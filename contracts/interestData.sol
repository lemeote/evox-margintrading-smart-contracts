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
        // console.log((interestInfo[token][index].interestRate) / 8736);
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

    function calculateCompoundedLiabilities(
        address token,
        uint256 newLiabilities,
        uint256 usersLiabilities,
        uint256 usersOriginIndex
    ) public view returns (uint256) {
        uint256 amountOfBilledHours = fetchCurrentRateIndex(token) -
            usersOriginIndex;

        uint256 adjustedNewLiabilities = newLiabilities *
            (1 + fetchCurrentRate(token));

        uint256 initalMarginFeeAmount;

        if (adjustedNewLiabilities == 0) {
            initalMarginFeeAmount = 0;
        } else {
            initalMarginFeeAmount = REX_LIBRARY.calculateinitialMarginFeeAmount(
                    Executor.returnAssetLogs(token),
                    newLiabilities
                );
        }
        if (usersLiabilities == 0) {
            return
                ((adjustedNewLiabilities + initalMarginFeeAmount) -
                    newLiabilities) / 10 ** 18;
        } else {
            uint256 interestCharge;
            uint256 averageHourly;

            averageHourly += calculateAverageCumulativeInterest(
                usersOriginIndex,
                fetchCurrentRateIndex(token),
                token
            ); //
            // 8736;

            averageHourly = averageHourly / 8736;
            averageHourly += 1e18;

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
            console.log(averageHourly, "average hourly");
            uint256 compoundedLiabilities = usersLiabilities * averageHourly;
            // hourlyChargesBase;
            console.log(compoundedLiabilities / 10 ** 18, "compoundede libs");
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

        function calculateHourlyCharges(address token, uint256 startindex, uint256 runningIndex, uint256 cumulativeInterestRates, uint256 cumulativeTimeToAverage) private view returns(uint256[3] memory) {
                 for (
                uint256 i = startindex;
                i <= fetchCurrentRateIndex(token);
                i++
            ) {
                cumulativeInterestRates += (fetchRate(token, i));
                runningIndex++;
                cumulativeTimeToAverage++;
                console.log(cumulativeTimeToAverage, runningIndex, "details from hour loop");
                if (
                    runningIndex >= 48 &&
                    fetchCurrentRateIndex(token) - startindex >= 48
                ) {
                    break;
                }
            }    

            return [runningIndex, cumulativeInterestRates, cumulativeTimeToAverage];
        }

    function calculateAverageCumulativeInterest(
        uint256 startindex, // 1
        uint256 endindex, //27
        address token
    ) public view returns (uint256) {
        uint256 cumulativeInterestRates = 0;
        uint256 cumulativeTimeToAverage = 0;

        // uint256[4] memory timeframes = [year, month, week, day];
        uint16[4] memory hoursInTimeframe = [8736, 672, 168, 24];

        uint256 runningIndex = startindex;
        uint256 largestTimeframe = 0;
        uint256 largestTimeframeIndex = 0;
        uint256 AverageRateApplied;

        uint16[4] memory hoursInTimeframeDescending = [24, 168, 672, 8736];

        if (
            (startindex % 24 != 0 ||
                startindex % 168 != 0 ||
                startindex % 672 != 0 ||
                startindex % 8736 != 0) &&
            startindex < fetchCurrentRateIndex(token) && runningIndex + hoursInTimeframeDescending[0] <= endindex
        ) {
        uint256[3] memory rateInfo = calculateHourlyCharges(token,startindex,runningIndex,cumulativeInterestRates, cumulativeTimeToAverage);
        runningIndex = rateInfo[0];
        cumulativeInterestRates = rateInfo[1];
        cumulativeTimeToAverage = rateInfo[2];

        }
        console.log(runningIndex, endindex, " detials i want");
        if(runningIndex >= endindex){
            AverageRateApplied = REX_LIBRARY.calculateAverageOfValue(
            cumulativeInterestRates,
            cumulativeTimeToAverage
        );
            return AverageRateApplied ;
        }
      //  console.log("we got here so.....");
       //  console.log(runningIndex, "running index");

        // Find the largest timeframe based on hours in debt
        // if 8600 + 8736 =< 20,000    --> this is correct it will spit yearly monthly or weekly, or dailt
        largestTimeframe =hoursInTimeframeDescending[0];
        largestTimeframeIndex = 0;
        console.log(runningIndex + hoursInTimeframeDescending[0] <= endindex);
        console.log(runningIndex, hoursInTimeframeDescending[0], endindex, "data requested");
        for (uint256 i = 0; i < hoursInTimeframeDescending.length; i++) {
            if (runningIndex + hoursInTimeframeDescending[i] <= endindex) {
                largestTimeframe = hoursInTimeframeDescending[i];
                largestTimeframeIndex = i;
            } else {
                break;
            }
        }

        uint256 currentSmallerTimeframe = 0;
        uint256 currentSmallerTimeframeIndex = 0;
        console.log(largestTimeframe, "largestTImeframe");

        if (largestTimeframe != 24) {
            while (
                runningIndex % largestTimeframe != 0 && runningIndex < endindex
            ) {
                currentSmallerTimeframe = 0;
                currentSmallerTimeframeIndex = 0;

                // Find the current smaller timeframe
                for (
                    uint256 i = 0;
                    i < hoursInTimeframeDescending.length;
                    i++
                ) {
                    // 8600 + 8736 <= endindex (true) && 8736 <=
                    if (
                        runningIndex + hoursInTimeframeDescending[i] <=
                        endindex &&
                        hoursInTimeframeDescending[i] <= largestTimeframe
                    ) {
                        currentSmallerTimeframe = hoursInTimeframeDescending[i]; // months
                        currentSmallerTimeframeIndex = i;
                    } else {
                        break;
                    }
                }

                // Scale down to the start time of the current smaller timeframe
                runningIndex += currentSmallerTimeframe;

          
                // Charge interest for the scaled-down timeframe
                cumulativeInterestRates +=
                    fetchTimeScaledRateIndex(
                        currentSmallerTimeframeIndex,
                        token,
                        runningIndex / currentSmallerTimeframe
                    ).interestRate *
                    currentSmallerTimeframe;
                cumulativeTimeToAverage += currentSmallerTimeframe;
            }
        } else {
            currentSmallerTimeframe = hoursInTimeframeDescending[0]; // months
            currentSmallerTimeframeIndex = 0;
        }
        // Charge the rates for the largest timeframe until reaching the end index

        while (runningIndex + largestTimeframe <= endindex) {
            cumulativeInterestRates +=
                fetchTimeScaledRateIndex(
                    largestTimeframeIndex,
                    token,
                    runningIndex / largestTimeframe
                ).interestRate *
                largestTimeframe;
            cumulativeTimeToAverage += largestTimeframe;
            runningIndex += largestTimeframe;
        }

        // Charge the rates for the remaining smaller timeframes
        for (uint256 i = 0; i < hoursInTimeframe.length; i++) {
            while (runningIndex + hoursInTimeframe[i] <= endindex) {
                cumulativeInterestRates +=
                    fetchTimeScaledRateIndex(i, token, hoursInTimeframe[i] / i)
                        .interestRate *
                    hoursInTimeframe[i];
                cumulativeTimeToAverage += hoursInTimeframe[i];
                runningIndex += hoursInTimeframe[i];
            }
        }

        if (runningIndex != endindex) {
            for (uint256 i = runningIndex; i < endindex; i++) {
                cumulativeInterestRates += (fetchRate(token, i));
                runningIndex++;
                cumulativeTimeToAverage += 1;
            }
        }
         AverageRateApplied = REX_LIBRARY.calculateAverageOfValue(
            cumulativeInterestRates,
            cumulativeTimeToAverage
        );

        console.log(
            cumulativeInterestRates,
            cumulativeTimeToAverage,
            AverageRateApplied,
            " average inputs and output"
        );

        return AverageRateApplied;
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
        return interestInfo[token][index].totalLiabilitiesAtIndex;
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
        interestInfo[token][currentInterestIndex[token]].interestRate = value;

        interestInfo[token][currentInterestIndex[token]]
            .rateInfo = interestInfo[token][currentInterestIndex[token] - 1]
            .rateInfo;

        interestInfo[token][currentInterestIndex[token]].lastUpdatedTime = block
            .timestamp;
        interestInfo[token][index].totalLiabilitiesAtIndex = Datahub
            .fetchTotalBorrowedAmount(token);

        if (index % 24 == 0) {
            // 168
            console.log("SET DAILY RATE");
            InterestRateEpochs[0][token][uint(currentInterestIndex[token] / 24)]
                .interestRate = REX_LIBRARY.calculateAverage(
                fetchRatesList(
                    currentInterestIndex[token] - 24, // 1
                    currentInterestIndex[token], //24
                    token
                )
            );
            console.log(
                InterestRateEpochs[0][token][1].interestRate,
                "daily rate"
            );

            InterestRateEpochs[0][token][uint(currentInterestIndex[token] / 24)]
                .lastUpdatedTime = block.timestamp;
            InterestRateEpochs[0][token][uint(currentInterestIndex[token] / 24)]
                .totalLiabilitiesAtIndex = Datahub.fetchTotalBorrowedAmount(
                token
            );
            InterestRateEpochs[0][token][uint(currentInterestIndex[token] / 24)]
                .rateInfo = interestInfo[token][currentInterestIndex[token]]
                .rateInfo;
        }
        if (index % 168 == 0) {
            console.log("SET WEEKLY RATE");
            InterestRateEpochs[1][token][
                uint(currentInterestIndex[token] / 168)
            ].interestRate = REX_LIBRARY.calculateAverage(
                fetchRatesList(
                    currentInterestIndex[token] - 168,
                    currentInterestIndex[token],
                    token
                )
            );
            console.log(
                InterestRateEpochs[1][token][
                    uint(currentInterestIndex[token] / 168)
                ].interestRate,
                "weekly rate"
            );

            InterestRateEpochs[1][token][
                uint(currentInterestIndex[token] / 168)
            ].lastUpdatedTime = block.timestamp;
            InterestRateEpochs[1][token][
                uint(currentInterestIndex[token] / 168)
            ].totalLiabilitiesAtIndex = Datahub.fetchTotalBorrowedAmount(token);

            InterestRateEpochs[1][token][
                uint(currentInterestIndex[token] / 168)
            ].rateInfo = interestInfo[token][currentInterestIndex[token]]
                .rateInfo;
        }
        if (index % 672 == 0) {
            console.log("SET MONTHLY RATE");
            InterestRateEpochs[2][token][
                uint(currentInterestIndex[token] / 672) //8736, 672, 168, 24
            ].interestRate = REX_LIBRARY.calculateAverage(
                fetchRatesList(
                    currentInterestIndex[token] - 672,
                    currentInterestIndex[token],
                    token
                )
            );
            InterestRateEpochs[2][token][
                uint(currentInterestIndex[token] / 672)
            ].lastUpdatedTime = block.timestamp;
            InterestRateEpochs[2][token][
                uint(currentInterestIndex[token] / 672)
            ].totalLiabilitiesAtIndex = Datahub.fetchTotalBorrowedAmount(token);

            InterestRateEpochs[2][token][
                uint(currentInterestIndex[token] / 672)
            ].rateInfo = interestInfo[token][currentInterestIndex[token]]
                .rateInfo;
        }
        if (index % 8736 == 0) {
            InterestRateEpochs[3][token][
                uint(currentInterestIndex[token] / 8736)
            ].interestRate = REX_LIBRARY.calculateAverage(
                fetchRatesList(
                    currentInterestIndex[token] - 8736,
                    currentInterestIndex[token],
                    token
                )
            );
            InterestRateEpochs[3][token][
                uint(currentInterestIndex[token] / 8736)
            ].lastUpdatedTime = block.timestamp;
            InterestRateEpochs[3][token][
                uint(currentInterestIndex[token] / 8736)
            ].totalLiabilitiesAtIndex = Datahub.fetchTotalBorrowedAmount(token);

            InterestRateEpochs[3][token][
                uint(currentInterestIndex[token] / 8736)
            ].rateInfo = interestInfo[token][currentInterestIndex[token]]
                .rateInfo;
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
            interestRatesForThePeriod[counter] = interestInfo[token][i]
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

        if (
            Datahub.fetchTotalBorrowedAmount(token) >
            fetchLiabilitiesOfIndex(token, index)
        ) {
            LiabilityDelta =
                Datahub.fetchTotalBorrowedAmount(token) -
                fetchLiabilitiesOfIndex(token, index);
            LiabilityToCharge -= LiabilityDelta;
        } else {
            LiabilityDelta =
                fetchLiabilitiesOfIndex(token, index) -
                Datahub.fetchTotalBorrowedAmount(token);

            LiabilityToCharge -= LiabilityDelta;
        }

        uint256 MassCharge = (LiabilityToCharge *
            ((fetchCurrentRate(token)) / 8760)) / 10 ** 18; // this has an erro i think
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
                chargeLiabilityDelta(token, fetchCurrentRateIndex(token) - 1), // why is this the case why do i need to -1..... oopsies?
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
    function fetchHoursInTimeSpan(
        uint EpochRateId
    ) public view returns (uint256) {
        uint[5] memory timeframes = [hour, day, week, month, year];
        return timeframes[EpochRateId] / hour;
    }

    function fetchHoursInTimeSpanDecending(
        uint EpochRateId
    ) public view returns (uint256) {
        uint[5] memory timeframes = [year, month, week, day, hour];
        return timeframes[EpochRateId] / hour;
    }
*/

/*else {
            uint256 interestCharge;
            /*
            uint256 hourlyCharges = (calculateInterestCharge(
                token,
                usersOriginIndex
            ) / 8736) ** amountOfBilledHours;

         uint256 compoundedLiabilities = ((usersLiabilities) *
              (1e18 + hourlyCharges)) / 10**18;
             

            uint256 compoundedLiabilities = 0;
            unchecked {
                compoundedLiabilities =
                    ((usersLiabilities) * //CHECK THIS
                        ((1e18 +
                            (calculateInterestCharge(token, usersOriginIndex) /
                                8736)) ** amountOfBilledHours)) /
                    (10 ** (18 * (amountOfBilledHours))); // line 322 we might be doing this hourly twice

                interestCharge = (compoundedLiabilities - usersLiabilities);
            }
            console.log( (calculateInterestCharge(token, usersOriginIndex) /
                                8736), "interest charge");
            console.log(amountOfBilledHours, "amount of blld hrs");
            console.log(compoundedLiabilities, "compounded liabilities");
            console.log(interestCharge, "interestCharge output");
            /*
                       interestCharge =
                    ((compoundedLiabilities +
                        adjustedNewLiabilities +
                        initalMarginFeeAmount)) -
                    ((usersLiabilities + newLiabilities));
            console.log(compoundedLiabilities,"compunded liab");
            console.log(adjustedNewLiabilities, "adjusted new should be 0 ");
            console.log(initalMarginFeeAmount, "inital margin fee should be 0");
            console.log("mock equation",(compoundedLiabilities +
                        adjustedNewLiabilities +
                        initalMarginFeeAmount));
            console.log(((usersLiabilities + newLiabilities)));
        
            
            console.log(interestCharge, "intereest charrgeee");
            */
//  return interestCharge;
// }
//  }

/*
    struct InterestDetails {
        uint256 interestRateTracker;
        uint256 counter;
    }

    function calculateInterestCharge(
        address token,
        uint256 usersOriginRateIndex
    ) private view returns (uint256) {
        uint256 TimeInHoursInDebt = fetchCurrentRateIndex(token) -
            usersOriginRateIndex +
            1; // we do this because we charged them 1 hour post trade we dont want to double charge

        // timehinhours in debt and use this
        uint256 convertedHoursInDebt = TimeInHoursInDebt * 3600;

        uint256 remainingTime = convertedHoursInDebt; // just hours in debt
        uint256 runningOriginIndex = usersOriginRateIndex;

        InterestDetails[5] memory interestDetails; // yearly, monthly, weekly, daily, hourly

        uint256[5] memory timeFrames = [year, month, week, day, hour];

        if (TimeInHoursInDebt == 0) {
            /// IMPORTANT UNDERSTAND THE IMPLICATIONS OF THIS ON A DEEPER LEVEL, WHAT IF THEY HAVE BEEN IN FOR 30 MINS AND CASH OUT? NO CHARGE??
            return 0;
        }
        // 24
        for (uint256 i = 0; i < 5; i++) {
            while (remainingTime >= timeFrames[i]) {
                uint256[4] memory details = calculateInterestResults(
                    remainingTime, // 26
                    runningOriginIndex, // 2
                    timeFrames[i], // 24
                    token
                );
                interestDetails[i].interestRateTracker += details[0]; // this adds up the hourly rates
                remainingTime = details[1];
                runningOriginIndex = details[2];
                interestDetails[i].counter = details[3];

                if (remainingTime <= 0) {
                    break;
                }
            }
            // console.log(interestDetails[i].interestRateTracker,interestDetails[i].counter, "should give me the interest and counter" );
            if (interestDetails[i].interestRateTracker != 0) {
                interestDetails[i].interestRateTracker = REX_LIBRARY
                    .calculateAverageOfValue(
                        interestDetails[i].interestRateTracker,
                        interestDetails[i].counter
                    );
            }
        }

        return calculateGrossRate(interestDetails);
    }

    function calculateGrossRate(
        InterestDetails[5] memory interestDetails
    ) private view returns (uint256) {
        uint256 numerator = 0;
        uint256 denominator = 0;

        for (uint i = 0; i < interestDetails.length; i++) {
            // console.log(interestDetails[i].counter, "should go up by 1 each cycle ");
            //   console.log(fetchHoursInTimeSpanDecending(i), "fetchgin the amount of hours in the timespan we are targetting should always be 1");
            //   console.log(interestDetails[i].interestRateTracker, "the interest rate tracker should give the bulk rate for the periods");
            numerator +=
                interestDetails[i].counter *
                fetchHoursInTimeSpanDecending(i) *
                interestDetails[i].interestRateTracker;
            denominator +=
                interestDetails[i].counter *
                fetchHoursInTimeSpanDecending(i);
        }

        //   console.log(numerator / denominator,fetchHoursInTimeSpanDecending(4),interestDetails[4].counter, "gross rate should scale");
        console.log(numerator / denominator);
        return numerator / denominator;
    }

    function calculateInterestResults(
        uint256 remainingTime, //26
        uint256 usersOriginRateIndex, // 2
        uint targetTimeFrame, // 24
        address token // pepe
    ) private view returns (uint256[4] memory) {
        uint[5] memory timeframes = [hour, day, week, month, year];

        if (targetTimeFrame == 3600) {
            targetTimeFrame = 0;
        }
        if (targetTimeFrame == 86400) {
            targetTimeFrame = 1;
        }
        if (targetTimeFrame == 604800) {
            targetTimeFrame = 2;
        }
        if (targetTimeFrame == 2419200) {
            targetTimeFrame = 3;
        }
        if (targetTimeFrame == 31449600) {
            targetTimeFrame = 4;
        }

        uint usersOriginTimeFrame = (usersOriginRateIndex * 3600) /
            timeframes[targetTimeFrame]; // 2 / 24 --> 0
        //
        // i.e if we want to find what year or month a user took their debt this will spit that out
        // if they took debt after the first rate year cycles done but not the second then it would be like 1.5
        uint usersOriginScaledDownTimeFrame;

        uint256 endingIndex;
        // cause if their origin year was 1 then would spit back 2 which is the orign of the next year

        // for here we have to do this
        // we know they have been in for over whatever target time frame we are on say a week right
        // we need to know how close they are to the next down rate like the days
        // if they are hours away from that then we scale up x hours to the day
        // then charge the day

        // if statement end index and start index

        if (targetTimeFrame != 0) {
            if (targetTimeFrame == 1) {
                usersOriginScaledDownTimeFrame = 0;
            } else {
                usersOriginScaledDownTimeFrame =
                    (usersOriginRateIndex * 3600) /
                    timeframes[targetTimeFrame - 1];
            }
            // need to find a better way to scale this down to 0 right now it returns 1 which is not a fucking scaled down timeframe
            endingIndex =
                (usersOriginTimeFrame + timeframes[targetTimeFrame]) /
                timeframes[targetTimeFrame - 1];

            console.log(endingIndex, "this is the ending index");
            console.log(
                usersOriginScaledDownTimeFrame,
                "this is the scaled down timefram"
            );
            // month that they took the debt on so it would be like 15 if they took the debt 3 months after the origin year
        } else {
            usersOriginScaledDownTimeFrame = usersOriginRateIndex;
            endingIndex = fetchCurrentRateIndex(token);
        }

        uint256[4] memory interestDetails = calculateInterest(
            targetTimeFrame, //
            usersOriginScaledDownTimeFrame, // months
            endingIndex, //
            remainingTime, // remaing time to bill
            token
        ); // this gets the next years month

        console.log(interestDetails[0], "gross rate ");
        console.log(interestDetails[1], "unbilled hrs");
        console.log(interestDetails[2], "users origin index ");
        console.log(interestDetails[3], " counter");

        return [
            interestDetails[0],
            interestDetails[1],
            interestDetails[2],
            interestDetails[3]
        ];
    }

/*
    function calculateInterest(
        uint EpochRateId,
        uint256 originRateIndex,
        uint256 endingIndex,
        uint256 unbilledHours,
        address token
    ) internal view returns (uint256[4] memory) {
        uint256 GrossRate = 0;

        uint256 CounterValue = 0;

        console.log(
            originRateIndex,
            endingIndex,
            "origin and ending rate index"
        );

        console.log(originRateIndex / endingIndex == 1, "a day rate");

        for (uint256 i = originRateIndex; i < endingIndex; i++) {
            if (EpochRateId == 0) {
                //  console.log((fetchRate(token, i) / 8736), "current hourly rate");
                GrossRate += (fetchRate(token, i) / 8736); // this is a yearly rate at the index this must be here /// or done in a later function
            } else {
                GrossRate += fetchTimeScaledRateIndex(EpochRateId, token, i)
                    .interestRate; // idivsion ehre by months to get average for the months
                console.log(GrossRate, "rate for day"); // divide by hours in year?
            }

            if ((fetchHoursInTimeSpan(EpochRateId) * 3600) >= unbilledHours) {
                unbilledHours = 0;
            } else {
                /// console.log( unbilledHours -= (fetchHoursInTimeSpan(EpochRateId) * 3600), "this is hitting");
                unbilledHours -= (fetchHoursInTimeSpan(EpochRateId) * 3600);
            }
            // console.log(fetchHoursInTimeSpan(EpochRateId), CounterValue, "this should be 24");

            originRateIndex += fetchHoursInTimeSpan(EpochRateId); // 24 --> 22 times

            CounterValue++;

            // EpochRateId == 0 ? CounterValue % 24 ?

            // originRateIndex = originRateIndex / CounterValue; // 24 / 24
        }
        //   EpochRateId == 0 ? CounterValue % 24 ?

        return [GrossRate, unbilledHours, originRateIndex, CounterValue];
    }
*/

/*
cumulativeInterestRates = 0
cumulativeTimeToAverage = 0

gatherUserTimeframesToBeCharged(startIndex + 1, endIndex){
   
if there are any year indexes where startHourOfYearIndex > startIndex+1 && endHourOfYearIndex < endIndex

  cumulativeInterestRates +=  interestRateOfYearIndex * 8736
  cumulativeTimeToAverage += 8736


 if there are any month indexes where the month start index and the month end index is greater 
 than the newest year index end index && less than the users end index

Add them the same way as above

if there are any month indexes where the month start index is less than
 the oldest year index start index && greater than the users startIndex+1 same shit as above

Rinse and repeat for all timeframes

Then (cumulativeInterestRate/cumulativeTimeToAverage) = Average Interest Rate


starting index ending index we know where we start billing from and where we end 

if amount of time in debt is less than the timeframe size dont check that just skip to the lower one 

use tinos conditionals --> if users index < index for the period -> go to lower timeframe to get it there
                            if users index 

conditionals:  if we can charge a time period --> if not we know to check the next lower down timeframe etc and go back up
i.e if index = y and y is < than timeframe start time descend and scale

we need two ver

scale up index --> we need to make sure that when a function runs that adds up rates we have an updated variable
that reflects what have we already charged be it months, weeks, days etc. 


parent function



running index 

biggest timeframe the user can be charged --> use their hours in debt 

scale up index 
scale down index 


y = usersStartIndex

x = amountOfDebtHours


we know what hour they got in and how many hours 

// we know for a fact we will need to use one of the smaller timeframes to work up in time 

// we know after we charge the largest and there is not bigger we have to go down
// we know that if we go R = Endindex - usersIndex = its going to be hours in debt and if R / year = 2
// we know we will only max scale them up a year




deliver the difference between the index origin in year timeframe, month,week day, 


usersStartingIndex /24  = 1.23


if(index = y and y is < than timeframe start time descend and scale ) 

if(index = y and y is < than timeframe start time descend and scale ) {
    auto scale
}

if(index = y and y is < than timeframe start time descend and scale ) 
{
 auto scale 
}
if(index = y and y is < than timeframe start time descend and scale ) {
 autoscale 

}
    function simpleForLoop(uint256 originIndex, uint256 endIndex) external pure returns (uint256) {
        uint256 result = 0;

        for (uint256 i = originIndex; i < endIndex; i++) {
            // Perform some operation here
            result += i;
        }

        return result;
    }




    function BIGBew(
        uint256 startindex,
        uint256 endindex,
        address token
    ) external view returns (uint256, uint256) {
        uint256 cumulativeInterestRates = 0;

        uint256 cumulativeTimeToAverage = 0;

        uint[4] memory timeframes = [year, month, week, day];

        uint16[4] memory hoursInTimeframe = [8736, 672, 168, 24];


            //uint BillStartTIme = startindex / hoursInTimeframe[i]; //good

            uint currentTimeframeIndex = fetchCurrentRateIndex(token) /
                hoursInTimeframe[0];

            for (uint256 j; j <= fetchCurrentRateIndex(token) /
                hoursInTimeframe[0]; ) {
                //if there are any year indexes where startHourOfYearIndex > startIndex+1 && endHourOfYearIndex < endIndex
                if (
                    j * i > startindex + 1 &&
                    ((j + 1) * hoursInTimeframe[i]) <= endindex
                ) {
                    // j = 1 * 8736 > users origin index + 1 && [ 1 + 1] * 8736 < ending index being currnet index
                    // 8600  8736 -- 17472 <= 20000
                    cumulativeInterestRates +=
                        fetchTimeScaledRateIndex(0, token, j).interestRate *
                        hoursInTimeframe[0]; //8736
                    cumulativeTimeToAverage += hoursInTimeframe[0]; // 8736
                }
                   unchecked {
                    ++j;
                }
                }
                //  if there are any month indexes where the month start index and the month end index is greater
                //than the newest year index end index && less than the users end index
                // 1 
                if (
                    j * (i - 1) > startindex + 1 &&
                    ((j + 1) * hoursInTimeframe[i - 1]) <= endindex
                ) {
                    cumulativeInterestRates +=
                        fetchTimeScaledRateIndex(i - 1, token, j).interestRate *
                        hoursInTimeframe[i - 1]; //8736
                    cumulativeTimeToAverage += hoursInTimeframe[i - 1]; // 8736
                }

                // if there are any month indexes where the month start index is less than
                //the oldest year index start index && greater than the users startIndex+1 same shit as above
                if (
                    j * (i - 2) > startindex + 1 &&
                    ((j + 1) * hoursInTimeframe[i - 2]) <= endindex
                ) {
                    cumulativeInterestRates +=
                        fetchTimeScaledRateIndex(i - 2, token, j).interestRate *
                        hoursInTimeframe[i - 2]; //8736
                    cumulativeTimeToAverage += hoursInTimeframe[i - 2]; // 8736
                }
                if (
                    j * (i - 3) > startindex + 1 &&
                    ((j + 1) * hoursInTimeframe[i - 3]) <= endindex
                ) {
                    cumulativeInterestRates +=
                        fetchTimeScaledRateIndex(i - 3, token, j).interestRate *
                        hoursInTimeframe[i - 3]; //8736
                    cumulativeTimeToAverage += hoursInTimeframe[i - 3]; // 8736
                }
         
            }
  
            //there are any year/month/week/day indexes where startHourOfYearIndex > startIndex+1 && endHourOfYearIndex < endIndex
        }
    }



    function calculateAverageCumulativeInterest(
        uint256 startindex,
        uint256 endindex,
        address token
    ) external view returns (uint256, uint256) {
        uint256 cumulativeInterestRates = 0;

        uint256 cumulativeTimeToAverage = 0;

        uint[4] memory timeframes = [year, month, week, day];

        uint16[4] memory hoursInTimeframe = [8736, 672, 168, 24];


            //uint BillStartTIme = startindex / hoursInTimeframe[i]; //good

            uint currentTimeframeIndex = fetchCurrentRateIndex(token) /
                hoursInTimeframe[0];

            /// usrs current time period

            // start index 8,600
            // end index 20,000

            uint256 runningDownIndex = startindex;

            uint256 runningUpIndex = startindex;

                //if there are any year indexes where startHourOfYearIndex > startIndex+1 && endHourOfYearIndex < endIndex
                if (
                    j * i > startindex + 1 &&
                    ((j + 1) * hoursInTimeframe[i]) <= endindex
                ) {
// FIRST YEAR IF CHECK
                    // j = 1 * 8736 > users origin index + 1 && [ 1 + 1] * 8736 < ending index being currnet index
                    // 8600  8736 -- 17472 <= 2000
                    cumulativeInterestRates +=
                        fetchTimeScaledRateIndex(i, token, j).interestRate *
                        hoursInTimeframe[i]; //8736
                    cumulativeTimeToAverage += hoursInTimeframe[i]; // 8736
                    runningDownIndex = i * hoursInTimeframe[0]; //8736
                    // i + 8736 + 8736?
                    // end inde xof year 2 if its
                    // if endof year 2 is greater than our current index charge it
                    // if 1 * 8736 > 8736 +  1
                    // 8600 > runningDownIndex - month && 17400 <= 20,000
                    if (
                        startindex + 1 > runningDownIndex - month &&
                        ((j + 1) * hoursInTimeframe[i]) <= endindex
                    ) {
// FIRST MONTHLY IF CHECK
                        cumulativeInterestRates +=
                            fetchTimeScaledRateIndex(i, token, j).interestRate *
                            hoursInTimeframe[i]; //8736
                        cumulativeTimeToAverage += hoursInTimeframe[i]; // 8736
                        runningDownIndex = i * hoursInTimeframe[i]; //8736

                        // 1 * 8736 > 8736 - week &&
                        if (
                            startindex + 1 > runningDownIndex - week &&
                            ((j + 1) * hoursInTimeframe[i]) <= endindex
                        ) {
// FIRST WEEKLY IF CHECK
                            cumulativeInterestRates +=
                                fetchTimeScaledRateIndex(i, token, j)
                                    .interestRate *
                                hoursInTimeframe[i]; //8736
                            cumulativeTimeToAverage += hoursInTimeframe[i]; // 8736
                            uint256 runningDownIndex = i * hoursInTimeframe[i]; //8736

                            if (
                                startindex + 1 > runningDownIndex - day &&
                                ((j + 1) * hoursInTimeframe[i]) <= endindex
                            ) {
// FIRST WEEKLY IF CHECK
                                cumulativeInterestRates +=
                                    fetchTimeScaledRateIndex(i, token, j)
                                        .interestRate *
                                    hoursInTimeframe[i]; //8736
                                cumulativeTimeToAverage += hoursInTimeframe[i]; // 8736
                                uint256 runningDownIndex = i *
                                    hoursInTimeframe[i]; //8736
                                if (
                                    startindex + 1 > runningDownIndex - 1 &&
                                    ((j + 1) * hoursInTimeframe[i]) <= endindex
                                ) {
// FIRST HOURLY IF CHECK
                                    cumulativeInterestRates +=
                                        fetchTimeScaledRateIndex(i, token, j)
                                            .interestRate *
                                        hoursInTimeframe[i]; //8736
                                    cumulativeTimeToAverage += hoursInTimeframe[
                                        i
                                    ]; // 8736
                                    uint256 runningDownIndex = i *
                                        hoursInTimeframe[i]; //8736
                                }
                            }
                        }}}}

*/
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
