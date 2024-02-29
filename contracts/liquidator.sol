// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IDataHub.sol";
import "./interfaces/IDepositVault.sol";
import "./interfaces/IOracle.sol";
import "./interfaces/IUtilityContract.sol";
import "./libraries/REX_LIBRARY.sol";
import "hardhat/console.sol";
import "./interfaces/IExecutor.sol";

contract Liquidator is Ownable {
    /* LIQUIDATION + INTEREST FUNCTIONS */

    IDataHub public Datahub;

    IOracle public Oracle;

    IDepositVault public DepositVault;

    IUtilityContract public Utilities;

    IExecutor public Executor;

    uint256 private DISCOUNT = 5; // 5% -> need decimal module for this Discount = (1 - LiquidationFee[ofAsset])

    /** Constructor  */
    constructor(
        address initialOwner,
        address _DataHub,
        address _executor
    ) Ownable(initialOwner) {
        Datahub = IDataHub(_DataHub);
        Executor = IExecutor(_executor);
    }

    mapping(address => uint256) FeesCollected; // token --> amount


    /// @notice This alters the admin roles for the contract
    /// @param _executor the address of the new executor contract
    function AlterAdmins(address _executor) public onlyOwner {
        Executor = IExecutor(_executor);
    }

    /// @notice This checks if the user is liquidatable
    /// @dev add in the users address to check their Aggregate Maintenance Margin Requirement and see if its higher that their Total Portfolio value
    function CheckForLiquidation(address user) public view returns (bool) {
        if (
            Datahub.calculateAMMRForUser(user) >
            Datahub.calculateTotalPortfolioValue(user)
        ) {
            return true;
        } else {
            return false;
        }
    }

    function Liquidate(
        address user,
        address[2] memory tokens, // liability tokens first, tokens to liquidate after
        uint256 spendingCap,
        bool long
    ) public {
        require(CheckForLiquidation(user), "not liquidatable");
        require(tokens.length == 2);

       // IDataHub.AssetData memory assetLogsToken0 = Executor
       //     .returnAssetLogs(tokens[0]);
        IDataHub.AssetData memory assetLogsToken1 = Executor
            .returnAssetLogs(tokens[1]);

        (uint256 assetstoken0, uint256 liabilitiestoken0,  , , ) = Datahub
            .ReadUserData(msg.sender, tokens[0]);

        (uint256 assetstoken1, ,  , , ) = Datahub
            .ReadUserData(user, tokens[1]);

        require(assetstoken0 >= spendingCap, "assets of token 0 are not above spending cap");

        uint256[] memory taker_amounts = new uint256[](1);
        uint256[] memory maker_amounts = new uint256[](1);

        uint256 discountMultiplier = 10 ** 18 - assetLogsToken1.liquidationFee;

        uint256 toLiquidator = ((spendingCap * discountMultiplier) / 
            (10 ** 18) / 100) * 80;

        if (long) {
            uint256 discountedAmount = (assetstoken1 * discountMultiplier) / (10 ** 18);
            taker_amounts[0] = (discountedAmount > spendingCap)
                ? spendingCap
                : discountedAmount;
            maker_amounts[0] = toLiquidator;
        } else {
            uint256 discountedAmount = (liabilitiestoken0 * discountMultiplier) / (10 ** 18);
            FeesCollected[tokens[0]] +=
                ((spendingCap * discountMultiplier) / (10 ** 18) / 100) * 20;

            taker_amounts[0] = (discountedAmount > spendingCap)
                ? spendingCap
                : discountedAmount;
            maker_amounts[0] = (discountedAmount > spendingCap)
                ? toLiquidator
                : discountedAmount;
        }

        address[] memory takers = REX_LIBRARY.createArray(msg.sender);
        address[] memory makers = REX_LIBRARY.createArray(user);

        Executor.TransferBalances(
            tokens,
            takers,
            makers,
            taker_amounts,
            maker_amounts,
            REX_LIBRARY.createNumberArray(0),
            REX_LIBRARY.createNumberArray(0)
        );
    }
}