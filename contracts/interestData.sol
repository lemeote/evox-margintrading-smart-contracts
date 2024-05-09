// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import "./interfaces/IDataHub.sol";
import "./interfaces/IExecutor.sol";
import "./interfaces/IUtilityContract.sol";
import "./libraries/EVO_LIBRARY.sol";

import "hardhat/console.sol";

contract interestData {
    modifier checkRoleAuthority() {
        require(admins[msg.sender] == true, "Unauthorized");
        _;
    }

    function alterAdminRoles(
        address _dh,
        address _executor,
        address _dv,
        address _utils
    ) public {
        require(msg.sender == owner, " you cannot perform this action");
        admins[_dh] = true;
        Datahub = IDataHub(_dh);
        admins[_executor] = true;
        Executor = IExecutor(_executor);
        admins[_dv] = true;
        admins[_utils] = true;
        utils = IUtilityContract(_utils);
    }

    function transferOwnership(address _owner) public {
        require(msg.sender == owner, " you cannot perform this action");
        owner = _owner;
    }

    /// @notice Keeps track of contract admins
    mapping(address => bool) public admins;

    IDataHub public Datahub;
    IExecutor public Executor;
    IUtilityContract public utils;

    address public owner;

    constructor(
        address initialOwner,
        address _executor,
        address _dh,
        address _utils,
        address _dv
    ) {
        owner = initialOwner;
        admins[initialOwner] = true;
        admins[_executor] = true;
        Executor = IExecutor(_executor);
        admins[_dh] = true;
        Datahub = IDataHub(_dh);
        admins[_utils] = true;
        utils = IUtilityContract(_utils);
        admins[_dv] = true;
    }

    mapping(uint => mapping(address => mapping(uint256 => IInterestData.interestDetails))) InterestRateEpochs;

    mapping(address => uint256) currentInterestIndex;

    /// @notice Fetches an interest rate data struct
    /// @param token the token being targetted
    /// @param index the index of the period
    /// @return IInterestData.interestDetails memor
    function fetchRateInfo(
        address token,
        uint256 index
    ) public view returns (IInterestData.interestDetails memory) {
        return InterestRateEpochs[0][token][index];
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
    /// @notice Fetches the current interest rate
    function fetchCurrentRate(address token) public view returns (uint256) {
        uint256 rate = InterestRateEpochs[0][token][currentInterestIndex[token]]
            .interestRate;
        return rate;
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
    /// @notice Fetches the libailities at a certain index
    function fetchLiabilitiesOfIndex(
        address token,
        uint256 index
    ) public view returns (uint256) {
        return InterestRateEpochs[0][token][index].totalLiabilitiesAtIndex;
    }

    function calculateAverageCumulativeInterest(
        uint256 startIndex,
        uint256 endIndex,
        address token
    ) public view returns (uint256) {
        uint256 cumulativeInterestRates = 0;
        uint16[5] memory timeframes = [8736, 672, 168, 24, 1];

        uint256 runningUpIndex = startIndex;
        uint256 runningDownIndex = endIndex;
        uint256 biggestPossibleStartTimeframe;
        uint256 adjustedIndex;
        
        if(startIndex != 1) {
            startIndex = startIndex + 1; // For calculating untouched and cause of gas fee
        }
        // startIndex = startIndex + 1; // For calculating untouched and cause of gas fee

        for (uint256 i = 0; i < timeframes.length; i++) {
            if ( startIndex + timeframes[i] - 1 <= endIndex) { // For spliting

                biggestPossibleStartTimeframe = (startIndex / timeframes[i]) * timeframes[i];

                if(( startIndex % timeframes[i]) > 0 ) {
                    biggestPossibleStartTimeframe += timeframes[i];
                }              
                
                runningUpIndex = biggestPossibleStartTimeframe + 1;
                runningDownIndex = biggestPossibleStartTimeframe;
                // console.log("runningUpIndex", runningUpIndex);
                break;
            }
        }
        for (uint256 i = 0; i < timeframes.length; i++) {
            while ((runningUpIndex + timeframes[i] - 1) <= endIndex) {
                // this inverses the list order due to interest being stored in the opposite index format 0-4
                adjustedIndex = timeframes.length - 1 - i;
                // console.log("adjusted index", adjustedIndex);
                // console.log("time scale rate index", fetchTimeScaledRateIndex(
                //     adjustedIndex,
                //     token,
                //     runningUpIndex / timeframes[i] // 168 / 168 = 1
                // ).interestRate);
                cumulativeInterestRates +=
                    fetchTimeScaledRateIndex(
                        adjustedIndex,
                        token,
                        runningUpIndex / timeframes[i] // 168 / 168 = 1
                    ).interestRate *
                    timeframes[i];
                // console.log("cumulativeInterestRates", cumulativeInterestRates);
                runningUpIndex += timeframes[i];
                // console.log("runningUpIndex", runningUpIndex);
                // console.log("counter", counter);
            }

            // Calculate cumulative interest rates for decreasing indexes
            while ((runningDownIndex >= timeframes[i]) && ((runningDownIndex - timeframes[i] + 1) >= startIndex)) {
                //&& available
                adjustedIndex = timeframes.length - 1 - i;
                // console.log("adjustedindex", adjustedIndex);

                cumulativeInterestRates +=
                    fetchTimeScaledRateIndex(
                        adjustedIndex,
                        token,
                        runningDownIndex / timeframes[i]
                    ).interestRate *
                    timeframes[i];

                // console.log("cumulativeInterestRates", cumulativeInterestRates);

                // console.log("counter", counter);

                runningDownIndex -= timeframes[i];

                // console.log("runningDownIndex", runningDownIndex);
            }
        }

        if (
            cumulativeInterestRates == 0 || (endIndex - (startIndex - 1)) == 0
        ) {
            return 0;
        }
        // Return the cumulative interest rates
        return cumulativeInterestRates / (endIndex - (startIndex  - 1));
    }

    function calculateAverageCumulativeDepositInterest(
        uint256 startIndex,
        uint256 endIndex,
        address token
    ) public view returns (uint256) {
        uint256 cumulativeInterestRates = 0;
        uint16[5] memory timeframes = [8736, 672, 168, 24, 1];

        uint256 cumulativeBorrowProportion;

        uint256 runningUpIndex = startIndex;
        uint256 runningDownIndex = endIndex;
        uint256 biggestPossibleStartTimeframe;
        uint256 adjustedIndex;

        if(startIndex != 1) {
            startIndex = startIndex + 1; // For calculating untouched and cause of gas fee
        }
        // startIndex = startIndex + 1; // For calculating untouched and cause of gas fee
        
        for (uint256 i = 0; i < timeframes.length; i++) {
            if ( startIndex + timeframes[i] - 1 <= endIndex) { // For spliting
                biggestPossibleStartTimeframe = (startIndex / timeframes[i]) * timeframes[i];

                if(( startIndex % timeframes[i]) > 0 ) {
                    biggestPossibleStartTimeframe += timeframes[i];
                }              
                
                runningUpIndex = biggestPossibleStartTimeframe + 1;
                runningDownIndex = biggestPossibleStartTimeframe;
                break;
            }
        }

        for (uint256 i = 0; i < timeframes.length; i++) {
            while ((runningUpIndex + timeframes[i] - 1) <= endIndex) {
                adjustedIndex = timeframes.length - 1 - i;
                cumulativeInterestRates +=
                    fetchTimeScaledRateIndex(
                        adjustedIndex,
                        token,
                        runningUpIndex / timeframes[i] // 168 / 168 = 1
                    ).interestRate *
                    timeframes[i];

                cumulativeBorrowProportion +=
                    fetchTimeScaledRateIndex(
                        adjustedIndex,
                        token,
                        runningUpIndex / timeframes[i] // 168 / 168 = 1
                    ).borrowProportionAtIndex *
                    timeframes[i];

                runningUpIndex += timeframes[i];
            }

            // Calculate cumulative interest rates for decreasing indexes
            while ((runningDownIndex >= timeframes[i]) && ((runningDownIndex - timeframes[i] + 1) >= startIndex)) {
                adjustedIndex = timeframes.length - 1 - i;

                cumulativeInterestRates +=
                    fetchTimeScaledRateIndex(
                        adjustedIndex,
                        token,
                        runningDownIndex / timeframes[i]
                    ).interestRate *
                    timeframes[i];

                cumulativeBorrowProportion +=
                    fetchTimeScaledRateIndex(
                        adjustedIndex,
                        token,
                        runningUpIndex / timeframes[i] // 168 / 168 = 1
                    ).borrowProportionAtIndex *
                    timeframes[i];

                runningDownIndex -= timeframes[i];
            }
        }

        if (
            cumulativeInterestRates == 0 || (endIndex - (startIndex - 1)) == 0
        ) {
            return 0;
        }

        return
            (cumulativeInterestRates / (endIndex - (startIndex - 1))) *
            (cumulativeBorrowProportion / (endIndex - (startIndex - 1)));
    }

    /// @notice updates intereest epochs, fills in the struct of data for a new index
    /// @param token the token being targetted
    /// @param index the index of the period
    /// @param value the value
    function updateInterestIndex(
        address token,
        uint256 index, // 24
        uint256 value
    ) public checkRoleAuthority {
        // console.log("=======================Update Interest Index Function========================");
        // console.log("index", index);
        // console.log("value", value);
        currentInterestIndex[token] = index + 1; // 25
        uint16[5] memory timeframes = [1, 24, 168, 672, 8736];
        uint256 period_start;
        uint256 period_interval;
        uint256 borrowProportion;
        uint256 interestReate;

        borrowProportion = EVO_LIBRARY.calculateBorrowProportion(
            Datahub.returnAssetLogs(token)
        );

        setInterestRateEpoch(
            0,
            token,
            uint(currentInterestIndex[token]),
            borrowProportion,
            value
        );

        for (uint256 i = 1; i < timeframes.length; i++) {
            if( (index % timeframes[i]) == 0 ) {
                period_interval = timeframes[i] / timeframes[i-1];
                period_start = currentInterestIndex[token] / timeframes[i-1];
                period_start = (period_start / period_interval - 1) * period_interval + 1;
                borrowProportion = EVO_LIBRARY.calculateAverage(
                    utils.fetchBorrowProportionList(
                        i - 1,
                        period_start, // 1
                        period_start + period_interval - 1, //24
                        token
                    )
                );
                interestReate = EVO_LIBRARY.calculateAverage(
                    utils.fetchRatesList(
                        i - 1,
                        period_start, // 1
                        period_start + period_interval - 1, //24
                        token
                    )
                );
                setInterestRateEpoch(
                    i,
                    token,
                    uint(currentInterestIndex[token] / timeframes[i]),
                    borrowProportion,
                    interestReate
                );
            }
        }
    }

    function setInterestRateEpoch(uint256 dimension, address token, uint256 index, uint256 borrowProportionAtIndex, uint256 interestRate ) internal {
        // console.log("======================setInterestRateEpoch function=========================");
        InterestRateEpochs[dimension][token][index].interestRate = interestRate;

        InterestRateEpochs[dimension][token][index].lastUpdatedTime = block.timestamp;

        InterestRateEpochs[dimension][token][index].totalLiabilitiesAtIndex = Datahub.returnAssetLogs(token).assetInfo[1]; // 1 -> totalBorrowedAmount

        InterestRateEpochs[dimension][token][index].totalAssetSuplyAtIndex = Datahub.returnAssetLogs(token).assetInfo[0]; // 0 -> totalAssetSupply

        InterestRateEpochs[dimension][token][index].borrowProportionAtIndex = borrowProportionAtIndex;

        InterestRateEpochs[dimension][token][index].rateInfo = InterestRateEpochs[dimension][token][index-1].rateInfo;
        // console.log("===============================end===============================");
    }
    /// @notice initilizes the interest data for a token
    function initInterest(
        address token,
        uint256 index,
        uint256[] memory rateInfo,
        uint256 interestRate
    ) external checkRoleAuthority {
        InterestRateEpochs[0][token][index].lastUpdatedTime = block.timestamp;
        InterestRateEpochs[0][token][index].rateInfo = rateInfo;
        InterestRateEpochs[0][token][index].interestRate = interestRate;
        InterestRateEpochs[0][token][index].borrowProportionAtIndex = 0;
        currentInterestIndex[token] = index;
    }

    /// @notice Explain to an end user what this does
    /// @dev Explain to a developer any extra details
    /// @param token the token being targetted

    function chargeMassinterest(address token) public {
        console.log("================charge Massininterest Function=================");
        // console.log("current token index", fetchCurrentRateIndex(token));
        // console.log("token address", token);
        uint256 currentRateIndex = fetchCurrentRateIndex(token);
        IInterestData.interestDetails memory rateInfo = fetchRateInfo(token, currentRateIndex);
        uint256 lastUpdatedTime = rateInfo.lastUpdatedTime;

        if (lastUpdatedTime + 1 hours <= block.timestamp) {
            console.log("current index");
            console.log(currentRateIndex);
            // console.log("assetlogs");
            // console.log(Datahub.returnAssetLogs(token).totalAssetSupply);
            // console.log("rate info");
            // console.log(fetchRateInfo(token, fetchCurrentRateIndex(token)));

            // console.log("calculate interest rate", EVO_LIBRARY.calculateInterestRate(0, Datahub.returnAssetLogs(token), fetchRateInfo(token, fetchCurrentRateIndex(token))));
            IDataHub.AssetData memory assetLogs = Datahub.returnAssetLogs(token);
            uint256 interestRate = EVO_LIBRARY.calculateInterestRate(
                0,
                assetLogs,
                rateInfo
            );

            updateInterestIndex(
                token,
                currentRateIndex,
                interestRate
            );

            // console.log("current index after update",  fetchRateInfo(token, fetchCurrentRateIndex(token)).interestRate);
            uint256 currentInterestRateHourly = interestRate / 8736;
            uint256 calculatedBorroedAmount = ((assetLogs.assetInfo[1]) * (currentInterestRateHourly)) / 10 ** 18; // 1 -> totalBorrowedAmount
            console.log("current interestrate hourly", currentInterestRateHourly);
            // total borroed amount * current interest rate -> up total borrowed amount by this fucking value
            Datahub.setAssetInfo(1, token, calculatedBorroedAmount, true); // 1 -> totalBorrowedAmount

            // console.log("borrow add amount", (Datahub.returnAssetLogs(token).totalBorrowedAmount * currentInterestRateHourly) / 10 **  18);

            // console.log("total borrow amount", (Datahub.returnAssetLogs(token).totalBorrowedAmount));
        }
    }

    function returnInterestCharge(
        address user,
        address token,
        uint256 liabilitiesAccrued
    ) public view returns (uint256) {
        console.log("========================return interest charge function========================");
        (, uint256 liabilities, , , ) = Datahub.ReadUserData(user, token);

        uint256 interestRateIndex = Datahub.viewUsersInterestRateIndex(user, token);
        uint256 currentRateIndex = fetchCurrentRateIndex(token);
        IInterestData.interestDetails memory rateInfo = fetchRateInfo(token, currentRateIndex);
        IDataHub.AssetData memory assetLogs = Datahub.returnAssetLogs(token);
        uint256 cumulativeInterest = calculateAverageCumulativeInterest(
            interestRateIndex,
            currentRateIndex,
            token
        );

        // console.log("liabilities", liabilities);
        // console.log("fetchcurrentreateIndex", fetchCurrentRateIndex(token));
        // console.log("userearningrateIndex", Datahub.viewUsersInterestRateIndex(user, token));
        // console.log("calculate avareage cumulative interest", calculateAverageCumulativeInterest(
        //     Datahub.viewUsersInterestRateIndex(user, token),
        //     fetchCurrentRateIndex(token),
        //     token
        // ));
        // console.log("liabilitiesAccrued", liabilitiesAccrued);
        // console.log("viewUsersInterestRateIndex", Datahub.viewUsersInterestRateIndex(user, token));

        uint256 interestCharge = EVO_LIBRARY.calculateCompoundedLiabilities(
            currentRateIndex,
            cumulativeInterest,
            assetLogs,
            rateInfo,
            liabilitiesAccrued,
            liabilities,
            interestRateIndex
        );
        console.log("interest charge", interestCharge);
        return interestCharge;
    }

    receive() external payable {}
}
/*


*/
