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
        console.log((interestInfo[token][index].interestRate) / 8736);
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


        }else {
            uint256 interestCharge;
            uint256 averageHourly = 1e18 + calculateInterestCharge(
                token,
                usersOriginIndex
            ) / 8736;

            (uint256 averageHourlyBase, int256 averageHourlyExp) = REX_LIBRARY.normalize(averageHourly);
            averageHourlyExp = averageHourlyExp - 18;

            uint256 hourlyChargesBase = 1;
            int256 hourlyChargesExp = 0;
            
            while (amountOfBilledHours > 0) {
                if (amountOfBilledHours % 2 == 1) {
                    (uint256 _base, int256 _exp) = REX_LIBRARY.normalize((hourlyChargesBase * averageHourlyBase));

                    hourlyChargesBase = _base;
                    hourlyChargesExp = hourlyChargesExp + averageHourlyExp + _exp;
                }
                (uint256 _bases, int256 _exps) = REX_LIBRARY.normalize((averageHourlyBase * averageHourlyBase));
                averageHourlyBase = _bases;
                averageHourlyExp = averageHourlyExp + averageHourlyExp + _exps;

                amountOfBilledHours /= 2;
            }

            uint256 compoundedLiabilities = usersLiabilities * hourlyChargesBase;

            unchecked {
                if(hourlyChargesExp >= 0) {
                    compoundedLiabilities = compoundedLiabilities * (10 ** uint256(hourlyChargesExp));
                } else {
                    compoundedLiabilities = compoundedLiabilities / (10 ** uint256(-hourlyChargesExp));
                }

                interestCharge =
                    (compoundedLiabilities +
                        adjustedNewLiabilities +
                        initalMarginFeeAmount) -
                    (usersLiabilities + newLiabilities);

            }
            console.log(interestCharge, "interestssss less gooo");
            return interestCharge;
        } /*else {
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

        if (TimeInHoursInDebt == 0) {
            /// IMPORTANT UNDERSTAND THE IMPLICATIONS OF THIS ON A DEEPER LEVEL, WHAT IF THEY HAVE BEEN IN FOR 30 MINS AND CASH OUT? NO CHARGE??
            return 0;
        }
        for (uint256 i = 0; i < 5; i++) {
            while (remainingTime >= timeFrames[i]) {
                uint256[4] memory details = calculateInterestResults(
                    remainingTime,
                    runningOriginIndex,
                    timeFrames[i],
                    token
                );
                interestDetails[i].interestRateTracker += details[0]; // this adds up the hourly rates
                remainingTime = details[1];
                runningOriginIndex = details[2];
                interestDetails[i].counter = details[3];

                console.log(
                    interestDetails[4].counter,
                    "counter should be going up by 1 each time on the 4th index"
                );
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
                console.log(
                    interestDetails[i].interestRateTracker,
                    "rate tracker value average rate"
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
        uint256 remainingTime,
        uint256 usersOriginRateIndex,
        uint targetTimeFrame,
        address token
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
            timeframes[targetTimeFrame];
        // i.e if we want to find what year or month a user took their debt this will spit that out
        // if they took debt after the first rate year cycles done but not the second then it would be like 1.5
        uint usersOriginScaledDownTimeFrame;

        uint256 endingIndex;
        // cause if their origin year was 1 then would spit back 2 which is the orign of the next year
        if (targetTimeFrame != 0) {
            usersOriginScaledDownTimeFrame =
                (usersOriginRateIndex * 3600) /
                timeframes[targetTimeFrame - 1]; // --> use this and go if its like 10 scale to 12
            endingIndex =
                (usersOriginTimeFrame + timeframes[targetTimeFrame]) /
                timeframes[targetTimeFrame - 1];
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

    function calculateInterest(
        uint EpochRateId,
        uint256 originRateIndex,
        uint256 endingIndex,
        uint256 unbilledHours,
        address token
    ) internal view returns (uint256[4] memory) {
        uint256 GrossRate = 0;

        uint256 CounterValue;

        for (uint256 i = originRateIndex; i < endingIndex; i++) {
            if (EpochRateId == 0) {
                //  console.log((fetchRate(token, i) / 8736), "current hourly rate");
                GrossRate += (fetchRate(token, i) / 8736); // this is a yearly rate at the index this must be here /// or done in a later function
            } else {
                GrossRate += fetchTimeScaledRateIndex(EpochRateId, token, i)
                    .interestRate; // idivsion ehre by months to get average for the months
            }

            if ((fetchHoursInTimeSpan(EpochRateId) * 3600) >= unbilledHours) {
                unbilledHours = 0;
            } else {
                /// console.log( unbilledHours -= (fetchHoursInTimeSpan(EpochRateId) * 3600), "this is hitting");
                unbilledHours -= (fetchHoursInTimeSpan(EpochRateId) * 3600);
            }
            // console.log("this should be 1",fetchHoursInTimeSpan(EpochRateId));
            originRateIndex += fetchHoursInTimeSpan(EpochRateId);

            CounterValue++;
        }

        return [GrossRate, unbilledHours, originRateIndex, CounterValue];
    }

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
                uint(currentInterestIndex[token] / (24 * 7))
            ].interestRate = REX_LIBRARY.calculateAverage(
                fetchRatesList(
                    currentInterestIndex[token] - 24 * 7,
                    currentInterestIndex[token],
                    token
                )
            );
            InterestRateEpochs[1][token][
                uint(currentInterestIndex[token] / (24 * 7))
            ].lastUpdatedTime = block.timestamp;
            InterestRateEpochs[1][token][
                uint(currentInterestIndex[token] / (24 * 7))
            ].totalLiabilitiesAtIndex = Datahub.fetchTotalBorrowedAmount(token);

            InterestRateEpochs[1][token][
                uint(currentInterestIndex[token] / (24 * 7))
            ].rateInfo = interestInfo[token][currentInterestIndex[token]]
                .rateInfo;
        }
        if (index % 672 == 0) {
            console.log("SET MONTHLY RATE");
            InterestRateEpochs[2][token][
                uint(currentInterestIndex[token] / (24 * month))
            ].interestRate = REX_LIBRARY.calculateAverage(
                fetchRatesList(
                    currentInterestIndex[token] - 24 * month,
                    currentInterestIndex[token],
                    token
                )
            );
            InterestRateEpochs[2][token][
                uint(currentInterestIndex[token] / (24 * month))
            ].lastUpdatedTime = block.timestamp;
            InterestRateEpochs[2][token][
                uint(currentInterestIndex[token] / (24 * month))
            ].totalLiabilitiesAtIndex = Datahub.fetchTotalBorrowedAmount(token);

            InterestRateEpochs[2][token][
                uint(currentInterestIndex[token] / (24 * month))
            ].rateInfo = interestInfo[token][currentInterestIndex[token]]
                .rateInfo;
        }
        if (index % 8736 == 0) {
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

            InterestRateEpochs[3][token][
                uint(currentInterestIndex[token] / (24 * year))
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
