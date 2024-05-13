// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import "../interfaces/IDataHub.sol";
import "../interfaces/IinterestData.sol";
import "hardhat/console.sol";
library EVO_LIBRARY {
    function createArray(address user) public pure returns (address[] memory) {
        address[] memory users = new address[](1);
        users[0] = user;
        return users;
    }

    function createNumberArray(
        uint256 amount
    ) public pure returns (uint256[] memory) {
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        return amounts;
    }

    function calculateTotal(
        uint256[] memory amounts
    ) external pure returns (uint256) {
        uint256 total;
        for (uint256 i = 0; i < amounts.length; i++) {
            total += amounts[i];
        }
        return total;
    }

    function calculateAverage(
        uint256[] memory values
    ) public pure returns (uint256) {
        // console.log("length", values.length);
        if (values.length == 0) {
            return 0;
        }
        uint256 total;
        uint256 value = 0;
        for (uint256 i = 0; i < values.length; i++) {
            total += values[i];
        }
        value = total / values.length;
        // console.log("average value", value);
        return value;
    }

    function calculateAverageOfValue(
        uint256 value,
        uint divisor
    ) public pure returns (uint256) {
        if (value / divisor == 0) {
            return 0;
        }
        if (divisor == 0) {
            return 0;
        }
        if (value == 0) {
            return 0;
        }
        uint256 total = value / divisor;
        return total;
    }

    function normalize(
        uint256 x
    ) public pure returns (uint256 base, int256 exp) {
        // console.log("=============normalize function=================");
        exp = 0;
        base = x;

        while (base > 1e18) {
            base = base / 10;
            // console.log("base", base);
            exp = exp + 1;
        }
        // console.log("===============end==============");
    }

    function calculateInterestRate(
        uint256 amount,
        IDataHub.AssetData memory assetlogs,
        IInterestData.interestDetails memory interestRateInfo
    ) public pure returns (uint256) {
        // console.log("======================calculate interest rate function===========================");
        // uint256 borrowProportion = ((assetlogs.totalBorrowedAmount + amount) * 10 ** 18) / assetlogs.totalAssetSupply; /// check for div by 0
        uint256 borrowProportion = ((assetlogs.assetInfo[1] + amount) * 10 ** 18) / assetlogs.assetInfo[0]; /// 0 -> totalAssetSupply 1 -> totalBorrowedAmount
        // console.log("borrow proportion", borrowProportion);
        // also those will need to be updated on every borrow (trade) and every deposit -> need to write in

        uint256 optimalBorrowProportion = assetlogs.borrowPosition[0]; // 0 -> optimalBorrowProportion
        // console.log("optimal Borrow Proportion", optimalBorrowProportion);

        uint256 minimumInterestRate = interestRateInfo.rateInfo[0];
        uint256 optimalInterestRate = interestRateInfo.rateInfo[1];
        uint256 maximumInterestRate = interestRateInfo.rateInfo[2];
        // console.log("minimumInterestRate", minimumInterestRate);
        // console.log("optimalInterestRate", optimalInterestRate);
        // console.log("maximumInterestRate", maximumInterestRate);

        if (borrowProportion <= optimalBorrowProportion) {
            uint256 rate = optimalInterestRate - minimumInterestRate; // 0.145
            // console.log("rate", rate);
            // console.log("result", min(
            //     optimalInterestRate,
            //     minimumInterestRate +
            //         (rate * borrowProportion) /
            //         optimalBorrowProportion
            // ));
            return
                min(
                    optimalInterestRate,
                    minimumInterestRate +
                        (rate * borrowProportion) /
                        optimalBorrowProportion
                );
        } else {
            uint256 rate = maximumInterestRate - optimalInterestRate;
            // console.log("rate", rate);
            // console.log("result", min(
            //     maximumInterestRate,
            //     optimalInterestRate +
            //         (rate * (borrowProportion - optimalBorrowProportion)) /
            //         (1e18 - optimalBorrowProportion)
            // ));
            return
                min(
                    maximumInterestRate,
                    optimalInterestRate +
                        (rate * (borrowProportion - optimalBorrowProportion)) /
                        (1e18 - optimalBorrowProportion)
                );
        }
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function calculatedepositLiabilityRatio(
        uint256 liabilities,
        uint256 deposit_amount
    ) public pure returns (uint256) {
        return ((deposit_amount * 10 ** 18) / liabilities); /// fetch decimals integration?
    }

    function calculateinitialMarginFeeAmount(
        IDataHub.AssetData memory assetdata,
        uint256 liabilities
    ) public pure returns (uint256) {
        return (assetdata.feeInfo[0] * liabilities) / 10 ** 18; // 0 -> initialMarginFee
    }

    function calculateInitialRequirementForTrade(
        IDataHub.AssetData memory assetdata,
        uint256 amount
    ) public pure returns (uint256) {
        uint256 initial = assetdata.marginRequirement[0]; // 0 -> InitialMarginRequirement
        // console.log("maintenance", maintenance);
        return (initial * (amount)) / 10 ** 18;
    }

    function calculateMaintenanceRequirementForTrade(
        IDataHub.AssetData memory assetdata,
        uint256 amount
    ) public pure returns (uint256) {
        // console.log("margin requirement", assetdata.marginRequirement[1]);
        uint256 maintenance = assetdata.marginRequirement[1]; // 1 -> MaintenanceMarginRequirement
        // console.log("maintenance", maintenance);
        return (maintenance * (amount)) / 10 ** 18;
    } // 13 deimcals to big

    function calculateBorrowProportion(
        IDataHub.AssetData memory assetdata
    ) public pure returns (uint256) {
        return
            (assetdata.assetInfo[1] * 10 ** 18) /
            assetdata.assetInfo[0]; // 0 -> totalAssetSupply, 1 -> totalBorrowedAmount
    }

    function calculateBorrowProportionAfterTrades(
        IDataHub.AssetData memory assetdata,
        uint256 new_liabilities
    ) public pure returns (bool) {
        // console.log("====================calculateBorrowProportionAfterTrades========================");
        uint256 scaleFactor = 1e18; // Scaling factor, e.g., 10^18 for wei

        // here we add the current borrowed amount and the new liabilities to be issued, and scale it
        uint256 scaledTotalBorrowed = (assetdata.assetInfo[1] +
            new_liabilities) * scaleFactor; // 1 -> totalBorrowedAmount

        // console.log("scaledTotalBorrowed", scaledTotalBorrowed);

        // Calculate the new borrow proportion
        uint256 newBorrowProportion = (scaledTotalBorrowed /
            assetdata.assetInfo[0]); // totalAssetSupply

        // console.log("newBorrowProportion", newBorrowProportion);

        // console.log("maximum borrow propotion", assetdata.borrowPosition[1]);

        // Compare with maximumBorrowProportion
        return newBorrowProportion <= assetdata.borrowPosition[1]; // 1 -> maximumBorrowProportion
    }

    function calculateFee(
        uint256 _amount,
        uint256 _fee
    ) public pure returns (uint256) {
        if (_fee == 0) return 0;
        return (_amount * (_fee)) / (10 ** 4);
    }

    function calculateCompoundedAssets(
        uint256 currentIndex,
        uint256 AverageCumulativeDepositInterest,
        uint256 usersAssets,
        uint256 usersOriginIndex
    ) public pure returns (uint256, uint256, uint256) {
        uint256 earningHours = currentIndex - usersOriginIndex;
        // console.log("Billed Hours", earningHours);

        uint256 DaoInterestCharge;
        uint256 OrderBookProviderCharge;
        uint256 interestCharge;

        uint256 averageHourly = 1e18 + AverageCumulativeDepositInterest / 8736;

        (uint256 averageHourlyBase, int256 averageHourlyExp) = normalize(
            averageHourly
        );
        averageHourlyExp = averageHourlyExp - 18;

        uint256 hourlyChargesBase = 1;
        int256 hourlyChargesExp = 0;
        while (earningHours > 0) {
            if (earningHours % 2 == 1) {
                (uint256 _base, int256 _exp) = normalize(
                    (hourlyChargesBase * averageHourlyBase)
                );

                hourlyChargesBase = _base;
                hourlyChargesExp = hourlyChargesExp + averageHourlyExp + _exp;
            }
            (uint256 _bases, int256 _exps) = normalize(
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
                    // we split up the whole balance and divide it by the deposittor, the order book provider, and the DAO

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
        uint256 currentIndex, // token index
        uint256 AverageCumulativeInterest,
        IDataHub.AssetData memory assetdata,
        IInterestData.interestDetails memory interestRateInfo,
        uint256 newLiabilities,
        uint256 usersLiabilities,
        uint256 usersOriginIndex
    ) public pure returns (uint256) {
        // console.log("=====================calculateCompundedLiabilities Function======================");
        uint256 amountOfBilledHours = currentIndex - usersOriginIndex;
        // if(usersOriginIndex == 1) {
        //     amountOfBilledHours = amountOfBilledHours + 1; // lower gas fee than amountOfBilledHours++
        // }
        // console.log("amount of billed hours", amountOfBilledHours);

        // calculate what the rate would be after their trade and charge that

        uint256 adjustedNewLiabilities = (newLiabilities *
            // (1e18 + (fetchCurrentRate(token) / 8736))) / (10 ** 18);
            (1e18 +
                (calculateInterestRate(
                    newLiabilities,
                    assetdata,
                    interestRateInfo
                ) / 8736))) / (10 ** 18);
        // console.log("adjustedNewLiabilities", adjustedNewLiabilities);
        uint256 initalMarginFeeAmount;

        if (newLiabilities == 0) {
            initalMarginFeeAmount = 0;
        } else {
            initalMarginFeeAmount = calculateinitialMarginFeeAmount(
                assetdata,
                newLiabilities
            );
        }

        // console.log("initalMarginFeeAmount", initalMarginFeeAmount);

        if (newLiabilities != 0) {
            // console.log("result", (adjustedNewLiabilities + initalMarginFeeAmount) -
            // newLiabilities);
            return
                (adjustedNewLiabilities + initalMarginFeeAmount) -
                newLiabilities;
        } else {
            uint256 interestCharge;

            uint256 averageHourly = 1e18 + AverageCumulativeInterest / 8736;
            // console.log("averageHourly", averageHourly);

            (uint256 averageHourlyBase, int256 averageHourlyExp) = normalize(
                averageHourly
            );
            // console.log("averageHourlyBase", averageHourlyBase);
            // console.log("averageHourlyExp", averageHourlyExp);
            averageHourlyExp = averageHourlyExp - 18;

            uint256 hourlyChargesBase = 1;
            int256 hourlyChargesExp = 0;

            while (amountOfBilledHours > 0) {
                if (amountOfBilledHours % 2 == 1) {
                    (uint256 _base, int256 _exp) = normalize(
                        (hourlyChargesBase * averageHourlyBase)
                    );

                    hourlyChargesBase = _base;
                    hourlyChargesExp =
                        hourlyChargesExp +
                        averageHourlyExp +
                        _exp;
                }
                (uint256 _bases, int256 _exps) = normalize(
                    (averageHourlyBase * averageHourlyBase)
                );
                averageHourlyBase = _bases;
                averageHourlyExp = averageHourlyExp + averageHourlyExp + _exps;

                amountOfBilledHours /= 2;
            }

            // console.log("hourlyChargesBase", hourlyChargesBase);

            uint256 compoundedLiabilities = usersLiabilities *
                hourlyChargesBase;

            // console.log("compoundedLiabilities", compoundedLiabilities);

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

                // console.log("compoundedLiabilities", compoundedLiabilities);
                // console.log("user liabilities", usersLiabilities);
                // console.log("interest rate", compoundedLiabilities - usersLiabilities);

                interestCharge =
                    (compoundedLiabilities +
                        adjustedNewLiabilities +
                        initalMarginFeeAmount) -
                    (usersLiabilities + newLiabilities);
                // console.log("interestCharge", interestCharge);
            }
            return interestCharge;
        }
    }
}
