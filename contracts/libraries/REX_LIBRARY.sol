// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import "../interfaces/IDataHub.sol";


library REX_LIBRARY {
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

    // NEEDS REVIEW

    /*
    function calculateInterestRate(
        uint256 amount,
        IDataHub.AssetData memory assetdata
    ) public pure returns (uint256) {
        uint256 borrowProportion = ((assetdata.totalBorrowedAmount * 10**18) + amount) /
            assetdata.totalAssetSupply; /// check for div by 0
        // also those will need to be updated on every borrow (trade) and every deposit -> need to write in

        uint256 interestRate;
        uint256 optimalBorrowProportion = assetdata.optimalBorrowProportion;

        uint256 minimumInterestRate = assetdata.interestRateInfo[0];
        uint256 optimalInterestRate = assetdata.interestRateInfo[1];
        uint256 maximumInterestRate = assetdata.interestRateInfo[2];

        if (borrowProportion <= assetdata.optimalBorrowProportion) {
     
            interestRate = min(
                optimalInterestRate,
                minimumInterestRate +
                    (optimalInterestRate - minimumInterestRate) *
                    (borrowProportion / optimalBorrowProportion)
            );
        } else {
            interestRate = min(
                maximumInterestRate,
                optimalInterestRate +
                    (maximumInterestRate - optimalInterestRate) *
                    ((borrowProportion - optimalBorrowProportion) /
                        (1e18 - optimalBorrowProportion))
            );
        }

        return interestRate;
    }

*/
    function calculateInterestRate(
        uint256 amount,
        IDataHub.AssetData memory assetlogs,
        IDataHub.interestDetails memory interestRateInfo
    ) public view returns (uint256) {
        uint256 borrowProportion = ((assetlogs.totalBorrowedAmount) +
            amount * 10 ** 18) / assetlogs.totalAssetSupply; /// check for div by 0
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
}
