// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IDataHub.sol";
import "./interfaces/IDepositVault.sol";
import "./interfaces/IOracle.sol";
import "./libraries/REX_LIBRARY.sol";
import "./interfaces/IExecutor.sol";
import "hardhat/console.sol";

contract Utility is Ownable {
    IDataHub public Datahub;

    IOracle public Oracle;

    IDepositVault public DepositVault;

    IExecutor public Executor;

    IInterestData public interestContract;

    /** Constructor  */
    constructor(
        address initialOwner,
        address _DataHub,
        address _deposit_vault,
        address oracle,
        address _executor,
        address _interest
    ) Ownable(initialOwner) {
        Datahub = IDataHub(_DataHub);
        DepositVault = IDepositVault(_deposit_vault);
        Oracle = IOracle(oracle);
        Executor = IExecutor(_executor);
        interestContract = IInterestData(_interest);
    }

    /// @notice Alters the exchange contract
    /// @param _executor the new executor address
    function AlterExchange(address _executor) public onlyOwner {
        Executor = IExecutor(_executor);
    }

    /// @notice Explain to an end user what this does
    /// @dev Explain to a developer any extra details
    /// @param user being argetted
    /// @param token being argetted
    function validateMarginStatus(
        address user,
        address token
    ) external view returns (bool) {
        (, , , bool margined, ) = Datahub.ReadUserData(user, token);
        return margined;
    }

    //// @notice calcualtes aimmr
    /// @dev Explain to a developer any extra details
    /// @param user being argetted
    /// @param token being argetted
    /// @param BalanceToLeave the balance to leave
    function calculateAIMRRequirement(
        address user,
        address token,
        uint256 BalanceToLeave
    ) external view returns (bool) {
        if (
            Datahub.calculateAIMRForUser(user, token, BalanceToLeave) <=
            Datahub.calculateTotalPortfolioValue(user)
        ) {
            return true;
        } else {
            return false;
        }
    }

    //// @notice Explain to an end user what this does
    /// @dev Explain to a developer any extra details
    /// @param user being argetted
    /// @param token being argetted
    /// @param BalanceToLeave the balance to leave
    /// @param userAssets the users assets
    function calculateMarginRequirement(
        address user,
        address token,
        uint256 BalanceToLeave,
        uint256 userAssets
    ) external view returns (bool) {
        uint256 liabilities = (BalanceToLeave - userAssets);
        if (
            Datahub.calculateAMMRForUser(user) +
                REX_LIBRARY.calculateMaintenanceRequirementForTrade(
                    Executor.returnAssetLogs(token),
                    liabilities
                ) <=
            Datahub.calculateTotalPortfolioValue(user)
        ) {
            return true;
        } else {
            return false;
        }
    }

    //// @notice calcualtes aimmr
    /// @dev Explain to a developer any extra details
    /// @param user being argetted
    function calculateAMMRRequirement(
        address user
    ) external view returns (bool) {
        if (
            Datahub.calculateAMMRForUser(user) <=
            Datahub.calculateTotalPortfolioValue(user)
        ) {
            return true;
        } else {
            return false;
        }
    }

    function calculateAmountToAddToLiabilities(
        address user,
        address token,
        uint256 amount
    ) public view returns (uint256) {
        (uint256 assets, , , , ) = Datahub.ReadUserData(user, token);
        return amount > assets ? amount - assets : 0;
    }

    function calculateTradeLiabilityAddtions(
        address[2] memory pair,
        address[][2] memory participants,
        uint256[][2] memory trade_amounts
    ) public view returns (uint256[] memory, uint256[] memory) {
        uint256[] memory TakerliabilityAmounts = new uint256[](
            participants[0].length
        );
        uint256[] memory MakerliabilityAmounts = new uint256[](
            participants[1].length
        );

        for (uint256 i = 0; i < participants[0].length; i++) {
            uint256 TakeramountToAddToLiabilities = calculateAmountToAddToLiabilities(
                    participants[0][i],
                    pair[0],
                    trade_amounts[0][i]
                );

            TakerliabilityAmounts[i] = TakeramountToAddToLiabilities;
        }

        for (uint256 i = 0; i < participants[1].length; i++) {
            uint256 MakeramountToAddToLiabilities = calculateAmountToAddToLiabilities(
                    participants[1][i],
                    pair[1],
                    trade_amounts[1][i]
                );

            MakerliabilityAmounts[i] = MakeramountToAddToLiabilities;
        }

        return (TakerliabilityAmounts, MakerliabilityAmounts);
    }

    function returnBulkAssets(
        address[] memory users,
        address token
    ) external view returns (uint256) {
        uint256 bulkAssets;
        for (uint256 i = 0; i < users.length; i++) {
            (uint256 assets, , , , ) = Datahub.ReadUserData(users[i], token);

            bulkAssets += assets;
        }
        return bulkAssets;
    }

    /// @notice Explain to an end user what this does
    /// @dev Explain to a developer any extra details
    /// @param user being argetted
    /// @param token being argetted
    /// @return assets
    function returnAssets(
        address user,
        address token
    ) external view returns (uint256) {
        (uint256 assets, , , , ) = Datahub.ReadUserData(user, token);
        return assets;
    }

    function returnliabilities(
        address user,
        address token
    ) external view returns (uint256) {
        (, uint256 liabilities, , , ) = Datahub.ReadUserData(user, token);
        return liabilities;
    }

    /// @notice Explain to an end user what this does
    /// @dev Explain to a developer any extra details
    /// @param user being targetted
    /// @param token being targetted
    /// @return pending balance
    function returnPending(
        address user,
        address token
    ) external view returns (uint256) {
        (, , uint256 pending, , ) = Datahub.ReadUserData(user, token);
        return pending;
    }

    function returnMaintenanceRequirementForTrade(
        address token,
        uint256 amount
    ) external view returns (uint256) {
        //uint256 price = assetdata[token].assetPrice; // price comes at aggregate calc now
        IDataHub.AssetData memory assetLogs = Executor.returnAssetLogs(token);
        uint256 maintenace = assetLogs.MaintenanceMarginRequirement;
        return ((maintenace * (amount)) / 10 ** 18); //
    }

    function alterAdminRoles(
        address _datahub,
        address _depositVault,
        address _oracle
    ) public onlyOwner {
        Datahub = IDataHub(_datahub);
        DepositVault = IDepositVault(_depositVault);
        Oracle = IOracle(_oracle);
    }

    receive() external payable {}
}
/*

    function chargeInterest(
        address token,
        uint256 liabilities,
        uint256 amount_to_be_added,
        uint256 rateIndex
    ) public view returns (uint256) {
        uint256 interestBulk;

        for (
            uint256 i = rateIndex;
            i < interestContract.fetchCurrentRateIndex(token);
            i++
        ) {
            interestBulk += (interestContract.fetchRate(token, i) / 8760); /// / 8760
        }
        uint256[] memory details = new uint256[](3);

        details[0] = liabilities;
        details[1] = amount_to_be_added;
        details[2] = rateIndex;
        uint256 interestAverage;

        if (interestContract.fetchCurrentRateIndex(token) != 0) {
            interestAverage = ((interestBulk * 10 ** 18) /
                ((interestContract.fetchCurrentRateIndex(token)) - rateIndex) /
                10 ** 18);
        } else {
            interestAverage = interestBulk;
        }
        console.log(interestAverage, "interest average");
        return
            returnInterestDetails(
                (interestAverage),
                token,
                details,
                Datahub.returnAssetLogs(token)
            );
    }

    function returnInterestDetails(
        uint256 interestAverage,
        address token,
        uint256[] memory details,
        IDataHub.AssetData memory assetLogs
    ) private view returns (uint256) {
        uint256 interestCharged;

        if (interestContract.fetchCurrentRateIndex(token) != 0) {
            unchecked {
                /*
                interestCharged = (details[0] / 10 ** 18) *
                    (1 + (interestAverage) **
                        (interestContract.fetchCurrentRateIndex(token) -
                            details[2])) -
                    (details[0] / 10 ** 18);

            
            newLiabilities = oldLiabilities * ((1+averageHourlyInterest)^amountOfIndexes)



                interestCharged = (1 +
                    (interestAverage) **
                        (interestContract.fetchCurrentRateIndex(token) -
                            details[2]));
                console.log(interestCharged / 10 ** 36, "interest charged");
                console.log(1 + (interestAverage), "interest avarge +1");

                /*
        uint256 amountOfchargedIndexs = interestContract.fetchCurrentRateIndex(token) - details[2];
        interestCharged = ((1 + (interestAverage)) ** (interestContract.fetchCurrentRateIndex(token) -
                            details[2])) / ((10**18) ** amountOfchargedIndexs);


                // console.log(interestCharged, "interest charged output");

                //interestCharged = details[0] * (((1 + interestAverage) ** (interestContract.fetchCurrentRateIndex(token) - details[2])) / (10**18 **(interestContract.fetchCurrentRateIndex(token) - details[2])))- details[0];
            }
        } else {
            interestCharged = details[0] * (1 + interestAverage) - details[0];
        }

        // this settles them in the example to the current hour not the next thats what happens below

        uint256 interestRateForHour = REX_LIBRARY.calculateInterestRate(
            details[1],
            assetLogs,
            interestContract.fetchRateInfo(
                token,
                interestContract.fetchCurrentRateIndex(token)
            )
        ) / 8760;

        return (interestCharged +
            interestRateForHour +
            REX_LIBRARY.calculateinitialMarginFeeAmount(assetLogs, details[1]));
    }

    */
/*

        uint hour = 1 hours; // 3600
        uint day = 1 days; // 86400
        uint week = day * 7; // 604800
        uint month = week * 4; // 2419200
        uint year = month * 14; // 33868800

        
function calculateInterestCharge(
    address token,
    address user,
    uint256 liabilities,
    uint256 amount_to_be_added,
    uint256 usersOriginRateIndex
) public view returns (uint256) {
    uint256 TimeInHoursInDebt = interestContract.fetchCurrentRateIndex(token) - usersOriginRateIndex;

    uint256 convertedHoursInDebt = TimeInHoursInDebt * 3600;

    uint256 calculatedInterest;

    uint256 remainingTime = convertedHoursInDebt;
    uint256 runningOriginIndex = usersOriginRateIndex;


    // Yearly interest calculation
    if (remainingTime >= year) {
        // scale them up to next years index 
        uint usersOriginYear =  (usersOriginRateIndex * 3600 )  / year;// 
        // 12 * usersOriginYear + 1;  // cause if their origin year was 1 then would spit back 2 which is the orign of the next year
        uint usersOriginMonth =  (usersOriginRateIndex * 3600) / month;// --> use this and go if its like 10 scale to 12 
        //1,2,3,4,5
       uint256[] memory interestDetails = calculateInterest(4, usersOriginMonth, (usersOriginYear + year) / month,remainingTime) ;  // this gets the next years month

       calculatedInterest += interestDetails[0];
       remainingTime -= interestDetails[1];
       runningOriginIndex = interestDetails[2];

    }

    // Monthly interest calculation
    if (remainingTime >= month  && remainingTime < year ) {
       uint usersOriginYear =  (usersOriginRateIndex * 3600 )  / year;// 
        // 12 * usersOriginYear + 1;  // cause if their origin year was 1 then would spit back 2 which is the orign of the next year
        uint usersOriginMonth =  (usersOriginRateIndex * 3600) / month;// --> use this and go if its like 10 scale to 12 
        //1,2,3,4,5
       uint256[] memory interestDetails = calculateInterest(4, usersOriginMonth, (usersOriginYear + year) / month,remainingTime) ;  // this gets the next years month
       calculatedInterest += interestDetails[0];
       remainingTime -= interestDetails[1];
       runningOriginIndex = interestDetails[2];
    }

    // Weekly interest calculation
    if (remainingTime >= week && remainingTime < month) {
       uint usersOriginYear =  (usersOriginRateIndex * 3600 )  / year;// 
        // 12 * usersOriginYear + 1;  // cause if their origin year was 1 then would spit back 2 which is the orign of the next year
        uint usersOriginMonth =  (usersOriginRateIndex * 3600) / month;// --> use this and go if its like 10 scale to 12 
        //1,2,3,4,5
       uint256[] memory interestDetails = calculateInterest(4, usersOriginMonth, (usersOriginYear + year) / month,remainingTime) ;  // this gets the next years month

       calculatedInterest += interestDetails[0];
       remainingTime -= interestDetails[1];
       runningOriginIndex = interestDetails[2];
    }

    // Daily interest calculation
    if (remainingTime >= day && remainingTime < week) {
       uint usersOriginYear =  (usersOriginRateIndex * 3600 )  / year;// 
        // 12 * usersOriginYear + 1;  // cause if their origin year was 1 then would spit back 2 which is the orign of the next year
        uint usersOriginMonth =  (usersOriginRateIndex * 3600) / month;// --> use this and go if its like 10 scale to 12 
        //1,2,3,4,5
       uint256[] memory interestDetails = calculateInterest(4, usersOriginMonth, (usersOriginYear + year) / month,remainingTime) ;  // this gets the next years month

       calculatedInterest += interestDetails[0];
       remainingTime -= interestDetails[1];
       runningOriginIndex = interestDetails[2];


    }
    // Hourly interest calculation
    if (remainingTime >= hour && remainingTime < day) {
       uint usersOriginYear =  (usersOriginRateIndex * 3600 )  / year;// 
        // 12 * usersOriginYear + 1;  // cause if their origin year was 1 then would spit back 2 which is the orign of the next year
        uint usersOriginMonth =  (usersOriginRateIndex * 3600) / month;// --> use this and go if its like 10 scale to 12 
        //1,2,3,4,5
       uint256[] memory interestDetails = calculateInterest(4, usersOriginMonth, (usersOriginYear + year) / month,remainingTime) ;  // this gets the next years month

       calculatedInterest += interestDetails[0];
       remainingTime -= interestDetails[1];
       runningOriginIndex = interestDetails[2];
    }

    return calculatedInterest;
}

    function handleHourlyFee(
        address user,
        address token,
        uint256 amount
    ) external view returns (uint256) {
        IDataHub.AssetData memory assetLogs = Datahub.returnAssetLogs(token);

        uint256 secondsElapsedInCurrentHour = block.timestamp % 3600;

        uint256 percentageOfHourElapsed = (secondsElapsedInCurrentHour * 100) /
            3600;

        uint256 percentageOfHourRemaining = 100 - percentageOfHourElapsed;

        uint256 initialMarginFee = REX_LIBRARY.calculateinitialMarginFeeAmount(
            assetLogs,
            amount
        );

        uint256 interestRateForHour = REX_LIBRARY.calculateInterestRate(
            amount,
            assetLogs,
            Datahub.fetchRates(token, Datahub.fetchCurrentRateIndex(token))
        ) / 8760;

        return
            initialMarginFee +
            ((interestRateForHour * percentageOfHourRemaining) / 100) *
            (amount / 10 ** 18);
    }
*/
/*

this function relfects what interest a user would be charged on liabilities they have out

this function should mirror precisly what amount in turn would be added to a users assets as well



REQUIREMENTS FOR THIS FUNCTION:

We need to know when a user depositted, withdrew, or last traded those assets -> any chnage in their assets this function must be called

we need to know the borrow proportion at the index of deposit last trade withdraw etc / interest index



/// @notice This calcuates the amount of deposit interest the user has earned
/// @param user -> the address of the user 
/// @param token -> the address of the token they are collecting deposit interest on 
/// @return totalDepositInterestOwed this is the total deposit interest owed to the user

function calculateDepositInterestOwed(address user){

uint256 usersAssets = DataHub.fetchUsersAssets(user,token);

uint256 usersAssetOriginIndex = fetchUsersIndex(user, token) // this will return the users deposit index 

       for (
            uint256 i = usersAssetOriginIndex;
            i < interestContract.fetchCurrentRateIndex(token);
            i++
        ) {
            AverageInterestRate += ((interestContract.fetchRate(token, i) / 8760) * IInterestData.borrowProportionAtIndex[i]) /10**18;

                // this adds up the rates for the cycles he has been in and multiplies the value by the borrow proprtion of that period
                // divided by 10**18 because borrow proportion should be a decimal not whole. 
        }

        interestRateCharged = AverageInterestRate / (interestContract.fetchCurrentRateIndex(token) - usersAssetOriginIndex);

return usersAssets * interestBulk

if (x % 24 == 0) {
    // x is divisible by 24
}


/// @notice Explain to an end user what this does
/// @dev Explain to a developer any extra details
/// @param Documents a parameter just like in doxygen (must be followed by parameter name)
/// @return Documents the return variables of a contract’s function state variable
/// @inheritdoc	Copies all missing tags from the base function (must be followed by the contract name)

function calculateInterestCharge(token, user, liabilities, amount_to_beAdded, usersRateIndex){

what we need here is this :

The users last charged rate index = usersRateIndex

the current rate index = fetchCurrnetRateIndex(token)

the user we are targetting = user

the token they are being charged interest on =  token

the liabilities the user has that they are being charged interest on = liabilities

the new amount that will be up charged an hour of interest = amount_to_be_added
////////////////////////////////////////////////////////////////////////////////////////////////////
example:

heres another example he took out margin at 29

and now its 112

83 hours of interest / 24 ->> 3.45 

so we know hes been in for 3 whole days and .45 days which we could in hours for the remainder

uint256 TimeInHoursInDebt = currentRateIndex - usersRateIndex    // 112 - 29 = 83 hours in debt 

uint indexToEndAtForDaily  = 83 / 24 -- 3.45   so that will be index 3 

uint usersDailyIndex =  usersRateIndex / 24    --> this will find out what daily he was in 


then chrge from 112-120

if(TimeInHoursInDebt > 25){

usersDailyIndex = 1.05 -> 1 

if the number isint a full number ie 1 even then take his origin and start fuckin counting

we need to save daily index like inex *24 +1 = 49

so 
uint usersDailyIndex =  usersRateIndex / 24    --> this will find out what daily he was in 

uint256 DailyIndexStartTime = ((usersDailyIndex + 1) * 24) + 1;

charge him up hourly to index 2 i

for(    uint256 i = usersRateIndex ; 29
            i < DailyIndexStartTime  (49);
            i++) {
                add interest to his interest charge hourly until we reach the end of index 2
                so this charges from 29-49 then we will charge a daily for index 2 (49-72) and index 3 (73-96) then hourly again up to 112

                IndexEndedAtForTheHourlyCharges = i
            }

for( uint256 i = IndexEndedAtForTheHourlyCharges; i <= indexToEndAtForDaily; i++ ){
    // add the two days of interest

    IndexEndedAtForTheDailyCharges = i;  // equals 3
}

IndexEndedAtForTheDailyCharges + 1

IndexToBeginAtForHourlyRemainder = (IndexEndedAtForTheDailyCharges + 1) * ((24) + 1);

for( uint256 i =IndexToBeginAtForHourlyRemainder; i <= currentRateIndex ; i++ ){
    // add interest for the last remaining hours 


}



do hourly charges all the way up to end point

whatever this output is charge him hourly to the next index (2)

loop from his rate index up to the index 2 daily rate 

 index 0 --->  1-24 ending at the end of the 24th hour 
 index 1 --->  25-48 
index 2 --->   49 - 72
index 3 --->   73 - 96   3.45 
index 4 --->   97 - 120
index 5 --->   49 - 72

then charge daily rates UNTIL he gets to 112
/////////////////////////////////////////////////////////////////////////////////////////////////////////
}

       for (
            uint256 i = usersAssetOriginIndex;
            i < interestContract.fetchCurrentRateIndex(token);
            i++
        ) {
            AverageInterestRate += ((interestContract.fetchRate(token, i) / 8760) * IInterestData.borrowProportionAtIndex[i]) /10**18;

                // this adds up the rates for the cycles he has been in and multiplies the value by the borrow proprtion of that period
                // divided by 10**18 because borrow proportion should be a decimal not whole. 
        }




in this example the answer would be 1.05 or some shit

so we go if value < 7 go into the daily charge logic but what weekly rate 

charge hourlys from current index to the value of the next daily rate

so hes on 29 so we charge dailys up to the next daily over, and if there is 

for instance 

  for (uint256 i = startIndex; i <= endIndex; i++) {
            // Calculate hourly interest for each hour
            totalInterest += hourlyRates[i];

            // If the next hour is the start of a new day, subtract the hourly rate to avoid double counting
            if (i % 24 == 0 && i + 1 <= endIndex) {
                totalInterest -= hourlyRates[i + 1];
            }
        }



we need t




}





function runalooop(uint256 usersOriginRateIndex, uint256 convertedHoursInDebt, uint256 timescale ){
                // find out what year 
        
            uint UsersOriginYear = usersOriginRateIndex / timescale == 0 ? 0 : usersOriginRateIndex / timescale;
            uint YearIndex = convertedHoursInDebt / timescale; // say its year 1.05 they have been in for one entire year and a bit
            // charge them for the year 
            // we still need to find the years ending index to see if we jump to weekly daily or hourly 
        for (
                uint256 i = UsersOriginYear; //0
                i < YearIndex; //1 // charge them a year basically 
                i++
            ) {
                //  add interest to his interest charge hourly until 
            
              uint EndedYearTime = (i * timescale);

              convertedHoursInDebt - EndedYearTime ;
            }   
}
       /*

    /// @notice EThis calculates an interest charge for a user
    /// @dev Explain to a developer any extra details
    /// @param token the token we are going to be charging interest on
    /// @param user the user we are going to bill
    /// @param liabilities the users current liabilities
    /// @param amount_to_be_added the amount to be added to their liabilities
    ///@param usersOriginRateIndex the users current interest rate index
    function calculateInterestCharge(
        address token,
        address user,
        uint256 liabilities,
        uint256 amount_to_be_added,
        uint256 usersOriginRateIndex
    ) public view returns (uint256) {

  
 index 0 --->  1-24 ending at the end of the 24th hour 
 index 1 --->  25-48 
index 2 --->   49 - 72
index 3 --->   73 - 96   3.45 
index 4 --->   97 - 120
index 5 --->   49 - 72

112 - 29 = 83 hours in debt

   
        uint256 TimeInHoursInDebt = interestContract.fetchCurrentRateIndex(
            token
        ) - usersOriginRateIndex; // 112 - 29 = 83 hours in debt

        uint convertedHoursInDebt = TimeInHoursInDebt * 3600;
        // 

        uint hour = 1 hours; // 3600
        uint day = 1 days; // 86400
        uint week = day * 7; // 604800
        uint month = week * 4; // 2419200
        uint year = month * 14; // 33868800

        // if their number is 34868800   then we can assume they have been in over a year 
        // used for accurate calculations we know there are not 14 months in a year 

        /// get the users index
        // ge tthe current index 
        // get the years start and end indexs 
        // first off what index are they in? if they are part way in one which they basically always will be
        // then we see is their origin index larger than thext end index of the upcoming year


        /*
        we can assume that the users index and the current index difference is the amount of hours they have ben accruing debt

        if they are on an index in between 

        

           uint usersOriginYear =  usersOriginRateIndex / year;// ---> this should give in what year they took on the debt if 0 then go to monthly 
           uint usersOriginMonth =  usersOriginRateIndex / month;// ---> this should give in what year they took on the debt if 0 then go to monthly 
           uint usersOriginWeek =  usersOriginRateIndex / week// ---> this should give in what year they took on the debt if 0 then go to monthly 

        if(convertedHoursInDebt >= year ){
            // find out what year 

            // the hour value 

            (usersOriginRateIndex * 3600) / year// ---> this should give in what year they took on the debt if 0 then go to monthly 
            // 1 - and the current index is that larger than 12 months. 

            uint UsersOriginYear = usersOriginRateIndex / year == 0 ? 0 : usersOriginRateIndex / year;
            uint YearIndex = convertedHoursInDebt / year; // say its year 1.05 they have been in for one entire year and a bit
            // charge them for the year 
            // we still need to find the years ending index to see if we jump to weekly daily or hourly 
        for (
                uint256 i = UsersOriginYear; //0
                i < YearIndex; //1 // charge them a year basically 
                i++
            ) {
                //  add interest to his interest charge hourly until 
            
              uint EndedYearTime = (i * year);

              convertedHoursInDebt - EndedYearTime ;
            }   

        }

        if(convertedHoursInDebt >= month ){

        } 
        if(convertedHoursInDebt >= week){

        } 

        if(convertedHoursInDebt >= day){

        } 

        if(convertedHoursInDebt >= hour){

        } 
        uint indexToEndAtForDaily = TimeInHoursInDebt / day; // -- 3.45   so that will be index 3

        uint usersDailyIndex = usersOriginRateIndex / day; // --> this will find out what daily he was in  will be 1

        if (TimeInHoursInDebt > day + 1) {

            uint256 DailyIndexStartTime = ((usersDailyIndex + 1) * 24) + 1; // this will equal 49 which is the start of index 2

            uint IndexEndedAtForTheHourlyCharges;
            uint IndexEndedAtForTheDailyCharges;
            for (
                uint256 i = usersOriginRateIndex; //29
                i < DailyIndexStartTime; //(49);
                i++
            ) {
                //  add interest to his interest charge hourly until we reach the end of index 2
                //   so this charges from 29-49 then we will charge a daily for index 2 (49-72) and index 3 (73-96) then hourly again up to 112

                IndexEndedAtForTheHourlyCharges = (i / day);
            }

            for (
                uint i = IndexEndedAtForTheHourlyCharges;
                i <= indexToEndAtForDaily;
                i++
            ) {
                // add the two days of interest

                IndexEndedAtForTheDailyCharges = i; // equals 3
            }

            IndexEndedAtForTheDailyCharges + 1;

            uint IndexToBeginAtForHourlyRemainder = (IndexEndedAtForTheDailyCharges +
                    1) * ((24) + 1);

            for (
                uint256 i = IndexToBeginAtForHourlyRemainder;
                i <= interestContract.fetchCurrentRateIndex(token);
                i++
            ) {
                // add interest for the last remaining hours
            }

            // update his index
            // reutrn the value
        } else {
            for (
                uint256 i = usersOriginRateIndex; //5
                i < interestContract.fetchCurrentRateIndex(token); //(25);
                i++
            ) {
                //  add interest to his interest charge hourly un
            }
        }
    }
*/
