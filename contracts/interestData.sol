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
        
        startIndex = startIndex + 1; // For calculating untouched and cause of gas fee

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
                uint256 adjustedIndex = timeframes.length - 1 - i;
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
                uint256 adjustedIndex = timeframes.length - 1 - i;
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
        return cumulativeInterestRates / (endIndex - (startIndex - 1));
    }

    // function calculateAverageCumulativeInterest(
    //     uint256 startIndex,
    //     uint256 endIndex,
    //     address token
    // ) public view returns (uint256) {
    //     uint256 cumulativeInterestRates = 0;
    //     uint16[5] memory timeframes = [8736, 672, 168, 24, 1];

    //     uint256 runningUpIndex = startIndex;
    //     uint256 runningDownIndex = endIndex;
    //     uint256 biggestPossibleStartTimeframe;

    //     // console.log("runningUpIndex", runningUpIndex);
    //     // console.log("runningDownIndex", runningDownIndex);

    //     uint32 counter;

    //     startIndex += 1;

    //     for (uint256 i = 0; i < timeframes.length; i++) {
    //         if (startIndex + timeframes[i] <= endIndex) {
    //             // console.log("timeframe", timeframes[i]);
    //             biggestPossibleStartTimeframe =
    //                 ((endIndex - startIndex) / timeframes[i]) *
    //                 timeframes[i];
    //             // console.log("biggestPossibleStartTimeframe", biggestPossibleStartTimeframe);
    //             runningDownIndex = biggestPossibleStartTimeframe; // 168
    //             // console.log("runningDownIndex", runningDownIndex);
    //             runningUpIndex = biggestPossibleStartTimeframe; // 168
    //             // console.log("runningUpIndex", runningUpIndex);
    //             break;
    //         }
    //     }
    //     for (uint256 i = 0; i < timeframes.length; i++) {
    //         while (runningUpIndex + timeframes[i] <= endIndex) {
    //             // this inverses the list order due to interest being stored in the opposite index format 0-4
    //             uint256 adjustedIndex = timeframes.length - 1 - i;
    //             // console.log("adjusted index", adjustedIndex);
    //             // console.log("time scale rate index", fetchTimeScaledRateIndex(
    //             //     adjustedIndex,
    //             //     token,
    //             //     runningUpIndex / timeframes[i] // 168 / 168 = 1
    //             // ).interestRate);
    //             cumulativeInterestRates +=
    //                 fetchTimeScaledRateIndex(
    //                     adjustedIndex,
    //                     token,
    //                     runningUpIndex / timeframes[i] // 168 / 168 = 1
    //                 ).interestRate *
    //                 timeframes[i];
    //             // console.log("cumulativeInterestRates", cumulativeInterestRates);
    //             runningUpIndex += timeframes[i];
    //             // console.log("runningUpIndex", runningUpIndex);
    //             counter++;
    //             // console.log("counter", counter);
    //         }

    //         // Calculate cumulative interest rates for decreasing indexes
    //         while (
    //             runningDownIndex >= startIndex &&
    //             runningDownIndex >= timeframes[i]
    //         ) {
    //             //&& available
    //             uint256 adjustedIndex = timeframes.length - 1 - i;
    //             // console.log("adjustedindex", adjustedIndex);

    //             cumulativeInterestRates +=
    //                 fetchTimeScaledRateIndex(
    //                     adjustedIndex,
    //                     token,
    //                     runningDownIndex / timeframes[i]
    //                 ).interestRate *
    //                 timeframes[i];

    //             // console.log("cumulativeInterestRates", cumulativeInterestRates);

    //             counter++;

    //             // console.log("counter", counter);

    //             runningDownIndex -= timeframes[i];

    //             // console.log("runningDownIndex", runningDownIndex);
    //         }
    //     }

    //     if (
    //         cumulativeInterestRates == 0 || (endIndex - (startIndex - 1)) == 0
    //     ) {
    //         return 0;
    //     }
    //     // Return the cumulative interest rates
    //     return cumulativeInterestRates / (endIndex - (startIndex - 1));
    // }

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

        startIndex = startIndex + 1; // For calculating untouched and cause of gas fee

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
                uint256 adjustedIndex = timeframes.length - 1 - i;
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
                uint256 adjustedIndex = timeframes.length - 1 - i;

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

    // function calculateAverageCumulativeDepositInterest(
    //     uint256 startIndex,
    //     uint256 endIndex,
    //     address token
    // ) public view returns (uint256) {
    //     uint256 cumulativeInterestRates = 0;
    //     uint16[5] memory timeframes = [8736, 672, 168, 24, 1];

    //     uint256 cumulativeBorrowProportion;

    //     uint256 runningUpIndex = startIndex;
    //     uint256 runningDownIndex = endIndex;
    //     uint256 biggestPossibleStartTimeframe;

    //     uint32 counter;

    //     startIndex += 1;

    //     for (uint256 i = 0; i < timeframes.length; i++) {
    //         if (startIndex + timeframes[i] <= endIndex) {
    //             biggestPossibleStartTimeframe =
    //                 ((endIndex - startIndex) / timeframes[i]) *
    //                 timeframes[i];
    //             runningDownIndex = biggestPossibleStartTimeframe; // 168
    //             runningUpIndex = biggestPossibleStartTimeframe; // 168
    //             break;
    //         }
    //     }

    //     for (uint256 i = 0; i < timeframes.length; i++) {
    //         while (runningUpIndex + timeframes[i] <= endIndex) {
    //             uint256 adjustedIndex = timeframes.length - 1 - i;
    //             cumulativeInterestRates +=
    //                 fetchTimeScaledRateIndex(
    //                     adjustedIndex,
    //                     token,
    //                     runningUpIndex / timeframes[i] // 168 / 168 = 1
    //                 ).interestRate *
    //                 timeframes[i];

    //             cumulativeBorrowProportion +=
    //                 fetchTimeScaledRateIndex(
    //                     adjustedIndex,
    //                     token,
    //                     runningUpIndex / timeframes[i] // 168 / 168 = 1
    //                 ).borrowProportionAtIndex *
    //                 timeframes[i];

    //             runningUpIndex += timeframes[i];
    //             counter++;
    //         }

    //         // Calculate cumulative interest rates for decreasing indexes
    //         while (
    //             runningDownIndex >= startIndex &&
    //             runningDownIndex - startIndex >= timeframes[i]
    //         ) {
    //             uint256 adjustedIndex = timeframes.length - 1 - i;

    //             cumulativeInterestRates +=
    //                 fetchTimeScaledRateIndex(
    //                     adjustedIndex,
    //                     token,
    //                     runningDownIndex / timeframes[i]
    //                 ).interestRate *
    //                 timeframes[i];

    //             cumulativeBorrowProportion +=
    //                 fetchTimeScaledRateIndex(
    //                     adjustedIndex,
    //                     token,
    //                     runningUpIndex / timeframes[i] // 168 / 168 = 1
    //                 ).borrowProportionAtIndex *
    //                 timeframes[i];

    //             counter++;

    //             runningDownIndex -= timeframes[i];
    //         }
    //     }

    //     if (
    //         cumulativeInterestRates == 0 || (endIndex - (startIndex - 1)) == 0
    //     ) {
    //         return 0;
    //     }

    //     return
    //         (cumulativeInterestRates / (endIndex - (startIndex - 1))) *
    //         (cumulativeBorrowProportion / (endIndex - (startIndex - 1)));
    // }
    /// @notice updates intereest epochs, fills in the struct of data for a new index
    /// @param token the token being targetted
    /// @param index the index of the period
    /// @param value the value
    /*
function updateInterestIndex(
    address token,
    uint256 index,
    uint256 value
) public checkRoleAuthority {
    uint256 currentIndex = currentInterestIndex[token];
    uint16[5] memory periods = [1, 24, 168, 672, 8736];

    currentInterestIndex[token] = index + 1;

    for (uint256 i = 0; i < periods.length; i++) {
        if (index % periods[i] == 0) {
            uint256 periodIndex = currentIndex / periods[i];
            
            if (i == 0) {
             InterestRateEpochs[i][token][periodIndex].interestRate = value;
             InterestRateEpochs[i][token][periodIndex].lastUpdatedTime = block.timestamp;
            InterestRateEpochs[i][token][periodIndex].totalLiabilitiesAtIndex = Datahub.returnAssetLogs(token).totalBorrowedAmount;
            InterestRateEpochs[i][token][periodIndex].totalAssetSuplyAtIndex = Datahub.returnAssetLogs(token).totalAssetSupply;
            InterestRateEpochs[i][token][periodIndex].rateInfo = InterestRateEpochs[i][token][periodIndex].rateInfo;
            } else {
                InterestRateEpochs[i][token][periodIndex].interestRate = EVO_LIBRARY.calculateAverage(
                    fetchRatesList(
                        currentIndex - (periods[i] - 1),
                        currentIndex,
                        token
                    )
                );
            }

            InterestRateEpochs[i][token][periodIndex].lastUpdatedTime = block.timestamp;
            InterestRateEpochs[i][token][periodIndex].totalLiabilitiesAtIndex = Datahub.returnAssetLogs(token).totalBorrowedAmount;
            InterestRateEpochs[i][token][periodIndex].totalAssetSuplyAtIndex = Datahub.returnAssetLogs(token).totalAssetSupply;
            InterestRateEpochs[i][token][periodIndex].borrowProportionAtIndex = EVO_LIBRARY.calculateAverage(
                utils.fetchBorrowProportionList(
                    currentIndex - (periods[i] - 1),
                    currentIndex,
                    token
                )
            );

            InterestRateEpochs[i][token][periodIndex].rateInfo = InterestRateEpochs[i][token][periodIndex - 1].rateInfo;
        }
    }
}
*/
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

        InterestRateEpochs[0][token][uint(currentInterestIndex[token])]
            .interestRate = value;

        InterestRateEpochs[0][token][uint(currentInterestIndex[token])]
            .lastUpdatedTime = block.timestamp;

        InterestRateEpochs[0][token][uint(currentInterestIndex[token])]
            .totalLiabilitiesAtIndex = Datahub
            .returnAssetLogs(token)
            .totalBorrowedAmount;

        InterestRateEpochs[0][token][uint(currentInterestIndex[token])]
            .totalAssetSuplyAtIndex = Datahub
            .returnAssetLogs(token)
            .totalAssetSupply;

        InterestRateEpochs[0][token][uint(currentInterestIndex[token])]
            .borrowProportionAtIndex = EVO_LIBRARY.calculateBorrowProportion(
            Datahub.returnAssetLogs(token)
        );

        InterestRateEpochs[0][token][uint(currentInterestIndex[token])]
            .rateInfo = InterestRateEpochs[0][token][
            uint(currentInterestIndex[token]) - 1
        ].rateInfo;

        if (index % 24 == 0) {
            // 168
            InterestRateEpochs[1][token][uint(currentInterestIndex[token] / 24)]
                .interestRate = EVO_LIBRARY.calculateAverage(
                fetchRatesList(
                    currentInterestIndex[token] - 23, // 1
                    currentInterestIndex[token], //24
                    token
                )
            );
            InterestRateEpochs[1][token][uint(currentInterestIndex[token] / 24)]
                .lastUpdatedTime = block.timestamp;
            InterestRateEpochs[1][token][uint(currentInterestIndex[token] / 24)]
                .totalLiabilitiesAtIndex = Datahub
                .returnAssetLogs(token)
                .totalBorrowedAmount;

            InterestRateEpochs[1][token][uint(currentInterestIndex[token] / 24)]
                .totalAssetSuplyAtIndex = Datahub
                .returnAssetLogs(token)
                .totalAssetSupply;

            InterestRateEpochs[1][token][uint(currentInterestIndex[token] / 24)]
                .borrowProportionAtIndex = EVO_LIBRARY.calculateAverage(
                utils.fetchBorrowProportionList(
                    currentInterestIndex[token] - 23, // 1
                    currentInterestIndex[token], //24
                    token
                )
            );

            InterestRateEpochs[1][token][uint(currentInterestIndex[token] / 24)]
                .rateInfo = InterestRateEpochs[1][token][
                uint(currentInterestIndex[token]) - 1
            ].rateInfo;
        }
        if (index % 168 == 0) {
            InterestRateEpochs[2][token][
                uint(currentInterestIndex[token] / 168)
            ].interestRate = EVO_LIBRARY.calculateAverage(
                fetchRatesList(
                    currentInterestIndex[token] - 167,
                    currentInterestIndex[token],
                    token
                )
            );

            InterestRateEpochs[2][token][
                uint(currentInterestIndex[token] / 168)
            ].lastUpdatedTime = block.timestamp;
            InterestRateEpochs[2][token][
                uint(currentInterestIndex[token] / 168)
            ].totalLiabilitiesAtIndex = Datahub
                .returnAssetLogs(token)
                .totalBorrowedAmount;

            InterestRateEpochs[2][token][
                uint(currentInterestIndex[token] / 168)
            ].borrowProportionAtIndex = EVO_LIBRARY.calculateAverage(
                utils.fetchBorrowProportionList(
                    currentInterestIndex[token] - 167,
                    currentInterestIndex[token],
                    token
                )
            );

            InterestRateEpochs[2][token][
                uint(currentInterestIndex[token] / 168)
            ].rateInfo = InterestRateEpochs[2][token][
                uint(currentInterestIndex[token]) - 1
            ].rateInfo;
        }
        if (index % 672 == 0) {
            InterestRateEpochs[3][token][
                uint(currentInterestIndex[token] / 672) //8736, 672, 168, 24
            ].interestRate = EVO_LIBRARY.calculateAverage(
                fetchRatesList(
                    currentInterestIndex[token] - 671,
                    currentInterestIndex[token],
                    token
                )
            );
            InterestRateEpochs[3][token][
                uint(currentInterestIndex[token] / 672)
            ].lastUpdatedTime = block.timestamp;
            InterestRateEpochs[3][token][
                uint(currentInterestIndex[token] / 672)
            ].totalLiabilitiesAtIndex = Datahub
                .returnAssetLogs(token)
                .totalBorrowedAmount;

            InterestRateEpochs[3][token][
                uint(currentInterestIndex[token] / 672)
            ].borrowProportionAtIndex = EVO_LIBRARY.calculateAverage(
                utils.fetchBorrowProportionList(
                    currentInterestIndex[token] - 671,
                    currentInterestIndex[token],
                    token
                )
            );

            InterestRateEpochs[3][token][
                uint(currentInterestIndex[token] / 672)
            ].rateInfo = InterestRateEpochs[3][token][
                uint(currentInterestIndex[token]) - 1
            ].rateInfo;
        }
        if (index % 8736 == 0) {
            InterestRateEpochs[4][token][
                uint(currentInterestIndex[token] / 8736)
            ].interestRate = EVO_LIBRARY.calculateAverage(
                fetchRatesList(
                    currentInterestIndex[token] - 8735,
                    currentInterestIndex[token],
                    token
                )
            );
            InterestRateEpochs[4][token][
                uint(currentInterestIndex[token] / 8736)
            ].lastUpdatedTime = block.timestamp;
            InterestRateEpochs[4][token][
                uint(currentInterestIndex[token] / 8736)
            ].totalLiabilitiesAtIndex = Datahub
                .returnAssetLogs(token)
                .totalBorrowedAmount;
            InterestRateEpochs[4][token][
                uint(currentInterestIndex[token] / 8736)
            ].borrowProportionAtIndex = EVO_LIBRARY.calculateAverage(
                utils.fetchBorrowProportionList(
                    currentInterestIndex[token] - 8735,
                    currentInterestIndex[token],
                    token
                )
            );
            InterestRateEpochs[4][token][
                uint(currentInterestIndex[token] / 8736)
            ].rateInfo = InterestRateEpochs[4][token][
                uint(currentInterestIndex[token]) - 1
            ].rateInfo;
        }
    }
    /// @notice returns a list of interest rates for a set amount of indexs or hours
    function fetchRatesList(
        uint256 startingIndex,
        uint256 endingIndex,
        address token
    ) private view returns (uint256[] memory) {
        uint256[] memory interestRatesForThePeriod = new uint256[](
            (endingIndex) - startingIndex
        );
        uint counter = 0;
        for (uint256 i = startingIndex; i < endingIndex; i++) {
            interestRatesForThePeriod[counter] = InterestRateEpochs[0][token][i]
                .interestRate;

            counter += 1;
        }
        return interestRatesForThePeriod;
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
        if (
            fetchRateInfo(token, fetchCurrentRateIndex(token)).lastUpdatedTime +
                1 hours <=
            block.timestamp
        ) {
            // console.log("current index");
            // console.log(fetchCurrentRateIndex(token));
            // // console.log("assetlogs");
            // // console.log(Datahub.returnAssetLogs(token));
            // console.log("rate info");
            // console.log(fetchRateInfo(token, fetchCurrentRateIndex(token)));

            updateInterestIndex(
                token,
                fetchCurrentRateIndex(token),
                EVO_LIBRARY.calculateInterestRate(
                    0,
                    Datahub.returnAssetLogs(token),
                    fetchRateInfo(token, fetchCurrentRateIndex(token))
                )
            );

            // console.log("current index after update",  fetchRateInfo(token, fetchCurrentRateIndex(token)).interestRate);
            uint256 currentInterestRateHourly = (
                fetchRateInfo(token, fetchCurrentRateIndex(token)).interestRate
            ) / 8736;
            // total borroed amount * current interest rate -> up total borrowed amount by this fucking value
            Datahub.setTotalBorrowedAmount(
                token,
                (((Datahub.returnAssetLogs(token).totalBorrowedAmount) *
                    (currentInterestRateHourly)) / 10 ** 18),
                true
            );
        }
    }

    function returnInterestCharge(
        address user,
        address token,
        uint256 liabilitiesAccrued
    ) public view returns (uint256) {
        (, uint256 liabilities, , , ) = Datahub.ReadUserData(user, token);
        uint256 interestCharge = EVO_LIBRARY.calculateCompoundedLiabilities(
            fetchCurrentRateIndex(token),
            calculateAverageCumulativeInterest(
                Datahub.viewUsersInterestRateIndex(user, token),
                fetchCurrentRateIndex(token),
                token
            ),
            Datahub.returnAssetLogs(token),
            fetchRateInfo(token, fetchCurrentRateIndex(token)),
            liabilitiesAccrued,
            liabilities,
            Datahub.viewUsersInterestRateIndex(user, token)
        );
        return interestCharge;
    }

    receive() external payable {}
}
/*


*/
