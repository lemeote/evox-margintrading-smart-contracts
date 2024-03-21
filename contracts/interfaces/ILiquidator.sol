// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

interface ILiquidator {
    function Liquidate(
        address user,
        address[2] memory tokens, // liability tokens first, tokens to liquidate after
        uint256 spendingCap,
        bool long
    ) external;

    function CheckForLiquidation(address user) external view returns (bool);
}
