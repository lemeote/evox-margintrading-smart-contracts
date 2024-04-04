// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import "./interfaces/IDataHub.sol";
import "./interfaces/IExecutor.sol";
import "./interfaces/IUtilityContract.sol";
import "hardhat/console.sol";
import "./libraries/EVO_LIBRARY.sol";

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

        uint32 counter;

        startIndex += 1;

        for (uint256 i = 0; i < timeframes.length; i++) {
            if (startIndex + timeframes[i] <= endIndex) {
                biggestPossibleStartTimeframe =
                    ((endIndex - startIndex) / timeframes[i]) *
                    timeframes[i];
                runningDownIndex = biggestPossibleStartTimeframe; // 168
                runningUpIndex = biggestPossibleStartTimeframe; // 168
                break;
            }
        }
        for (uint256 i = 0; i < timeframes.length; i++) {
            while (runningUpIndex + timeframes[i] <= endIndex) {
                // this inverses the list order due to interest being stored in the opposite index format 0-4
                uint256 adjustedIndex = timeframes.length - 1 - i;
                cumulativeInterestRates +=
                    fetchTimeScaledRateIndex(
                        adjustedIndex,
                        token,
                        runningUpIndex / timeframes[i] // 168 / 168 = 1
                    ).interestRate *
                    timeframes[i];

                runningUpIndex += timeframes[i];
                counter++;
            }

            // Calculate cumulative interest rates for decreasing indexes
            while (
                runningDownIndex >= startIndex &&
                runningDownIndex >= timeframes[i]
            ) {
                //&& available
                uint256 adjustedIndex = timeframes.length - 1 - i;

                cumulativeInterestRates +=
                    fetchTimeScaledRateIndex(
                        adjustedIndex,
                        token,
                        runningDownIndex / timeframes[i]
                    ).interestRate *
                    timeframes[i];

                counter++;

                runningDownIndex -= timeframes[i];
            }
        }

        if (
            cumulativeInterestRates == 0 || (endIndex - (startIndex - 1)) == 0
        ) {
            return 0;
        }
        console.log(cumulativeInterestRates, "cumulative rate");
        // Return the cumulative interest rates
        return cumulativeInterestRates / (endIndex - (startIndex - 1));
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

        uint32 counter;

        startIndex += 1;

        for (uint256 i = 0; i < timeframes.length; i++) {
            if (startIndex + timeframes[i] <= endIndex) {
                biggestPossibleStartTimeframe =
                    ((endIndex - startIndex) / timeframes[i]) *
                    timeframes[i];
                runningDownIndex = biggestPossibleStartTimeframe; // 168
                runningUpIndex = biggestPossibleStartTimeframe; // 168
                break;
            }
        }

        for (uint256 i = 0; i < timeframes.length; i++) {
            while (runningUpIndex + timeframes[i] <= endIndex) {
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
                counter++;
            }

            // Calculate cumulative interest rates for decreasing indexes
            while (
                runningDownIndex >= startIndex &&
                runningDownIndex >= timeframes[i]
            ) {
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

                counter++;

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
        currentInterestIndex[token] = index + 1; // 25

        InterestRateEpochs[0][token][uint(currentInterestIndex[token])]
            .interestRate = value;

        console.log("hourly", value);

        InterestRateEpochs[0][token][uint(currentInterestIndex[token])]
            .lastUpdatedTime = block.timestamp;

        InterestRateEpochs[0][token][uint(currentInterestIndex[token])]
            .totalLiabilitiesAtIndex = Datahub.fetchTotalBorrowedAmount(token);
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
            console.log("SET DAILY RATE");
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
                .totalLiabilitiesAtIndex = Datahub.fetchTotalBorrowedAmount(
                token
            );
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
            console.log("SET WEEKLY RATE");
            InterestRateEpochs[2][token][
                uint(currentInterestIndex[token] / 168)
            ].interestRate = EVO_LIBRARY.calculateAverage(
                fetchRatesList(
                    currentInterestIndex[token] - 167,
                    currentInterestIndex[token],
                    token
                )
            );
            console.log(
                InterestRateEpochs[2][token][
                    uint(currentInterestIndex[token] / 168)
                ].interestRate,
                "weekly rate"
            );

            InterestRateEpochs[2][token][
                uint(currentInterestIndex[token] / 168)
            ].lastUpdatedTime = block.timestamp;
            InterestRateEpochs[2][token][
                uint(currentInterestIndex[token] / 168)
            ].totalLiabilitiesAtIndex = Datahub.fetchTotalBorrowedAmount(token);

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
            console.log("SET MONTHLY RATE");
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
            ].totalLiabilitiesAtIndex = Datahub.fetchTotalBorrowedAmount(token);

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
            ].totalLiabilitiesAtIndex = Datahub.fetchTotalBorrowedAmount(token);
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
            Datahub.setTotalBorrowedAmount(
                token,
                utils.chargeStaticLiabilityInterest(
                    token,
                    fetchCurrentRateIndex(token)
                ),
                true
            );

            updateInterestIndex(
                token,
                fetchCurrentRateIndex(token),
                EVO_LIBRARY.calculateInterestRate(
                    utils.chargeStaticLiabilityInterest(
                        token,
                        fetchCurrentRateIndex(token)
                    ),
                    Datahub.returnAssetLogs(token),
                    fetchRateInfo(token, fetchCurrentRateIndex(token))
                )
            );
        }
    }

    function returnCompoundedLiabilitiesOfUser(
        address user,
        address token
    ) public view returns (uint256) {
        (, uint256 liabilities, , , ) = Datahub.ReadUserData(user, token);

        uint256 interest = EVO_LIBRARY.calculateCompoundedLiabilities(
            fetchCurrentRateIndex(token),
            calculateAverageCumulativeInterest(
                Datahub.viewUsersInterestRateIndex(user, token),
                fetchCurrentRateIndex(token),
                token
            ),
            Datahub.returnAssetLogs(token),
            fetchRateInfo(token, fetchCurrentRateIndex(token)),
            0,
            liabilities,
            Datahub.viewUsersInterestRateIndex(user, token)
        );
        return interest;
    }

    receive() external payable {}
}

/*
    function calculateCompoundedAssets(
        address token,
        uint256 currentIndex,
        uint256 usersAssets,
        uint256 usersOriginIndex
    ) public view returns (uint256, uint256, uint256) {
        uint256 earningHours = fetchCurrentRateIndex(token) - usersOriginIndex;

        uint256 DaoInterestCharge;
        uint256 OrderBookProviderCharge;
        uint256 interestCharge;

        uint256 averageHourly = 1e18 +
            calculateAverageCumulativeDepositInterest(
                usersOriginIndex,
                fetchCurrentRateIndex(token),
                token
            ) /
            8736;

        (uint256 averageHourlyBase, int256 averageHourlyExp) = EVO_LIBRARY
            .normalize(averageHourly);
        averageHourlyExp = averageHourlyExp - 18;

        uint256 hourlyChargesBase = 1;
        int256 hourlyChargesExp = 0;
        while (earningHours > 0) {
            if (earningHours % 2 == 1) {
                (uint256 _base, int256 _exp) = EVO_LIBRARY.normalize(
                    (hourlyChargesBase * averageHourlyBase)
                );

                hourlyChargesBase = _base;
                hourlyChargesExp = hourlyChargesExp + averageHourlyExp + _exp;
            }
            (uint256 _bases, int256 _exps) = EVO_LIBRARY.normalize(
                (averageHourlyBase * averageHourlyBase)
            );
            averageHourlyBase = _bases;
            averageHourlyExp = averageHourlyExp + averageHourlyExp + _exps;

            earningHours /= 2;
        }

        uint256 compoundedAssets = usersAssets * hourlyChargesBase;

        unchecked {
            if (hourlyChargesExp >= 0) {
                compoundedAssets =
                    compoundedAssets *
                    (10 ** uint256(hourlyChargesExp));
            } else {
                compoundedAssets =
                    compoundedAssets /
                    (10 ** uint256(-hourlyChargesExp));
            }

            interestCharge = compoundedAssets - usersAssets;

            if (interestCharge > 0) {
                if (interestCharge > 100 wei) {
                    interestCharge = interestCharge / 100;

                    interestCharge *= 80;

                    OrderBookProviderCharge *= 2;

                    DaoInterestCharge *= 18;
                }
            }
        } // 20 / 80
        return (interestCharge, OrderBookProviderCharge, DaoInterestCharge);
        // now for this it will always returtn 80% of their actual interest --> to do this splits we scale up to 100% then take the 20%
    }

    function calculateCompoundedLiabilities(
        address token,
        uint256 newLiabilities,
        uint256 usersLiabilities,
        uint256 usersOriginIndex
    ) public view returns (uint256) {
        uint256 amountOfBilledHours = fetchCurrentRateIndex(token) -
            usersOriginIndex;

        // calculate what the rate would be after their trade and charge that

        uint256 adjustedNewLiabilities = (newLiabilities *
            // (1e18 + (fetchCurrentRate(token) / 8736))) / (10 ** 18);
            (1e18 +
                (EVO_LIBRARY.calculateInterestRate(
                    newLiabilities,
                    Datahub.returnAssetLogs(token),
                    InterestRateEpochs[0][token][fetchCurrentRateIndex(token)]
                ) / 8736))) / (10 ** 18);
        uint256 initalMarginFeeAmount;

        if (newLiabilities == 0) {
            initalMarginFeeAmount = 0;
        } else {
            initalMarginFeeAmount = EVO_LIBRARY.calculateinitialMarginFeeAmount(
                    Datahub.returnAssetLogs(token),
                    newLiabilities
                );
        }

        if (newLiabilities != 0) {
            return
                (adjustedNewLiabilities + initalMarginFeeAmount) -
                newLiabilities;
        } else {
            uint256 interestCharge;

            uint256 averageHourly = 1e18 +
                calculateAverageCumulativeInterest(
                    usersOriginIndex,
                    fetchCurrentRateIndex(token),
                    token
                ) /
                8736;

            (uint256 averageHourlyBase, int256 averageHourlyExp) = EVO_LIBRARY
                .normalize(averageHourly);
            averageHourlyExp = averageHourlyExp - 18;

            uint256 hourlyChargesBase = 1;
            int256 hourlyChargesExp = 0;

            while (amountOfBilledHours > 0) {
                if (amountOfBilledHours % 2 == 1) {
                    (uint256 _base, int256 _exp) = EVO_LIBRARY.normalize(
                        (hourlyChargesBase * averageHourlyBase)
                    );

                    hourlyChargesBase = _base;
                    hourlyChargesExp =
                        hourlyChargesExp +
                        averageHourlyExp +
                        _exp;
                }
                (uint256 _bases, int256 _exps) = EVO_LIBRARY.normalize(
                    (averageHourlyBase * averageHourlyBase)
                );
                averageHourlyBase = _bases;
                averageHourlyExp = averageHourlyExp + averageHourlyExp + _exps;

                amountOfBilledHours /= 2;
            }

            uint256 compoundedLiabilities = usersLiabilities *
                hourlyChargesBase;

            // hourlyChargesBase;
            console.log(compoundedLiabilities, "compoundede libs");

            unchecked {
                if (hourlyChargesExp >= 0) {
                    compoundedLiabilities =
                        compoundedLiabilities *
                        (10 ** uint256(hourlyChargesExp));
                } else {
                    compoundedLiabilities =
                        compoundedLiabilities /
                        (10 ** uint256(-hourlyChargesExp));
                }

                interestCharge =
                    (compoundedLiabilities +
                        adjustedNewLiabilities +
                        initalMarginFeeAmount) -
                    (usersLiabilities + newLiabilities);
            }
            console.log(interestCharge, "interest");
            return interestCharge;
        }
    }
*/
