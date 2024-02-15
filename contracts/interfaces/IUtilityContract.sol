// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;
import "../interfaces/IDataHub.sol";

interface IUtilityContract {
    function validateMarginStatus(
        address user,
        address token
    ) external view returns (bool);

    function calculateMarginRequirement(
        address user,
        address token,
        uint256 BalanceToLeave,
        uint256 userAssets
    ) external view returns (bool);

    function AlterExchange(address _executor) external;

    function returnPending(
        address user,
        address token
    ) external view returns (uint256);

    function chargeInterest(
        address token,
        uint256 liabilities,
        uint256 amount_to_be_added, 
        uint256 rateIndex
    ) external view returns (uint256);

    function calculateAmountToAddToLiabilities(
        address user,
        address token,
        uint256 amount
    ) external view returns (uint256);

    function returnAssets(
        address user,
        address token
    ) external view returns (uint256);

    function returnBulkAssets(
        address[] memory users,
        address token
    ) external view returns (uint256);
    function returnliabilities(
        address user,
        address token
    ) external view returns (uint256);

    function returnMaintenanceRequirementForTrade(
        address token,
        uint256 amount
    ) external view returns (uint256);

}
