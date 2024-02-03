// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IDataHub.sol";
import "./interfaces/IDepositVault.sol";
import "./interfaces/IOracle.sol";
import "./libraries/REX_LIBRARY.sol";
import "./interfaces/IExecutor.sol";
import "hardhat/console.sol";

contract Utility is Ownable {
    IDataHub public Datahub;

    IOracle public Oracle;

    IDepositVault public DepositVault;

    IExecutor public Executor;

    /** Constructor  */
    constructor(
        address initialOwner,
        address _DataHub,
        address _deposit_vault,
        address oracle,
        address _executor
    ) Ownable(initialOwner) {
        Datahub = IDataHub(_DataHub);
        DepositVault = IDepositVault(_deposit_vault);
        Oracle = IOracle(oracle);
        Executor = IExecutor(_executor);
    }

    function AlterExchange(address _executor) public onlyOwner {
        Executor = IExecutor(_executor);
    }

    function validateMarginStatus(
        address user,
        address token
    ) external view returns (bool) {
        (, , , , bool margined, ) = Datahub.ReadUserData(user, token);
        return margined;
    }

    function calculateMarginRequirement(
        address user,
        address token,
        uint256 BalanceToLeave,
        uint256 userAssets
    ) external view returns (bool) {
        uint256 liabilities = (BalanceToLeave - userAssets);
        if (
            Datahub.calculateAMMRForUser(user) +
                REX_LIBRARY.calculateMaintenanceRequirementForTrade(
                    Executor.returnAssetLogsExternal(token),
                    liabilities
                ) <=
            Datahub.calculateTotalPortfolioValue(user)
        ) {
            return true;
        } else {
            return false;
        }
    }

    /// @notice This checks if the user is liquidatable
    /// @dev add in the users address to check their Aggregate Maintenance Margin Requirement and see if its higher that their Total Portfolio value
    function CheckForLiquidation(address user) external view returns (bool) {
        if (
            Datahub.calculateAMMRForUser(user) >
            Datahub.calculateTotalPortfolioValue(user)
        ) {
            return true;
            // liquidate this fucker
        } else {
            return false;
            // safe for now
        }
    }

    function handleHourlyFee(
        address token,
        uint256 amount
    ) external view returns (uint256) {

        IDataHub.AssetData memory assetLogs = Datahub.returnAssetLogs(token);

        uint256 secondsElapsedInCurrentHour = block.timestamp % 3600;

        uint256 percentageOfHourElapsed = (secondsElapsedInCurrentHour * 100) /
            3600;

        uint256 percentageOfHourRemaining = 100 - percentageOfHourElapsed;

        uint256 initialMarginFee = REX_LIBRARY.calculateinitialMarginFeeAmount(
            assetLogs,
            amount
        );


        console.log(
            "output form interest rate in the handle hourly fee function",
            REX_LIBRARY.calculateInterestRate(amount, assetLogs)
        );
        uint256 interestRateForHour = REX_LIBRARY.calculateInterestRate(
            amount,
            assetLogs
        ) / 8760;

        console.log("interest Rate for the hour", interestRateForHour);

        console.log("percentage of hour remaining", percentageOfHourRemaining);

        console.log(
            "handleHourlyFee output ",
            initialMarginFee +
                ((interestRateForHour * percentageOfHourRemaining) / 100) *
                (amount / 10 ** 18)
        );
        return
            initialMarginFee +
            ((interestRateForHour * percentageOfHourRemaining) / 100) *
            (amount / 10 ** 18);
    }

    function calculateAmountToAddToLiabilities(
        address user,
        address token,
        uint256 amount
    ) external view returns (uint256) {
        (uint256 assets, , , , , ) = Datahub.ReadUserData(user, token);
        return amount > assets ? amount - assets : 0;
    }

    function returnBulkAssets(
        address[] memory users,
        address token
    ) external view returns (uint256) {
        uint256 bulkAssets;
        for (uint256 i = 0; i < users.length; i++) {
            (uint256 assets, , , , , ) = Datahub.ReadUserData(users[i], token);

            bulkAssets += assets;
        }
        return bulkAssets;
    }

    function returnAssets(
        address user,
        address token
    ) external view returns (uint256) {
        (uint256 assets, , , , , ) = Datahub.ReadUserData(user, token);
        return assets;
    }

    function returnliabilities(
        address user,
        address token
    ) external view returns (uint256) {
        (, uint256 liabilities, , , , ) = Datahub.ReadUserData(user, token);
        return liabilities;
    }

    function returnPending(
        address user,
        address token
    ) external view returns (uint256) {
        (, , , uint256 pending, , ) = Datahub.ReadUserData(user, token);
        return pending;
    }

    function returnMaintenanceRequirementForTrade(
        address token,
        uint256 amount
    ) external view returns (uint256) {
        //uint256 price = assetdata[token].assetPrice; // price comes at aggregate calc now
        IDataHub.AssetData memory assetLogs = Executor.returnAssetLogsExternal(
            token
        );
        uint256 maintenace = assetLogs.MaintenanceMarginRequirement;
        return ((maintenace * (amount)) / 10 ** 18); //
    }

    function alterAdminRoles(
        address _datahub,
        address _depositVault,
        address _oracle
    ) public onlyOwner {
        Datahub = IDataHub(_datahub);
        DepositVault = IDepositVault(_depositVault);
        Oracle = IOracle(_oracle);
    }

    receive() external payable {}
}
