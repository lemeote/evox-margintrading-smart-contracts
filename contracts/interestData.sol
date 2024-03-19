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

    mapping(uint => mapping(address => mapping(uint256 => IInterestData.interestDetails))) InterestRateEpochs;

    mapping(address => uint256) currentInterestIndex;

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
        return InterestRateEpochs[0][token][index];
    }

    /// @notice Explain to an end user what this does
    /// @dev Explain to a developer any extra details
    /// @param token the token being targetted
    /// @param index the index of the period
    function fetchRate(
        address token,
        uint256 index
    ) public view returns (uint256) {
        // console.log((interestInfo[token][index].interestRate) / 8736);
        return InterestRateEpochs[0][token][index].interestRate;
    }

    /// @notice Explain to an end user what this does
    /// @dev Explain to a developer any extra details
    /// @param token the token being targetted
    function fetchCurrentRate(address token) public view returns (uint256) {
        return
            InterestRateEpochs[0][token][uint(currentInterestIndex[token])]
                .interestRate;
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

    function calculateCompoundedAssets(
        address token,
        uint256 usersAssets,
        uint256 usersOriginIndex
    ) public view returns (uint256) {
        uint256 interestCharge;
        uint256 earningHours = fetchCurrentRateIndex(token) - usersOriginIndex;

        uint256 averageHourly = 1e18 +
            calculateAverageCumulativeInterest(
                usersOriginIndex,
                fetchCurrentRateIndex(token),
                token
            ) /
            8736;

        (uint256 averageHourlyBase, int256 averageHourlyExp) = REX_LIBRARY
            .normalize(averageHourly);
        averageHourlyExp = averageHourlyExp - 18;

        uint256 hourlyChargesBase = 1;
        int256 hourlyChargesExp = 0;
        while (earningHours > 0) {
            if (earningHours % 2 == 1) {
                (uint256 _base, int256 _exp) = REX_LIBRARY.normalize(
                    (hourlyChargesBase * averageHourlyBase)
                );

                hourlyChargesBase = _base;
                hourlyChargesExp = hourlyChargesExp + averageHourlyExp + _exp;
            }
            (uint256 _bases, int256 _exps) = REX_LIBRARY.normalize(
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
        }
        return interestCharge;
    }

    function calculateCompoundedLiabilities(
        address token,
        uint256 newLiabilities,
        uint256 usersLiabilities,
        uint256 usersOriginIndex
    ) public view returns (uint256) {
        uint256 amountOfBilledHours = fetchCurrentRateIndex(token) -
            usersOriginIndex;

        uint256 adjustedNewLiabilities = (newLiabilities *
            (1e18 + (fetchCurrentRate(token) / 8736))) / (10 ** 18);

        uint256 initalMarginFeeAmount;

        if (newLiabilities == 0) {
            initalMarginFeeAmount = 0;
        } else {
            initalMarginFeeAmount = REX_LIBRARY.calculateinitialMarginFeeAmount(
                    Executor.returnAssetLogs(token),
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

            console.log(averageHourly, "average hourly");

            (uint256 averageHourlyBase, int256 averageHourlyExp) = REX_LIBRARY
                .normalize(averageHourly);
            averageHourlyExp = averageHourlyExp - 18;

            uint256 hourlyChargesBase = 1;
            int256 hourlyChargesExp = 0;

            while (amountOfBilledHours > 0) {
                if (amountOfBilledHours % 2 == 1) {
                    (uint256 _base, int256 _exp) = REX_LIBRARY.normalize(
                        (hourlyChargesBase * averageHourlyBase)
                    );

                    hourlyChargesBase = _base;
                    hourlyChargesExp =
                        hourlyChargesExp +
                        averageHourlyExp +
                        _exp;
                }
                (uint256 _bases, int256 _exps) = REX_LIBRARY.normalize(
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
            console.log(interestCharge, "interestssss less gooo");
            return interestCharge;
        }
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
                biggestPossibleStartTimeframe = startIndex / timeframes[i];
                runningDownIndex = biggestPossibleStartTimeframe;
                runningUpIndex = biggestPossibleStartTimeframe;
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
                        runningUpIndex / timeframes[i]
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
        // Return the cumulative interest rates
        return cumulativeInterestRates / (endIndex - (startIndex - 1));
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

    function fetchLiabilitiesOfIndex(
        address token,
        uint256 index
    ) private view returns (uint256) {
        return InterestRateEpochs[0][token][index].totalLiabilitiesAtIndex;
    }

    /// @notice Explain to an end user what this does
    /// @dev Explain to a developer any extra details
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

        InterestRateEpochs[0][token][uint(currentInterestIndex[token])]
            .lastUpdatedTime = block.timestamp;

        InterestRateEpochs[0][token][uint(currentInterestIndex[token])]
            .totalLiabilitiesAtIndex = Datahub.fetchTotalBorrowedAmount(token);
        InterestRateEpochs[0][token][uint(currentInterestIndex[token])]
            .borrowProportionAtIndex = REX_LIBRARY.calculateBorrowProportion(
            Executor.returnAssetLogs(token)
        );

        InterestRateEpochs[0][token][uint(currentInterestIndex[token])]
            .rateInfo = InterestRateEpochs[0][token][
            uint(currentInterestIndex[token]) - 1
        ].rateInfo;

        if (index % 24 == 0) {
            // 168
            console.log("SET DAILY RATE");
            InterestRateEpochs[1][token][uint(currentInterestIndex[token] / 24)]
                .interestRate = REX_LIBRARY.calculateAverage(
                fetchRatesList(
                    currentInterestIndex[token] - 24, // 1
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
                .borrowProportionAtIndex = REX_LIBRARY
                .calculateBorrowProportion(Executor.returnAssetLogs(token));
            InterestRateEpochs[1][token][uint(currentInterestIndex[token] / 24)]
                .rateInfo = InterestRateEpochs[1][token][
                uint(currentInterestIndex[token]) - 1
            ].rateInfo;
        }
        if (index % 168 == 0) {
            console.log("SET WEEKLY RATE");
            InterestRateEpochs[2][token][
                uint(currentInterestIndex[token] / 168)
            ].interestRate = REX_LIBRARY.calculateAverage(
                fetchRatesList(
                    currentInterestIndex[token] - 168,
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
            ].borrowProportionAtIndex = REX_LIBRARY.calculateBorrowProportion(
                Executor.returnAssetLogs(token)
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
            ].interestRate = REX_LIBRARY.calculateAverage(
                fetchRatesList(
                    currentInterestIndex[token] - 672,
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
            ].borrowProportionAtIndex = REX_LIBRARY.calculateBorrowProportion(
                Executor.returnAssetLogs(token)
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
            ].interestRate = REX_LIBRARY.calculateAverage(
                fetchRatesList(
                    currentInterestIndex[token] - 8736,
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
            ].borrowProportionAtIndex = REX_LIBRARY.calculateBorrowProportion(
                Executor.returnAssetLogs(token)
            );

            InterestRateEpochs[4][token][
                uint(currentInterestIndex[token] / 8736)
            ].rateInfo = InterestRateEpochs[4][token][
                uint(currentInterestIndex[token]) - 1
            ].rateInfo;
        }
    }

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
    /// @param index the index of the period
    /// @return MassCharge
    function chargeStaticLiabilityInterest(
        address token,
        uint256 index
    ) public view returns (uint256) {
        uint256 LiabilityToCharge = Datahub.fetchTotalBorrowedAmount(token);
        uint256 LiabilityDelta;

        if (
            Datahub.fetchTotalBorrowedAmount(token) >
            fetchLiabilitiesOfIndex(token, index)
        ) {
            LiabilityDelta =
                Datahub.fetchTotalBorrowedAmount(token) -
                fetchLiabilitiesOfIndex(token, index);
            LiabilityToCharge += LiabilityDelta;
        } else {
            LiabilityDelta =
                fetchLiabilitiesOfIndex(token, index) -
                Datahub.fetchTotalBorrowedAmount(token);

            LiabilityToCharge -= LiabilityDelta;
        }

        uint256 MassCharge = (LiabilityToCharge *
            ((fetchCurrentRate(token)) / 8736)) / 10 ** 18;
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
                chargeStaticLiabilityInterest(
                    token,
                    fetchCurrentRateIndex(token) - 1
                ), // why is this the case why do i need to -1..... oopsies?
                true
            );

            updateInterestIndex(
                token,
                fetchCurrentRateIndex(token),
                REX_LIBRARY.calculateInterestRate(
                    chargeStaticLiabilityInterest(
                        token,
                        fetchCurrentRateIndex(token)
                    ),
                    Datahub.returnAssetLogs(token),
                    fetchRateInfo(token, fetchCurrentRateIndex(token))
                )
            );
        }
    }

    receive() external payable {}
}
