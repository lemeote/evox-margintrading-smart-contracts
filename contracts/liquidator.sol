// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IDataHub.sol";
import "./interfaces/IDepositVault.sol";
import "./interfaces/IOracle.sol";
import "./interfaces/IUtilityContract.sol";
import "./libraries/EVO_LIBRARY.sol";
import "./interfaces/IExecutor.sol";

contract Liquidator is Ownable {
    /* LIQUIDATION + INTEREST FUNCTIONS */

    IUtilityContract public Utilities;
    IDataHub public Datahub;

    IExecutor public Executor;

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
    function alterAdminRoles(address _executor) public onlyOwner {
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

    // TO DO when we pull TPV we need to add pending balances in here as well --> loop through pending convert to price add to tpv
    /// @notice This function is for liquidating a user
    /// @dev Explain to a developer any extra details
    /// @param user the address of the user being liquidated
    /// @param tokens the liability token (the token the liquidatee has outstanding liabilities on), liquidation token ( the tokens that are liquidated from the liquidatees account)
    /// @param spendingCap the max amount the liquidator is willing to pay to settled the liquidatee's debt
    /// @param long a boolean to mark if they are liquidating a long or a short.
    function Liquidate(
        address user,
        address[2] memory tokens, // liability tokens first, tokens to liquidate after
        uint256 spendingCap,
        bool long
    ) public {
        require(CheckForLiquidation(user), "not liquidatable"); // AMMR liquidatee --> checks AMMR
        require(tokens.length == 2, "have to select a pair");

        require(
            spendingCap <= fetchliabilities(user, tokens[0]),
            "cannot liquidate that amount of the users assets"
        );
        require(
            spendingCap <= fetchAssets(msg.sender, tokens[0]),
            "you do not have the assets required for this size of liquidation, please lower your spending cap"
        );

        uint256[] memory taker_amounts = new uint256[](1);
        uint256[] memory maker_amounts = new uint256[](1);
        
        uint256 amountToLiquidate = (spendingCap * 10 ** 18) /
            ((fetchLogs(tokens[1]).assetPrice * fetchAssets(user, tokens[1]))) /
            10 ** 18;

        FeesCollected[tokens[1]] +=
            (((amountToLiquidate * returnMultiplier(false, tokens[1])) /
                10 ** 18) / 100) *
            20;

        if (long) {
            uint256 discountedAmount = (((fetchLogs(tokens[1]).assetPrice *
                fetchAssets(user, tokens[1])) / 10 ** 18) *
                (returnMultiplier(false, tokens[1]))) / 10 ** 18;

            taker_amounts[0] = (discountedAmount > spendingCap)
                ? spendingCap
                : discountedAmount;

            maker_amounts[0] =
                (((amountToLiquidate * returnMultiplier(false, tokens[1])) /
                    10 ** 18) / 100) *
                80;

            taker_amounts[0] = (discountedAmount > spendingCap)
                ? spendingCap
                : discountedAmount;
            maker_amounts[0] =
                (((amountToLiquidate * returnMultiplier(false, tokens[1])) /
                    10 ** 18) / 100) *
                80;
        } else {
            uint256 premiumAmount = ((fetchLogs(tokens[0]).assetPrice *
                spendingCap) * returnMultiplier(true, tokens[1])) / 10 ** 18;
            ////////////////////////////////////////////////////
            FeesCollected[tokens[0]] +=
                (((((spendingCap / fetchliabilities(user, tokens[0])) *
                    returnMultiplier(true, tokens[1])) / 10 ** 18) -
                    (spendingCap / fetchliabilities(user, tokens[0]))) / 100) *
                20;
            ////////////////////////////////////////////////////
            taker_amounts[0] = (premiumAmount >
                (spendingCap * fetchLogs(tokens[0]).assetPrice))
                ? spendingCap
                : fetchliabilities(user, tokens[0]);
            ////////////////////////////////////////////////////
            maker_amounts[0] = (premiumAmount >
                (spendingCap * fetchLogs(tokens[0]).assetPrice))
                ? spendingCap * fetchLogs(tokens[0]).assetPrice
                : premiumAmount;
        }

        conductLiquidation(
            user,
            msg.sender,
            tokens,
            maker_amounts,
            taker_amounts
        );
    }

    function returnMultiplier(
        bool short,
        address token
    ) private view returns (uint256) {
        if (!short) {
            return 10 ** 18 - fetchLogs(token).liquidationFee; //100000000000000000
        } else {
            return 10 ** 18 + fetchLogs(token).liquidationFee;
        }
    }

    function conductLiquidation(
        address user,
        address liquidator,
        address[2] memory tokens, // liability tokens first, tokens to liquidate after
        uint256[] memory maker_amounts,
        uint256[] memory taker_amounts
    ) private {
        address[] memory takers = EVO_LIBRARY.createArray(liquidator);
        address[] memory makers = EVO_LIBRARY.createArray(user); //liquidatee

        // max borrow proportion check
        require(
            Utilities.maxBorrowCheck(
                tokens,
                [takers, makers],
                [
                    EVO_LIBRARY.createNumberArray(0),
                    EVO_LIBRARY.createNumberArray(0) // this makes a 0 array lol
                ]
            ),
            "this liquidation would exceed max borrow proportion please lower the spending cap"
        );

        require(
            Datahub.calculateCollateralValue(user) +
                Datahub.calculatePendingCollateralValue(user) <
                Datahub.calculateAMMRForUser(user)
        );

        bool[] memory fee_side = new bool[](1);
        bool[] memory fee_side_2 = new bool[](1);

        fee_side[0] = true;
        fee_side_2[0] = true;

        freezeTempBalance(
            tokens,
            [takers, makers],
            [taker_amounts, maker_amounts],
            [fee_side, fee_side_2]
        );

        Executor.TransferBalances(
            tokens,
            takers,
            makers,
            taker_amounts,
            maker_amounts,
            EVO_LIBRARY.createNumberArray(0),
            EVO_LIBRARY.createNumberArray(0),
            [fee_side, fee_side_2]
        );
    }

    /// @notice This simulates an airnode call to see if it is a success or fail
    /// @param pair the pair of tokens being traded
    /// @param participants of the trade 2 nested arrays
    /// @param trade_amounts the trades amounts for each participant
    function freezeTempBalance(
        address[2] memory pair,
        address[][2] memory participants,
        uint256[][2] memory trade_amounts,
        bool[][2] memory trade_side
    ) private {
        alterPending(participants[0], trade_amounts[0], trade_side[0], pair[0]);
        alterPending(participants[1], trade_amounts[1], trade_side[1], pair[1]);
    }

    /// @notice Processes a trade details
    /// @param  participants the participants on the trade
    /// @param  tradeAmounts the trade amounts in the trade
    /// @param  pair the token involved in the trade
    function alterPending(
        address[] memory participants,
        uint256[] memory tradeAmounts,
        bool[] memory tradeside,
        address pair
    ) internal returns (bool) {
        for (uint256 i = 0; i < participants.length; i++) {
            (uint256 assets, , , , ) = Datahub.ReadUserData(
                participants[i],
                pair
            );
            if (tradeside[i] == true) {} else {
                tradeAmounts[i] =
                    (tradeAmounts[i] * Datahub.tradeFee(pair, 1)) /
                    10 ** 18;
            }
            uint256 balanceToAdd = tradeAmounts[i] > assets
                ? assets
                : tradeAmounts[i];
            AlterPendingBalances(participants[i], pair, balanceToAdd);
        }
        return true;
    }

    /// @notice Alters a users pending balance
    /// @param participant the participant being adjusted
    /// @param asset the asset being traded
    /// @param trade_amount the amount being adjusted
    function AlterPendingBalances(
        address participant,
        address asset,
        uint256 trade_amount
    ) private {
        // pay fee take less from the maker if they are a maker
        Datahub.removeAssets(participant, asset, trade_amount);
        Datahub.addPendingBalances(participant, asset, trade_amount);
    }

    function fetchLogs(
        address token
    ) private view returns (IDataHub.AssetData memory) {
        IDataHub.AssetData memory assetLogs = Datahub.returnAssetLogs(token);

        return assetLogs;
    }

    function fetchAssets(
        address user,
        address token
    ) private view returns (uint256) {
        (uint256 assets, , , , ) = Datahub.ReadUserData(user, token);
        return assets;
    }

    function fetchliabilities(
        address user,
        address token
    ) private view returns (uint256) {
        (, uint256 liabilities, , , ) = Datahub.ReadUserData(user, token);
        return liabilities;
    }
}
