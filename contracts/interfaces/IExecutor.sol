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
        uint256[] memory TakerliabilityAmounts,
        uint256[] memory MakerliabilityAmounts,
        bool[][2] memory trade_side
    ) external;

    function fetchOrderBookProvider() external view returns (address);

    function fetchDaoWallet() external view returns (address);
}
