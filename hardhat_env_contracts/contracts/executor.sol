// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IDataHub.sol";
import "./interfaces/IDepositVault.sol";
import "./interfaces/IOracle.sol";
import "./interfaces/IUtilityContract.sol";
import "./libraries/REX_LIBRARY.sol";
import "./interfaces/IinterestData.sol";
import "hardhat/console.sol";

contract REX_EXCHANGE is Ownable {
    error OracleCallFailed(uint256);

    /** Address's  */

    IDataHub public Datahub;

    IOracle public Oracle;

    IDepositVault public DepositVault;

    IInterestData public interestContract;

    IUtilityContract public Utilities;

    address public FeeWallet =
        address(0x1167E56ABcf9d2dF6354e03610E301B8a2934955);

    address public liquidator;

    /** Constructor  */
    constructor(
        address initialOwner,
        address _DataHub,
        address _deposit_vault,
        address oracle,
        address _utility,
        address _interest,
        address _liquidator
    ) Ownable(initialOwner) {
        Datahub = IDataHub(_DataHub);
        DepositVault = IDepositVault(_deposit_vault);
        Oracle = IOracle(oracle);
        Utilities = IUtilityContract(_utility);
        interestContract = IInterestData(_interest);
        liquidator = _liquidator;
    }

    modifier checkRoleAuthority() {
        require(
            msg.sender == address(Oracle) || msg.sender == liquidator,
            "Unauthorized"
        );
        _;
    }

    /// @notice This is the function users need to submit an order to the exchange
    /// @dev Explain to a developer any extra details
    /// @param pair the pair of tokens being traded
    /// @param participants of the trade 2 nested arrays
    /// @param trade_amounts the trades amounts for each participant
    function SubmitOrder(
        address[2] memory pair,
        address[][2] memory participants,
        uint256[][2] memory trade_amounts
    ) public {
        // require(airnode address == airnode address set on deployment )
        (
            uint256[] memory takerLiabilities,
            uint256[] memory makerLiabilities
        ) = Utilities.calculateTradeLiabilityAddtions(
                pair,
                participants,
                trade_amounts
            );

        // this checks if the asset they are trying to trade isn't pass max borrow
        maxBorrowCheck(pair, participants, trade_amounts);

        processMargin(pair, participants, trade_amounts);

        Oracle.ProcessTrade(
            pair,
            participants,
            trade_amounts,
            takerLiabilities,
            makerLiabilities
        );
    }

    /// @notice Checks that the trade will not push the asset over maxBorrowProportion
    function maxBorrowCheck(
        address[2] memory pair,
        address[][2] memory participants,
        uint256[][2] memory trade_amounts
    ) public view returns (bool) {
        uint256 newLiabilitiesIssued;
        for (uint256 i = 0; i < pair.length; i++) {
            newLiabilitiesIssued = REX_LIBRARY.calculateTotal(
                trade_amounts[i]
            ) > Utilities.returnBulkAssets(participants[i], pair[i])
                ? REX_LIBRARY.calculateTotal(trade_amounts[i]) -
                    Utilities.returnBulkAssets(participants[i], pair[i])
                : 0;

            if (newLiabilitiesIssued > 0) {
                return
                    REX_LIBRARY.calculateBorrowProportionAfterTrades(
                        returnAssetLogs(pair[i]),
                        newLiabilitiesIssued
                    );
            }
        }
        return true;
    }

    /// @notice this function runs the margin checks, changes margin status if applicable and adds pending balances
    /// @param pair the pair of tokens being traded
    /// @param participants of the trade 2 nested arrays
    /// @param trade_amounts the trades amounts for each participant
    function processMargin(
        address[2] memory pair,
        address[][2] memory participants,
        uint256[][2] memory trade_amounts
    ) internal returns (bool) {
        bool takerTradeConfirmation = processChecks(
            participants[0],
            trade_amounts[0],
            pair[0]
        );
        bool makerTradeConfirmation = processChecks(
            participants[1],
            trade_amounts[1],
            pair[1]
        );

        if (!makerTradeConfirmation || !takerTradeConfirmation) {
            return false;
        } else {
            return true;
        }
    }

    /// @notice Processes a trade details
    /// @param  participants the participants on the trade
    /// @param  tradeAmounts the trade amounts in the trade
    /// @param  pair the token involved in the trade
    function processChecks(
        address[] memory participants,
        uint256[] memory tradeAmounts,
        address pair
    ) internal returns (bool) {
        for (uint256 i = 0; i < participants.length; i++) {
            (uint256 assets, , , , ) = Datahub.ReadUserData(
                participants[i],
                pair
            );

            if (tradeAmounts[i] > assets) {
                uint256 initalMarginFeeAmount = REX_LIBRARY
                    .calculateinitialMarginFeeAmount(
                        returnAssetLogs(pair),
                        tradeAmounts[i]
                    );
                initalMarginFeeAmount *= returnAssetLogs(pair).assetPrice;

                if (
                    Datahub.calculateTotalPortfolioValue(participants[i]) >
                    Datahub.calculateAIMRForUser(participants[i]) +
                        initalMarginFeeAmount
                ) {
                    return false;
                }

                if (!Utilities.validateMarginStatus(participants[i], pair)) {
                    Datahub.SetMarginStatus(participants[i], true);
                }
            }
        }
        return true;
    }

    /// @notice This called the execute trade functions on the particpants and checks if the assets are already in their portfolio
    /// @param pair the pair of assets involved in the trade
    /// @param takers the taker wallet addresses
    /// @param makers the maker wallet addresses
    /// @param taker_amounts the taker amounts in the trade
    /// @param maker_amounts the maker amounts in the trade
    /// @param TakerliabilityAmounts the new liabilities being issued to the takers
    /// @param MakerliabilityAmounts the new liabilities being issued to the makers
    function TransferBalances(
        address[2] memory pair,
        address[] memory takers,
        address[] memory makers,
        uint256[] memory taker_amounts,
        uint256[] memory maker_amounts,
        uint256[] memory TakerliabilityAmounts,
        uint256[] memory MakerliabilityAmounts
    ) external checkRoleAuthority {
        Datahub.checkIfAssetIsPresent(takers, pair[1]);
        Datahub.checkIfAssetIsPresent(makers, pair[0]);
        // checks if the asset is in the users portfolio already or not and adds it if it isnt
        executeTrade(
            makers,
            taker_amounts,
            maker_amounts,
            MakerliabilityAmounts,
            pair[1],
            pair[0]
        );
        executeTrade(
            takers,
            maker_amounts,
            taker_amounts,
            TakerliabilityAmounts,
            pair[0],
            pair[1]
        );
    }

    /// @notice Explain to an end user what this does
    /// @dev Explain to a developer any extra details
    /// @param users the users involved in the trade
    /// @param amounts_in_token the amounts coming into the users wallets
    /// @param amounts_out_token the amounts coming out of the users wallets
    /// @param  liabilityAmounts new liabilities being issued
    /// @param  out_token the token leaving the users wallet
    /// @param  in_token the token coming into the users wallet
    function executeTrade(
        address[] memory users,
        uint256[] memory amounts_in_token,
        uint256[] memory amounts_out_token,
        uint256[] memory liabilityAmounts,
        address out_token,
        address in_token
    ) private {
        for (uint256 i = 0; i < users.length; i++) {
            uint256 amountToAddToLiabilities = liabilityAmounts[i];
            if (amountToAddToLiabilities != 0) {
                chargeinterest(
                    users[i],
                    out_token,
                    amountToAddToLiabilities,
                    false
                ); // this sets total borrowed amount, adds to liabilities

                Datahub.addMaintenanceMarginRequirement(
                    users[i],
                    out_token,
                    in_token,
                    REX_LIBRARY.calculateMaintenanceRequirementForTrade(
                        returnAssetLogs(in_token),
                        amountToAddToLiabilities
                    )
                );
            }
            if (
                amounts_in_token[i] <=
                Utilities.returnliabilities(users[i], in_token)
            ) {
                chargeinterest(users[i], in_token, amounts_in_token[i], true);

                Modifymmr(users[i], in_token, out_token, amounts_in_token[i]);
            } else {
                uint256 subtractedFromLiabilites = Utilities.returnliabilities(
                    users[i],
                    in_token
                ); // we know its greater than or equal to its safe to 0

                uint256 input_amount = amounts_in_token[i];

                if (subtractedFromLiabilites > 0) {
                    input_amount =
                        amounts_in_token[i] -
                        Utilities.returnliabilities(users[i], in_token);

                    chargeinterest(
                        users[i],
                        in_token,
                        subtractedFromLiabilites,
                        true
                    );

                    Modifymmr(
                        users[i],
                        in_token,
                        out_token,
                        amounts_in_token[i]
                    );
                }

                amounts_out_token[i] >
                    Utilities.returnPending(users[i], out_token)
                    ? Datahub.removePendingBalances(
                        users[i],
                        out_token,
                        Utilities.returnPending(users[i], out_token)
                    )
                    : Datahub.removePendingBalances(
                        users[i],
                        out_token,
                        amounts_out_token[i]
                    );

                Datahub.addAssets(users[i], in_token, input_amount);

                // Conditions met assets changed, set flag to true
            }
        }
    }

    /// @notice Explain to an end user what this does
    /// @dev Explain to a developer any extra details
    /// @param user the address of the user beign confirmed
    /// @param token the token being targetted
    /// @param liabilitiesAccrued the new liabilities being issued
    /// @param minus determines if we are adding to the liability pool or subtracting
    function chargeinterest(
        address user,
        address token,
        uint256 liabilitiesAccrued,
        bool minus
    ) private {
        if (minus == false) {
            uint256 interestCharge = interestContract
                .calculateCompoundedLiabilities(
                    token,
                    liabilitiesAccrued,
                    Utilities.returnliabilities(user, token),
                    Datahub.viewUsersInterestRateIndex(user, token)
                );

            Datahub.addLiabilities(
                user,
                token,
                liabilitiesAccrued + interestCharge
            );

            Datahub.alterUsersInterestRateIndex(user, token);

            Datahub.setTotalBorrowedAmount(
                token,
                (liabilitiesAccrued + interestCharge),
                true
            );
        } else {
            Datahub.removeLiabilities(user, token, liabilitiesAccrued);
            Datahub.setTotalBorrowedAmount(token, liabilitiesAccrued, true);
        }

        ///Datahub.alterUsersInterestRateIndex(user, token);

        if (
            interestContract
                .fetchRateInfo(
                    token,
                    interestContract.fetchCurrentRateIndex(token)
                )
                .lastUpdatedTime +
                1 hours <
            block.timestamp
        ) {
            Datahub.setTotalBorrowedAmount(
                token,
                interestContract.chargeStaticLiabilityInterest(
                    token,
                    interestContract.fetchCurrentRateIndex(token)
                ),
                true
            );

            interestContract.updateInterestIndex(
                token,
                interestContract.fetchCurrentRateIndex(token),
                REX_LIBRARY.calculateInterestRate(
                    liabilitiesAccrued,
                    returnAssetLogs(token),
                    interestContract.fetchRateInfo(
                        token,
                        interestContract.fetchCurrentRateIndex(token)
                    )
                )
            );
        }
    }

 
    /// @notice This modify's a users maintenance margin requirement
    /// @dev Explain to a developer any extra details
    /// @param user the user we are modifying the mmr of
    /// @param in_token the token entering the users wallet
    /// @param out_token the token leaving the users wallet
    /// @param amount the amount being adjected
    function Modifymmr(
        address user,
        address in_token,
        address out_token,
        uint256 amount
    ) private {
        IDataHub.AssetData memory assetLogsOutToken = returnAssetLogs(
            out_token
        );
        IDataHub.AssetData memory assetLogsInToken = returnAssetLogs(in_token);
        if (amount <= Utilities.returnliabilities(user, in_token)) {
            uint256 StartingDollarMMR = (amount *
                assetLogsOutToken.MaintenanceMarginRequirement) / 10 ** 18; // check to make sure this is right
            if (
                StartingDollarMMR >
                Datahub.returnPairMMROfUser(user, in_token, out_token)
            ) {
                uint256 overage = (StartingDollarMMR -
                    Datahub.returnPairMMROfUser(user, in_token, out_token)) /
                    assetLogsInToken.MaintenanceMarginRequirement;

                Datahub.removeMaintenanceMarginRequirement(
                    user,
                    in_token,
                    out_token,
                    Datahub.returnPairMMROfUser(user, in_token, out_token)
                );

                uint256 liabilityMultiplier = REX_LIBRARY
                    .calculatedepositLiabilityRatio(
                        Utilities.returnliabilities(user, in_token),
                        overage
                    );

                address[] memory tokens = Datahub.returnUsersAssetTokens(user);

                for (uint256 i = 0; i < tokens.length; i++) {
                    Datahub.alterMMR(
                        user,
                        in_token,
                        tokens[i],
                        liabilityMultiplier
                    );
                }
            } else {
                Datahub.removeMaintenanceMarginRequirement(
                    user,
                    in_token,
                    out_token,
                    StartingDollarMMR
                );
            }
        } else {
            for (
                uint256 i = 0;
                i < Datahub.returnUsersAssetTokens(user).length;
                i++
            ) {
                address[] memory tokens = Datahub.returnUsersAssetTokens(user);
                Datahub.removeMaintenanceMarginRequirement(
                    user,
                    in_token,
                    tokens[i],
                    Datahub.returnPairMMROfUser(user, in_token, tokens[i])
                );
            }
        }
    }

    function revertTrade(
        address[2] memory pair,
        address[] memory takers,
        address[] memory makers,
        uint256[] memory taker_amounts,
        uint256[] memory maker_amounts
    ) public checkRoleAuthority {
        for (uint256 i = 0; i < takers.length; i++) {
            Datahub.addAssets(takers[i], pair[0], taker_amounts[i]);
            Datahub.removePendingBalances(takers[i], pair[0], taker_amounts[i]);
        }

        for (uint256 i = 0; i < makers.length; i++) {
            Datahub.addAssets(makers[i], pair[1], maker_amounts[i]);
            Datahub.removePendingBalances(makers[i], pair[0], maker_amounts[i]);
        }
    }

    /// @notice This returns all asset data from the asset data struct from IDatahub
    /// @param token the token we are fetching the data for
    /// @return assetLogs the asset logs for the asset
    function returnAssetLogs(
        address token
    ) public view returns (IDataHub.AssetData memory assetLogs) {
        IDataHub.AssetData memory assetlogs = Datahub.returnAssetLogs(token);
        return assetlogs;
    }

    /// @notice Alters the Admin roles for the contract
    /// @param _datahub  the new address for the datahub
    /// @param _depositVault the new address for the deposit vault
    /// @param _oracle the new address for oracle
    /// @param _utility the new address for the utility contract
    /// @param  _int the new address for the interest contract
    function alterAdminRoles(
        address _datahub,
        address _depositVault,
        address _oracle,
        address _utility,
        address _int
    ) public onlyOwner {
        Datahub = IDataHub(_datahub);
        DepositVault = IDepositVault(_depositVault);
        Oracle = IOracle(_oracle);
        Utilities = IUtilityContract(_utility);
        interestContract = IInterestData(_int);
    }

    receive() external payable {}
}
