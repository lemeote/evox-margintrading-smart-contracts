// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IDataHub.sol";
import "../interfaces/IDepositVault.sol";
import "../interfaces/IExecutor.sol";
import "../Oracle.sol";
import "hardhat/console.sol";


contract MockOracle is Oracle {
  constructor(address initialOwner, address _DataHub, address _deposit_vault, address _executor) Oracle(initialOwner, _DataHub, _deposit_vault, _executor) {}

  function setUSDT(address _usdt) public {
    USDT = _usdt;
  }
}