// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

interface IOracle {


    function ProcessTrade(
        address[2] memory pair,
        address[][2] memory participants,
        uint256[][2] memory trade_amounts,
        bool[][2] memory trade_side,
        uint256[] memory TakerliabilityAmounts,
        uint256[] memory  MakerliabilityAmounts,
        address[3] memory airnode_details,
        bytes32 endpointId,
        bytes calldata parameters
        
    ) external;
}
