// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;
import "../interfaces/IDataHub.sol";

interface IExecutor {
    function TransferBalances(
        address[2] memory pair,
        bool[][2] trade_sides,
        address[] memory takers,
        address[] memory makers,
        uint256[] memory taker_amounts,
        uint256[] memory maker_amounts,
        uint256[] memory TakerliabilityAmounts,
        uint256[] memory MakerliabilityAmounts
    ) external;

    function revertTrade(
        address[2] memory pair,
        address[] memory takers,
        address[] memory makers,
        uint256[] memory taker_amounts,
        uint256[] memory maker_amounts
    ) external;

    function maxBorrowCheck(
        address[2] memory pair,
        address[][2] memory participants,
        uint256[][2] memory trade_amounts
    ) external view returns (bool);

    function returnAssetLogs(
        address token
    ) external view returns (IDataHub.AssetData memory assetLogs);

    function chargeLiabilityDelta(
        address token,
        uint256 index
    ) external view returns (uint256);
}
