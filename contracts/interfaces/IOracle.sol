// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

interface IOracle {

    error OracleCallFailed(uint256);

    function ProcessTrade(
        bool feeSide,
        address[2] memory pair,
        address[][2] memory participants,
        uint256[][2] memory trade_amounts,
        uint256[] memory TakerliabilityAmounts,
        uint256[] memory  MakerliabilityAmounts
        
    ) external;
}
