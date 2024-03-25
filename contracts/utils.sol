// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IDataHub.sol";
import "./interfaces/IDepositVault.sol";
import "./interfaces/IOracle.sol";
import "./libraries/EVO_LIBRARY.sol";
import "./interfaces/IExecutor.sol";
import "hardhat/console.sol";

contract Utility is Ownable {
    
    IDataHub public Datahub;

    IOracle public Oracle;

    IDepositVault public DepositVault;

    IExecutor public Executor;

    IInterestData public interestContract;

    /** Constructor  */
    constructor(
        address initialOwner,
        address _DataHub,
        address _deposit_vault,
        address oracle,
        address _executor,
        address _interest
    ) Ownable(initialOwner) {
        Datahub = IDataHub(_DataHub);
        DepositVault = IDepositVault(_deposit_vault);
        Oracle = IOracle(oracle);
        Executor = IExecutor(_executor);
        interestContract = IInterestData(_interest);
    }

    /// @notice Alters the exchange contract
    /// @param _executor the new executor address
    function AlterExchange(address _executor) public onlyOwner {
        Executor = IExecutor(_executor);
    }

    /// @notice Explain to an end user what this does
    /// @dev Explain to a developer any extra details
    /// @param user being argetted
    /// @param token being argetted
    function validateMarginStatus(
        address user,
        address token
    ) external view returns (bool) {
        (, , , bool margined, ) = Datahub.ReadUserData(user, token);
        return margined;
    }

    //// @notice calcualtes aimmr
    /// @dev Explain to a developer any extra details
    /// @param user being argetted
    /// @param token being argetted
    /// @param BalanceToLeave the balance to leave
    function calculateAIMRRequirement(
        address user,
        address token,
        uint256 BalanceToLeave
    ) external view returns (bool) {
        if (
            Datahub.calculateAIMRForUser(user, token, BalanceToLeave) <=
            Datahub.calculateTotalPortfolioValue(user)
        ) {
            return true;
        } else {
            return false;
        }
    }

    //// @notice Explain to an end user what this does
    /// @dev Explain to a developer any extra details
    /// @param user being argetted
    /// @param token being argetted
    /// @param BalanceToLeave the balance to leave
    /// @param userAssets the users assets
    function calculateMarginRequirement(
        address user,
        address token,
        uint256 BalanceToLeave,
        uint256 userAssets
    ) external view returns (bool) {
        uint256 liabilities = (BalanceToLeave - userAssets);
        if (
            Datahub.calculateAMMRForUser(user) +
               (EVO_LIBRARY.calculateMaintenanceRequirementForTrade(
                    Executor.returnAssetLogs(token),
                    liabilities
                ) * Executor.returnAssetLogs(token).assetPrice) <=
            Datahub.calculateTotalPortfolioValue(user)
        ) {
            return true;
        } else {
            return false;
        }
    }

    //// @notice calcualtes aimmr
    /// @dev Explain to a developer any extra details
    /// @param user being argetted
    function calculateAMMRRequirement(
        address user
    ) external view returns (bool) {
        if (
            Datahub.calculateAMMRForUser(user) <=
            Datahub.calculateTotalPortfolioValue(user)
        ) {
            return true;
        } else {
            return false;
        }
    }


    function calculateAmountToAddToLiabilities(
        address user,
        address token,
        uint256 amount
    ) public view returns (uint256) {
        (uint256 assets, , , , ) = Datahub.ReadUserData(user, token);
        return amount > assets ? amount - assets : 0;
    }

    function calculateTradeLiabilityAddtions(
        address[2] memory pair,
        address[][2] memory participants,
        uint256[][2] memory trade_amounts
    ) public view returns (uint256[] memory, uint256[] memory) {
        uint256[] memory TakerliabilityAmounts = new uint256[](
            participants[0].length
        );
        uint256[] memory MakerliabilityAmounts = new uint256[](
            participants[1].length
        );

        for (uint256 i = 0; i < participants[0].length; i++) {
            uint256 TakeramountToAddToLiabilities = calculateAmountToAddToLiabilities(
                    participants[0][i],
                    pair[0],
                    trade_amounts[0][i]
                );

            TakerliabilityAmounts[i] = TakeramountToAddToLiabilities;
        }

        for (uint256 i = 0; i < participants[1].length; i++) {
            uint256 MakeramountToAddToLiabilities = calculateAmountToAddToLiabilities(
                    participants[1][i],
                    pair[1],
                    trade_amounts[1][i]
                );

            MakerliabilityAmounts[i] = MakeramountToAddToLiabilities;
        }

        return (TakerliabilityAmounts, MakerliabilityAmounts);
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

    /// @notice Explain to an end user what this does
    /// @dev Explain to a developer any extra details
    /// @param user being argetted
    /// @param token being argetted
    /// @return assets
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

    /// @notice Explain to an end user what this does
    /// @dev Explain to a developer any extra details
    /// @param user being targetted
    /// @param token being targetted
    /// @return pending balance
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
        IDataHub.AssetData memory assetLogs = Executor.returnAssetLogs(token);
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
