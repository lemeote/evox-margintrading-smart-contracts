// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;
import "../interfaces/IDataHub.sol";

interface IExecutor {
    function TransferBalances(
        address[2] memory pair,
        address[] memory takers,
        address[] memory makers,
        uint256[] memory taker_amounts,
        uint256[] memory maker_amounts,
        uint256[] memory  TakerliabilityAmounts,
        uint256[] memory MakerliabilityAmounts
    ) external ;

    function returnAssetLogs(
        address token
    ) external view returns (IDataHub.AssetData memory assetLogs);

        function chargeLiabilityDelta(
        address token,
        uint256 index
    ) external view returns (uint256) ;
}
