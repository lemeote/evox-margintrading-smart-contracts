// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IDataHub.sol";
import "./interfaces/IExecutor.sol";
import "./interfaces/IinterestData.sol";
import "hardhat/console.sol";
import "./libraries/REX_LIBRARY.sol";

contract interestData is Ownable {
    modifier checkRoleAuthority() {
        require(
            msg.sender == owner() ||
                msg.sender == address(Datahub) ||
                msg.sender == address(Executor),
            "Unauthorized"
        );
        _;
    }

    IDataHub public Datahub;
    IExecutor public Executor;

    constructor(
        address initialOwner,
        address _DataHub,
        address _executor
    ) Ownable(initialOwner) {
        Datahub = IDataHub(_DataHub);
        Executor = IExecutor(_executor);
    }

    mapping(address => mapping(uint256 => IInterestData.interestDetails)) interestInfo;

    mapping(uint => mapping(address => mapping(uint256 => IInterestData.interestDetails))) InterestRateEpochs;

    mapping(address => uint256) currentInterestIndex;

    uint public hour = 1 hours; // 3600
    uint public day = 1 days; // 86400
    uint public week = day * 7; // 604800
    uint public month = week * 4; // 2419200
    uint public year = month * 13; // 31449600

    /// @notice This alters the admin roles for the contract
    /// @param _executor the address of the new executor contract
    /// @param _DataHub the adddress of the new datahub
    function AlterAdmins(address _executor, address _DataHub) public onlyOwner {
        Executor = IExecutor(_executor);
        Datahub = IDataHub(_DataHub);
    }

    /// @notice Explain to an end user what this does
    /// @dev Explain to a developer any extra details
    /// @param token the token being targetted
    /// @param index the index of the period
    /// @return IInterestData.interestDetails memor

    function fetchRateInfo(
        address token,
        uint256 index
    ) public view returns (IInterestData.interestDetails memory) {
        return interestInfo[token][index];
    }

    /// @notice Explain to an end user what this does
    /// @dev Explain to a developer any extra details
    /// @param token the token being targetted
    /// @param index the index of the period
    function fetchRate(
        address token,
        uint256 index
    ) public view returns (uint256) {
        return interestInfo[token][index].interestRate;
    }

    /// @notice Explain to an end user what this does
    /// @dev Explain to a developer any extra details
    /// @param token the token being targetted
    function fetchCurrentRate(address token) public view returns (uint256) {
        return interestInfo[token][currentInterestIndex[token]].interestRate;
    }

    /// @notice Explain to an end user what this does
    /// @dev Explain to a developer any extra details
    /// @param token the token being targetted
    /// @return currentInterestIndex[token]
    function fetchCurrentRateIndex(
        address token
    ) public view returns (uint256) {
        return currentInterestIndex[token];
    }

    /// @notice Explain to an end user what this does
    /// @dev Explain to a developer any extra details
    /// @param token the token being targetted
    /// @return currentInterestIndex[token]
    function fetchTimeScaledRateIndex(
        uint targetEpoch,
        address token,
        uint256 epochStartingIndex
    ) public view returns (IInterestData.interestDetails memory) {
        return InterestRateEpochs[targetEpoch][token][epochStartingIndex];
    }

    function calculateCompoundedLiabilities(
        address token,
        uint256 newLiabilities,
        uint256 usersLiabilities,
        uint256 usersOriginIndex
    ) public view returns (uint256) {
        // oldLiabilities * ((1+averageHourlyInterest)^amountOfIndexes)
        uint256 amountOfBilledHours = fetchCurrentRateIndex(token) -
            usersOriginIndex;
        console.log("users liabilities ",usersLiabilities);
        console.log("users index", usersOriginIndex);
        console.log("hours to bill for user", amountOfBilledHours);

        uint256 adjustedNewLiabilities = newLiabilities * (1 + fetchCurrentRate(token));
        uint256 initalMarginFeeAmount =  REX_LIBRARY.calculateinitialMarginFeeAmount(Executor.returnAssetLogs(token), newLiabilities);

        if(usersLiabilities ==0){
            return ((adjustedNewLiabilities + initalMarginFeeAmount) - newLiabilities) / 10**18;
        }else{
        return
            (((usersLiabilities *
            ((1 + calculateInterestCharge(token, usersOriginIndex)) **
                amountOfBilledHours)) + adjustedNewLiabilities + initalMarginFeeAmount) - (usersLiabilities +newLiabilities)) /10**18 ;
        }
    }

    struct InterestDetails {
        uint256 interestRateTracker;
        uint256 counter;
    }

    function calculateInterestCharge(
        address token,
        uint256 usersOriginRateIndex
    ) private view returns (uint256) {
        uint256 TimeInHoursInDebt = fetchCurrentRateIndex(token) -
            usersOriginRateIndex;
        uint256 convertedHoursInDebt = TimeInHoursInDebt * 3600;

        uint256 remainingTime = convertedHoursInDebt;
        uint256 runningOriginIndex = usersOriginRateIndex;

        InterestDetails[5] memory interestDetails; // yearly, monthly, weekly, daily, hourly

        uint256[5] memory timeFrames = [year, month, week, day, hour];

        for (uint256 i = 0; i < 5; i++) {
            while (remainingTime >= timeFrames[i]) {
                uint256[3] memory details = calculateInterestResults(
                    remainingTime,
                    runningOriginIndex,
                    timeFrames[i],
                    token
                );

                interestDetails[i].interestRateTracker += details[0];
                remainingTime -= details[1];
                runningOriginIndex += details[2];
                interestDetails[i].counter++;
            }
        }

        return
            calculateGrossRate(
                interestDetails[0].counter,
                REX_LIBRARY.calculateAverageOfValue(
                    interestDetails[0].interestRateTracker,
                    interestDetails[0].counter
                ),
                interestDetails[1].counter,
                REX_LIBRARY.calculateAverageOfValue(
                    interestDetails[1].interestRateTracker,
                    interestDetails[1].counter
                ),
                interestDetails[2].counter,
                REX_LIBRARY.calculateAverageOfValue(
                    interestDetails[2].interestRateTracker,
                    interestDetails[2].counter
                ),
                interestDetails[3].counter,
                REX_LIBRARY.calculateAverageOfValue(
                    interestDetails[3].interestRateTracker,
                    interestDetails[3].counter
                )
            );
    }

    function calculateGrossRate(
        uint timeFrameYear,
        uint256 grossYearlyRate,
        uint timeFrameMonth,
        uint256 grossMonthlyRate,
        uint timeFrameWeek,
        uint256 grossWeeklyRate,
        uint timeFrameDay,
        uint256 grossDailyRate
    ) private view returns (uint256) {
        return
            ((timeFrameYear * fetchHoursInTimeSpan(4) * grossYearlyRate) +
                (timeFrameMonth * fetchHoursInTimeSpan(3) * grossMonthlyRate) +
                (timeFrameWeek * fetchHoursInTimeSpan(2) * grossWeeklyRate) +
                (timeFrameDay * fetchHoursInTimeSpan(1) * grossDailyRate)) /
            ((timeFrameYear * fetchHoursInTimeSpan(4)) +
                (timeFrameMonth * fetchHoursInTimeSpan(3)) +
                (timeFrameWeek * fetchHoursInTimeSpan(2)) +
                (timeFrameDay * fetchHoursInTimeSpan(1)));
    }

    function calculateInterestResults(
        uint256 remainingTime,
        uint256 usersOriginRateIndex,
        uint targetTimeFrame,
        address token
    ) private view returns (uint256[3] memory) {
        uint[5] memory timeframes = [hour, day, week, month, year];

        uint usersOriginTimeFrame = (usersOriginRateIndex * 3600) /
            timeframes[targetTimeFrame];
        // i.e if we want to find what year or month a user took their debt this will spit that out
        // if they took debt after the first rate year cycles done but not the second then it would be like 1.5

        // cause if their origin year was 1 then would spit back 2 which is the orign of the next year
        uint usersOriginScaledDownTimeFrame = (usersOriginRateIndex * 3600) /
            timeframes[targetTimeFrame - 1]; // --> use this and go if its like 10 scale to 12
        // month that they took the debt on so it would be like 15 if they took the debt 3 months after the origin year
        uint256[3] memory interestDetails = calculateInterest(
            targetTimeFrame, // 1 year
            usersOriginScaledDownTimeFrame, // months
            (usersOriginTimeFrame + timeframes[targetTimeFrame]) /
                timeframes[targetTimeFrame - 1], //
            remainingTime, // remaing time to bill
            token
        ); // this gets the next years month

        return [interestDetails[0], interestDetails[1], interestDetails[2]];
    }

    //(usersOriginYear + year) ending index
    function calculateInterest(
        uint EpochRateId,
        uint256 originRateIndex,
        uint256 endingIndex,
        uint256 unbilledHours,
        address token
    ) internal view returns (uint256[3] memory) {
        uint256 interestCharge;

        for (uint256 i = originRateIndex; i < endingIndex; i++) {
            uint256 GrossRate = fetchTimeScaledRateIndex(EpochRateId, token, i)
                .interestRate; // idivsion ehre by months to get average for the months
            interestCharge += GrossRate;

            unbilledHours -= fetchHoursInTimeSpan(EpochRateId);

            originRateIndex += fetchHoursInTimeSpan(EpochRateId);
        }

        return [interestCharge, unbilledHours, originRateIndex];
    }

    function fetchHoursInTimeSpan(
        uint EpochRateId
    ) public view returns (uint256) {
        uint[5] memory timeframes = [hour, day, week, month, year];
        return timeframes[EpochRateId] / hour;
    }

    /// @notice Explain to an end user what this does
    /// @dev Explain to a developer any extra details
    /// @param token the token being targetted
    /// @param index the index of the period
    /// @param value the value
    function updateInterestIndex(
        address token,
        uint256 index,
        uint256 value
    ) public checkRoleAuthority {
        currentInterestIndex[token] = index + 1; // fetch current plus 1?
        interestInfo[token][currentInterestIndex[token]].interestRate = value;
        interestInfo[token][currentInterestIndex[token]].lastUpdatedTime = block
            .timestamp;
        interestInfo[token][index].totalLiabilitiesAtIndex = Datahub
            .fetchTotalBorrowedAmount(token);
/*
        if (index % 24 == 0) {
            InterestRateEpochs[1][token][uint(currentInterestIndex[token] / 24)]
                .interestRate = REX_LIBRARY.calculateAverage(
                fetchRatesList(
                    currentInterestIndex[token] - 24,
                    currentInterestIndex[token],
                    token
                )
            );

            InterestRateEpochs[1][token][uint(currentInterestIndex[token] / 24)]
                .lastUpdatedTime = block.timestamp;
            InterestRateEpochs[1][token][uint(currentInterestIndex[token] / 24)]
                .totalLiabilitiesAtIndex = Datahub.fetchTotalBorrowedAmount(
                token
            );
        }
        if (index % (24 * week) == 0) {
            InterestRateEpochs[2][token][
                uint(currentInterestIndex[token] / (24 * week))
            ].interestRate = REX_LIBRARY.calculateAverage(
                fetchRatesList(
                    currentInterestIndex[token] - 24 * week,
                    currentInterestIndex[token],
                    token
                )
            );
            InterestRateEpochs[2][token][
                uint(currentInterestIndex[token] / (24 * week))
            ].lastUpdatedTime = block.timestamp;
            InterestRateEpochs[2][token][
                uint(currentInterestIndex[token] / (24 * week))
            ].totalLiabilitiesAtIndex = Datahub.fetchTotalBorrowedAmount(token);
        }
        if (index % (24 * month) == 0) {
            InterestRateEpochs[3][token][
                uint(currentInterestIndex[token] / (24 * month))
            ].interestRate = REX_LIBRARY.calculateAverage(
                fetchRatesList(
                    currentInterestIndex[token] - 24 * month,
                    currentInterestIndex[token],
                    token
                )
            );
            InterestRateEpochs[3][token][
                uint(currentInterestIndex[token] / (24 * month))
            ].lastUpdatedTime = block.timestamp;
            InterestRateEpochs[3][token][
                uint(currentInterestIndex[token] / (24 * month))
            ].totalLiabilitiesAtIndex = Datahub.fetchTotalBorrowedAmount(token);
        }
        if (index % (24 * year) == 0) {
            InterestRateEpochs[3][token][
                uint(currentInterestIndex[token] / (24 * year))
            ].interestRate = REX_LIBRARY.calculateAverage(
                fetchRatesList(
                    currentInterestIndex[token] - 24 * year,
                    currentInterestIndex[token],
                    token
                )
            );
            InterestRateEpochs[3][token][
                uint(currentInterestIndex[token] / (24 * year))
            ].lastUpdatedTime = block.timestamp;
            InterestRateEpochs[3][token][
                uint(currentInterestIndex[token] / (24 * year))
            ].totalLiabilitiesAtIndex = Datahub.fetchTotalBorrowedAmount(token);
        }
        */
    }

    function fetchRatesList(
        uint256 startingIndex,
        uint256 endingIndex,
        address token
    ) private view returns (uint256[] memory) {
        uint256[] memory interestRatesForThePeriod;
        uint256 counter = 0;
        for (uint256 i = startingIndex; i < endingIndex; i++) {
            interestRatesForThePeriod[counter] = interestInfo[token][i]
                .interestRate;
            counter++;
        }
        return interestRatesForThePeriod;
    }

    function initInterest(
        address token,
        uint256 index,
        uint256[] memory rateInfo,
        uint256 interestRate
    ) external checkRoleAuthority {
        interestInfo[token][index].lastUpdatedTime = block.timestamp;
        interestInfo[token][index].rateInfo = rateInfo;
        interestInfo[token][index].interestRate = interestRate;
        currentInterestIndex[token] = index;
    }

    /// @notice Explain to an end user what this does
    /// @dev Explain to a developer any extra details
    /// @param token the token being targetted
    /// @param index the index of the period
    /// @return MassCharge
    function chargeLiabilityDelta(
        address token,
        uint256 index
    ) public view returns (uint256) {
        uint256 LiabilityToCharge = Datahub.fetchTotalBorrowedAmount(token);
        uint256 LiabilityDelta;

        IInterestData.interestDetails memory interestDetails = fetchRateInfo(
            token,
            index
        );

        /*
LiabilityDelta = TotalLiabilityPoolNow - TotalLiabilityPoolAtIndex // check which one is bigger, subtract the smaller from the bigger
LiabilityToCharge = TotalLiabilityPoolNow - LiabilityDelta
MassCharge = LiabilityToCharge * CurrentHourlyIndexInterest  //This means the index that just passed (i.e. we charge at 12:00:01 we use the interest rate for 12:00:00)

TotalLiabilityPoolNow += MassCharge
        */
        if (
            Datahub.fetchTotalBorrowedAmount(token) >
            interestDetails.totalLiabilitiesAtIndex
        ) {
            LiabilityDelta =
                Datahub.fetchTotalBorrowedAmount(token) -
                interestDetails.totalLiabilitiesAtIndex;
                LiabilityToCharge -= LiabilityDelta;
        } else {
            LiabilityDelta =
                interestDetails.totalLiabilitiesAtIndex -
                Datahub.fetchTotalBorrowedAmount(token);

            LiabilityToCharge -= LiabilityDelta;
        }
        uint256 MassCharge = (LiabilityToCharge *
            ((fetchCurrentRate(token)) / 8760)) / 10 ** 18;

        return MassCharge;
    }

    /// @notice Explain to an end user what this does
    /// @dev Explain to a developer any extra details
    /// @param token the token being targetted
    function chargeMassinterest(address token) public onlyOwner {
        if (
            fetchRateInfo(token, fetchCurrentRateIndex(token)).lastUpdatedTime +
                1 hours <=
            block.timestamp
        ) {
            Datahub.setTotalBorrowedAmount(
                token,
                chargeLiabilityDelta(token, fetchCurrentRateIndex(token)),
                true
            );

      
            updateInterestIndex(
                token,
                fetchCurrentRateIndex(token),
                REX_LIBRARY.calculateInterestRate(
                    chargeLiabilityDelta(token, fetchCurrentRateIndex(token)),
                    Datahub.returnAssetLogs(token),
                    fetchRateInfo(token, fetchCurrentRateIndex(token))
                )
            );
 
        }
    }

    receive() external payable {}
}

/*
    function calculateInterestCharge(
        address token,
        uint256 usersOriginRateIndex
    ) public view returns (uint256) {
        uint256 TimeInHoursInDebt = fetchCurrentRateIndex(token) -
            usersOriginRateIndex;

        // what this will return is the amount index or hours they have been in debt
        uint256 convertedHoursInDebt = TimeInHoursInDebt * 3600;
        // this will convert to seconds because all these timestamps are acutally in seconds at the base form
        // this will store the calcualted interest charge
        uint256 targetTimeFrame;
        // this is the timeframe variable we will use to try to scale them via the daily,weekly,monthly or yearly rate

        uint256 remainingTime = convertedHoursInDebt;
        // remaining time is the remaining time we should scale them
        uint256 runningOriginIndex = usersOriginRateIndex;
        // this is the index that keeps track of what we have already billed them for in their debt duration

        // Yearly interest calculation
        // change for while loop so while this condition is true do this then move down the chain

        uint256 yearlyInterestRateTracker;
        uint256 MonthlyInterestRateTracker;
        uint256 weeklyInterestRateTracker;
        uint256 dailyInterestRateTracker;
        uint256 hourlyInterestRateTracker;

        uint256 yearlyCounter;
        uint256 monthlyCounter;
        uint256 weeklyCounter;
        uint256 dailyCounter;
        uint256 hourlyCounter;

        while (remainingTime >= year) {
            targetTimeFrame = year;
            uint256[3] memory interestDetails = calculateInterestResults(
                remainingTime,
                usersOriginRateIndex,
                targetTimeFrame,
                token
            );

            yearlyInterestRateTracker += interestDetails[0];
            remainingTime -= interestDetails[1];
            runningOriginIndex = interestDetails[2];
            yearlyCounter++;
        }
        while (remainingTime >= month && remainingTime < year) {
            targetTimeFrame = month;
            uint256[3] memory interestDetails = calculateInterestResults(
                remainingTime,
                usersOriginRateIndex,
                targetTimeFrame,
                token
            );
            MonthlyInterestRateTracker += interestDetails[0];
            remainingTime -= interestDetails[1];
            runningOriginIndex = interestDetails[2];
            monthlyCounter++;
        }

        while (remainingTime >= week && remainingTime < month) {
            targetTimeFrame = week;
            uint256[3] memory interestDetails = calculateInterestResults(
                remainingTime,
                usersOriginRateIndex,
                targetTimeFrame,
                token
            );

            weeklyInterestRateTracker += interestDetails[0];
            remainingTime -= interestDetails[1];
            runningOriginIndex = interestDetails[2];
            weeklyCounter++;
        }

        while (remainingTime >= day && remainingTime < week) {
            targetTimeFrame = day;
            uint256[3] memory interestDetails = calculateInterestResults(
                remainingTime,
                usersOriginRateIndex,
                targetTimeFrame,
                token
            );
            dailyInterestRateTracker += interestDetails[0];
            remainingTime -= interestDetails[1];
            runningOriginIndex = interestDetails[2];
            dailyCounter++;
        }

        while (remainingTime >= hour && remainingTime < day) {
            targetTimeFrame = hour;
            uint256[3] memory interestDetails = calculateInterestResults(
                remainingTime,
                usersOriginRateIndex,
                targetTimeFrame,
                token
            );
            hourlyInterestRateTracker += interestDetails[0];
            remainingTime -= interestDetails[1];
            runningOriginIndex = interestDetails[2];
            hourlyCounter++;
        }

        return
            calculateGrossRate(
                yearlyCounter,
                REX_LIBRARY.calculateAverageOfValue(
                    yearlyInterestRateTracker,
                    yearlyCounter
                ),
                monthlyCounter,
                REX_LIBRARY.calculateAverageOfValue(
                    MonthlyInterestRateTracker,
                    monthlyCounter
                ),
                weeklyCounter,
                REX_LIBRARY.calculateAverageOfValue(
                    weeklyInterestRateTracker,
                    weeklyCounter
                ),
                dailyCounter,
                REX_LIBRARY.calculateAverageOfValue(
                    dailyInterestRateTracker,
                    dailyCounter
                )
            );
    }

*/
