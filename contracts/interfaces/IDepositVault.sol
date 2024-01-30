// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

interface IDepositVault {
    function deposit_token(
        address token,
        uint256 amount
    ) external returns (bool);

    function withdraw_token(
        address token,
        uint256 amount
    ) external returns (bool);

    function fetchDecimals(address token) external view returns (uint256);

    function fetchstatus(address user) external view returns (bool);
}
