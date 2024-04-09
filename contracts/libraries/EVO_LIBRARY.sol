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
    ) external view returns (uint256) {
        uint256 total;
        for (uint256 i = 0; i < amounts.length; i++) {
            total += amounts[i];
        }
        return total;
    }

    function calculateAverage(
        uint256[] memory values
    ) public view returns (uint256) {
        if (values.length == 0) {
            return 0;
        }
        uint256 total;
        uint256 value = 0;
        for (uint256 i = 0; i < values.length; i++) {
            total += values[i];
        }
        value = total / values.length;
        return value;
    }

    function calculateAverageOfValue(
        uint256 value,
        uint divisor
    ) public view returns (uint256) {
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
        exp = 0;
        base = x;

        while (base > 1e18) {
            base = base / 10;
            exp = exp + 1;
        }
    }

    function calculateInterestRate(
        uint256 amount,
        IDataHub.AssetData memory assetlogs,
        IInterestData.interestDetails memory interestRateInfo
    ) public view returns (uint256) {
        uint256 borrowProportion = ((assetlogs.totalBorrowedAmount + amount) *
            10 ** 18) / assetlogs.totalAssetSupply; /// check for div by 0
        // also those will need to be updated on every borrow (trade) and every deposit -> need to write in

        uint256 optimalBorrowProportion = assetlogs.optimalBorrowProportion;

        uint256 minimumInterestRate = interestRateInfo.rateInfo[0];
        uint256 optimalInterestRate = interestRateInfo.rateInfo[1];
        uint256 maximumInterestRate = interestRateInfo.rateInfo[2];

        if (borrowProportion <= optimalBorrowProportion) {
            uint256 rate = optimalInterestRate - minimumInterestRate;
            return
                min(
                    optimalInterestRate,
                    minimumInterestRate +
                        (rate * borrowProportion) /
                        optimalBorrowProportion
                );
        } else {
            uint256 rate = maximumInterestRate - optimalInterestRate;
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
    ) public view returns (uint256) {
        return (assetdata.initialMarginFee * liabilities) / 10 ** 18;
    }

    function calculateMaintenanceRequirementForTrade(
        IDataHub.AssetData memory assetdata,
        uint256 amount
    ) public view returns (uint256) {
        uint256 maintenance = assetdata.MaintenanceMarginRequirement; // 10 * 18 -> this function will output a 10*18 number
        return (maintenance * (amount)) / 10 ** 18;
    } // 13 deimcals to big

    function calculateBorrowProportion(
        IDataHub.AssetData memory assetdata
    ) public view returns (uint256) {
        return
            (assetdata.totalBorrowedAmount * 10 ** 18) /
            assetdata.totalAssetSupply; // 10 ** 18 output
    }

    function calculateBorrowProportionAfterTrades(
        IDataHub.AssetData memory assetdata,
        uint256 new_liabilities
    ) public view returns (bool) {
        uint256 scaleFactor = 1e18; // Scaling factor, e.g., 10^18 for wei

        // here we add the current borrowed amount and the new liabilities to be issued, and scale it
        uint256 scaledTotalBorrowed = (assetdata.totalBorrowedAmount +
            new_liabilities) * scaleFactor;

        // Calculate the new borrow proportion
        uint256 newBorrowProportion = (scaledTotalBorrowed /
            assetdata.totalAssetSupply); // equal decimal * 10**!8 decimal is max

        // Compare with maximumBorrowProportion
        return newBorrowProportion <= assetdata.maximumBorrowProportion;
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
    ) public view returns (uint256, uint256, uint256) {
        uint256 earningHours = currentIndex - usersOriginIndex;

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
        uint256 currentIndex,
        uint256 AverageCumulativeInterest,
        IDataHub.AssetData memory assetdata,
        IInterestData.interestDetails memory interestRateInfo,
        uint256 newLiabilities,
        uint256 usersLiabilities,
        uint256 usersOriginIndex
    ) public view returns (uint256) {
        uint256 amountOfBilledHours = currentIndex - usersOriginIndex;

        // calculate what the rate would be after their trade and charge that

        uint256 adjustedNewLiabilities = (newLiabilities *
            // (1e18 + (fetchCurrentRate(token) / 8736))) / (10 ** 18);
            (1e18 +
                (calculateInterestRate(
                    newLiabilities,
                    assetdata,
                    interestRateInfo
                ) / 8736))) / (10 ** 18);
        uint256 initalMarginFeeAmount;

        if (newLiabilities == 0) {
            initalMarginFeeAmount = 0;
        } else {
            initalMarginFeeAmount = calculateinitialMarginFeeAmount(
                assetdata,
                newLiabilities
            );
        }

        if (newLiabilities != 0) {
            return
                (adjustedNewLiabilities + initalMarginFeeAmount) -
                newLiabilities;
        } else {
            uint256 interestCharge;

            uint256 averageHourly = 1e18 + AverageCumulativeInterest / 8736;

            (uint256 averageHourlyBase, int256 averageHourlyExp) = normalize(
                averageHourly
            );
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

            uint256 compoundedLiabilities = usersLiabilities *
                hourlyChargesBase;

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
            return interestCharge;
        }
    }
}
