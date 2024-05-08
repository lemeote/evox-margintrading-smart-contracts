// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import "../datahub.sol";
import "hardhat/console.sol";


contract MockDatahub is DataHub {
  constructor(
    address initialOwner,
    address _executor,
    address _deposit_vault,
    address _oracle,
    address _interest,
    address utils
) DataHub(initialOwner, _executor, _deposit_vault, _oracle, _interest, utils) {}

  function addAssetsTest(
    address user,
    address token,
    uint256 amount
  ) external {
    userdata[user].asset_info[token] += amount;
  }
  function removeAssetsTest(
    address user,
    address token,
    uint256 amount
  ) external {
    userdata[user].asset_info[token] -= amount;
  }

  function addLiabilitiesTest(
    address user,
    address token,
    uint256 amount
  ) external {
      userdata[user].liability_info[token] += amount;
  }

  /// @notice removes a users liabilities
  /// @param user being targetted
  /// @param token being targetted
  /// @param amount to alter liabilities by
  function removeLiabilitiesTest(
      address user,
      address token,
      uint256 amount
  ) external {
      userdata[user].liability_info[token] -= amount;
  }
  
  function settotalAssetSupplyTest(address token, uint256 amount, bool pos_neg) public {
    if (pos_neg == true) {
      assetdata[token].totalAssetSupply += amount;
    } else {
      assetdata[token].totalAssetSupply -= amount;
    }
  }
}