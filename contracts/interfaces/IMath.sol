// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import "./IDataHub.sol";
import "./IinterestData.sol";
import "hardhat/console.sol";
contract IMath {
  function calculateInterestRate(
      uint256 amount,
      IDataHub.AssetData memory assetlogs,
      IInterestData.interestDetails memory interestRateInfo
  ) public pure returns (uint256) {}

  function calculatedepositLiabilityRatio(
      uint256 liabilities,
      uint256 deposit_amount
  ) public pure returns (uint256) {}

  function calculateinitialMarginFeeAmount(
      IDataHub.AssetData memory assetdata,
      uint256 liabilities
  ) public pure returns (uint256) {}

  function calculateMaintenanceRequirementForTrade(
      IDataHub.AssetData memory assetdata,
      uint256 amount
  ) public pure returns (uint256) {} // 13 deimcals to big

  function calculateBorrowProportion(
      IDataHub.AssetData memory assetdata
  ) public pure returns (uint256) {}

  function calculateBorrowProportionAfterTrades(
      IDataHub.AssetData memory assetdata,
      uint256 new_liabilities
  ) public pure returns (bool) {}

  function calculateFee(
      uint256 _amount,
      uint256 _fee
  ) public pure returns (uint256) {}

  function calculateCompoundedAssets(
      uint256 currentIndex,
      uint256 AverageCumulativeDepositInterest,
      uint256 usersAssets,
      uint256 usersOriginIndex
  ) public pure returns (uint256, uint256, uint256) {}

  function calculateCompoundedLiabilities(
      uint256 currentIndex, // token index
      uint256 AverageCumulativeInterest,
      IDataHub.AssetData memory assetdata,
      IInterestData.interestDetails memory interestRateInfo,
      uint256 newLiabilities,
      uint256 usersLiabilities,
      uint256 usersOriginIndex
  ) public pure returns (uint256) {}

  function normalize(
    uint256 x
  ) public pure returns (uint256 base, int256 exp) {}

  function createArray(address user) public pure returns (address[] memory) {
    address[] memory users = new address[](1);
    users[0] = user;
    return users;
  }

  function createNumberArray(
      uint256 amount
  ) public pure returns (uint256[] memory) {}

  function calculateTotal(
      uint256[] memory amounts
  ) external pure returns (uint256) {}

  function calculateAverage(
      uint256[] memory values
  ) public pure returns (uint256) {}

  function calculateAverageOfValue(
      uint256 value,
      uint divisor
  ) public pure returns (uint256) {}
}
