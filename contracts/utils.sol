// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IDataHub.sol";
import "./interfaces/IDepositVault.sol";
import "./interfaces/IOracle.sol";
import "./libraries/REX_LIBRARY.sol";
import "./interfaces/IExecutor.sol";

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
        (, , , bool margined, ) = Datahub.ReadUserData(user, token);
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

    function chargeInterest(
        address token,
        uint256 liabilities,
        uint256 rateIndex
    ) public view returns (uint256) {
        uint256 interestBulk;

        uint256 lastRateChange = Datahub
            .fetchRates(token, Datahub.fetchCurrentRateIndex(token))
            .lastUpdatedTime;

        uint256 currentTime = block.timestamp;

        for (
            uint256 i = rateIndex;
            i < Datahub.fetchCurrentRateIndex(token);
            i++
        ) {
            interestBulk += Datahub.fetchRates(token, i).interestRate;

            if (currentTime - lastRateChange > 1 hours) {
                interestBulk +=
                    Datahub.fetchRates(token, i).interestRate *
                    (currentTime - lastRateChange / 1 hours);
            }
        }

        uint256 interestAverage = interestBulk /
            (Datahub.fetchCurrentRateIndex(token) -
                rateIndex +
                (currentTime - lastRateChange / 1 hours));

        uint256 interestCharged = liabilities *
            ((1 + interestAverage) **
                (Datahub.fetchCurrentRateIndex(token) - rateIndex)) -
            liabilities;

        return interestCharged;
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

        uint256 interestRateForHour = REX_LIBRARY.calculateInterestRate(
            amount,
            assetLogs,
            Datahub.fetchRates(token, Datahub.fetchCurrentRateIndex(token))
        ) / 8760;

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
        (uint256 assets, , , , ) = Datahub.ReadUserData(user, token);
        return amount > assets ? amount - assets : 0;
    }

    function returnBulkAssets(
        address[] memory users,
        address token
    ) external view returns (uint256) {
        uint256 bulkAssets;
        for (uint256 i = 0; i < users.length; i++) {
            (uint256 assets, , , , ) = Datahub.ReadUserData(users[i], token);

            bulkAssets += assets;
        }
        return bulkAssets;
    }

    function returnAssets(
        address user,
        address token
    ) external view returns (uint256) {
        (uint256 assets, , , , ) = Datahub.ReadUserData(user, token);
        return assets;
    }

    function returnliabilities(
        address user,
        address token
    ) external view returns (uint256) {
        (, uint256 liabilities, , , ) = Datahub.ReadUserData(user, token);
        return liabilities;
    }

    function returnPending(
        address user,
        address token
    ) external view returns (uint256) {
        (, , uint256 pending, , ) = Datahub.ReadUserData(user, token);
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
