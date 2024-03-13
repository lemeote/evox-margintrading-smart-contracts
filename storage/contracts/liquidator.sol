// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol" as ERC20;
import "@openzeppelin/contracts/interfaces/IERC20.sol" as IERC20;
import "./interfaces/IDataHub.sol";
import "./libraries/REX_LIBRARY.sol";
import "./interfaces/IExecutor.sol";
import "hardhat/console.sol";

contract Liquidator is Ownable {

    IDataHub public Datahub;

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


    function feeCollection(address token) public onlyOwner {
       IERC20.IERC20 _token =  IERC20.IERC20(token);
       require(_token.transfer(owner(),FeesCollected[token]));
       FeesCollected[token] = 0;
    }

    /// @notice This checks if the user is liquidatable
    /// @dev add in the users address to check their Aggregate Maintenance Margin Requirement and see if its higher that their Total Portfolio value
    function CheckForLiquidation(address user) public view returns (bool) {
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

    function Liquidate(
        address user,
        address[2] memory tokens, // liability tokens first, tokens to liquidate after
        uint256 spendingCap,
        bool long
    ) public {
        require(CheckForLiquidation(user), "not liquidatable");
        require(tokens.length == 2);

        IDataHub.AssetData memory assetLogsToken0 = Executor
            .returnAssetLogsExternal(tokens[0]);
        IDataHub.AssetData memory assetLogsToken1 = Executor
            .returnAssetLogsExternal(tokens[1]);

        (uint256 assetstoken0, uint256 liabilitiestoken0,  , , ) = Datahub
            .ReadUserData(user, tokens[0]);

        (uint256 assetstoken1, ,  , , ) = Datahub
            .ReadUserData(user, tokens[1]);

        require(assetstoken0 > spendingCap, "assets of token 0 are not above spending cap");

        uint256[] memory taker_amounts = new uint256[](1);
        uint256[] memory maker_amounts = new uint256[](1);

        uint256 amountToLiquidate = (spendingCap * 10 ** 18) /
            ((assetLogsToken1.assetPrice * assetstoken1) / 10 ** 18);

        uint256 discountMultiplier = (1 +
            assetLogsToken1.liquidationFee *
            1000);

        uint256 toLiquidator = amountToLiquidate +
            ((((amountToLiquidate * discountMultiplier) / 1000) -
                amountToLiquidate) / 100) *
            80;

        FeesCollected[tokens[1]] +=
            ((((amountToLiquidate * discountMultiplier) / 1000) -
                amountToLiquidate) / 100) *
            20;


        if (long) {
            uint256 discountedAmount = (((assetLogsToken1.assetPrice *
                assetstoken1) / 10 ** 18) *
                (1 - assetLogsToken1.liquidationFee * 1000)) / 1000;
            taker_amounts[0] = (discountedAmount > spendingCap)
                ? spendingCap
                : discountedAmount;
            maker_amounts[0] = toLiquidator;
        } else {
            uint256 discountedAmount = ((assetLogsToken0.assetPrice *
                liabilitiestoken0) * discountMultiplier) / 1000;
            FeesCollected[tokens[0]] +=
                (((((spendingCap / liabilitiestoken0) * discountMultiplier) /
                    1000) - (spendingCap / liabilitiestoken0)) / 100) *
                20;

            taker_amounts[0] = (discountedAmount >
                (spendingCap * assetLogsToken0.assetPrice))
                ? spendingCap
                : (spendingCap * assetLogsToken0.assetPrice) /
                    (assetLogsToken0.assetPrice * liabilitiestoken0);
            maker_amounts[0] = (discountedAmount >
                (spendingCap * assetLogsToken0.assetPrice))
                ? toLiquidator
                : (((spendingCap / liabilitiestoken0) * discountMultiplier) /
                    1000) +
                    (((((spendingCap / liabilitiestoken0) *
                        discountMultiplier) / 1000) -
                        (spendingCap / liabilitiestoken0)) / 100) *
                    80;

            /// MAKE SURE TO CHECK ALL MATH ON THIS -> CHATGPT MIGHT HAVE FUCKD US
        }

        Executor.TransferBalances(
            tokens,
            REX_LIBRARY.createArray(msg.sender),
            REX_LIBRARY.createArray(user),
            taker_amounts,
            maker_amounts,
            REX_LIBRARY.createNumberArray(0),
            REX_LIBRARY.createNumberArray(0)
        );
    }
}
