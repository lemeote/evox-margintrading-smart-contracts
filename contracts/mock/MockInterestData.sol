// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../interfaces/IDataHub.sol";
import "../interfaces/IExecutor.sol";
import "../interfaces/IUtilityContract.sol";
import "../libraries/EVO_LIBRARY.sol";

import "../interestData.sol";

import "hardhat/console.sol";

contract MockInterestData is interestData {
    constructor(address initialOwner, address _executor, address _dh, address _utils, address _dv) interestData(initialOwner, _executor, _dh, _utils, _dv) {}

    function setInterestIndex(address token, uint256 dimension, uint256 index, uint256 value) public {

        InterestRateEpochs[dimension][token][index].interestRate = value;

        InterestRateEpochs[dimension][token][index].lastUpdatedTime = block.timestamp;

        InterestRateEpochs[dimension][token][index].totalLiabilitiesAtIndex = Datahub.returnAssetLogs(token).totalBorrowedAmount;

        InterestRateEpochs[dimension][token][index].totalAssetSuplyAtIndex = Datahub.returnAssetLogs(token).totalAssetSupply;

        InterestRateEpochs[dimension][token][index].borrowProportionAtIndex = EVO_LIBRARY.calculateBorrowProportion(Datahub.returnAssetLogs(token));

        InterestRateEpochs[dimension][token][index].rateInfo = InterestRateEpochs[dimension][token][index - 1].rateInfo;
    }

    function calculateAverageCumulativeInterest_test(
        uint256 startIndex,
        uint256 endIndex,
        address token
    ) public view returns (uint256) {
        // console.log("calculateAverageCumulativeInterest_test function");
        uint256 cumulativeInterestRates = 0;
        uint16[5] memory timeframes = [8736, 600, 200, 10, 1];
        // console.log("calculateAverageCumulativeInterest_test function");

        uint256 runningUpIndex = startIndex;
        uint256 runningDownIndex = endIndex;
        uint256 biggestPossibleStartTimeframe;
        
        startIndex = startIndex + 1; // For calculating untouched and cause of gas fee

        // console.log("calculateAverageCumulativeInterest_test function");

        for (uint256 i = 0; i < timeframes.length; i++) {
            // console.log("timeframe", i, timeframes[i]);
            if ( startIndex + timeframes[i] - 1 <= endIndex) { // For spliting
                // console.log("timeframe passed", timeframes[i]);
                biggestPossibleStartTimeframe = (startIndex / timeframes[i]) * timeframes[i];

                // console.log("biggestPossibleStartTimeframe", biggestPossibleStartTimeframe );

                if(( startIndex % timeframes[i]) > 0 ) {
                    biggestPossibleStartTimeframe += timeframes[i];
                }  
                
                // console.log("biggestPossibleStartTimeframe", biggestPossibleStartTimeframe );
                
                runningUpIndex = biggestPossibleStartTimeframe + 1;
                runningDownIndex = biggestPossibleStartTimeframe;
                // console.log("runningUpIndex", runningUpIndex);
                break;
            }
        }

        // console.log("runningUpIndex", runningUpIndex );
        // console.log("runningDownIndex", runningDownIndex );
        // console.log("stsartIndex", startIndex);
        // console.log("endIndex", endIndex);

        for (uint256 i = 0; i < timeframes.length; i++) {
            // console.log("timeframes", timeframes[i]);
            while ((runningUpIndex + timeframes[i] - 1) <= endIndex) {
                // this inverses the list order due to interest being stored in the opposite index format 0-4
                uint256 adjustedIndex = timeframes.length - 1 - i;
                // console.log("adjusted index", adjustedIndex);
                // console.log("runningUpIndex", runningUpIndex);
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
                // console.log("counter", counter);
            }

            // Calculate cumulative interest rates for decreasing indexes
            while ((runningDownIndex >= timeframes[i]) && ((runningDownIndex - timeframes[i] + 1) >= startIndex)) {
                //&& available
                uint256 adjustedIndex = timeframes.length - 1 - i;
                // console.log("runningDownIndex", runningDownIndex);
                cumulativeInterestRates +=
                    fetchTimeScaledRateIndex(
                        adjustedIndex,
                        token,
                        runningDownIndex / timeframes[i]
                    ).interestRate *
                    timeframes[i];

                // console.log("cumulativeInterestRates", cumulativeInterestRates);

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

    function updateInterestIndexTest(
        address token,
        uint256 index, // 24
        uint256 value
    ) public {
        // console.log("=======================Update Interest Index Function========================");
        // console.log("index", index);
        // console.log("value", value);
        currentInterestIndex[token] = index + 1; // 25
        uint8[5] memory timeframes = [1, 2, 4, 8, 16];
        uint256 period_start;
        uint256 period_interval;
        uint256 borrowProportion;
        uint256 interestReate;

        // borrowProportion = EVO_LIBRARY.calculateBorrowProportion(
        //     Datahub.returnAssetLogs(token)
        // );
        // borrowProportion = 0;

        setInterestRateEpoch(
            0,
            token,
            uint(currentInterestIndex[token]),
            borrowProportion,
            value
        );

        for (uint256 i = 1; i < timeframes.length; i++) {
            if( (currentInterestIndex[token] % timeframes[i]) == 0 ) {
                // console.log("///////////////////////start//////////////////////////");
                // console.log("index - timeframe", currentInterestIndex[token], timeframes[i]);
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
                // borrowProportion = 0;
                // console.log("period interval", period_interval);
                // console.log("start", period_start);
                // console.log("end", period_start + period_interval - 1);
                interestReate = EVO_LIBRARY.calculateAverage(
                    utils.fetchRatesList(
                        i - 1,
                        period_start, // 1
                        period_start + period_interval - 1, //24
                        token
                    )
                );
                // console.log("interest rate", interestReate);
                // interestReate = value;
                setInterestRateEpoch(
                    i,
                    token,
                    uint(currentInterestIndex[token] / timeframes[i]),
                    borrowProportion,
                    interestReate
                );
                // console.log("////////////////////end/////////////////////");
            }
        }
    }
}
