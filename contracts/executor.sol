// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IDataHub.sol";
import "./interfaces/IDepositVault.sol";
import "./interfaces/IOracle.sol";
import "./interfaces/IUtilityContract.sol";
import "./libraries/EVO_LIBRARY.sol";
import "./interfaces/IinterestData.sol";
import "hardhat/console.sol";

contract EVO_EXCHANGE is Ownable {
    /** Address's  */

    IDataHub public Datahub;

    IOracle public Oracle;

    IDepositVault public DepositVault;

    IInterestData public interestContract;

    IUtilityContract public Utilities;

    function alterAdminRoles(
        address _DataHub,
        address _deposit_vault,
        address _oracle,
        address _interest,
        address _liquidator
    ) public onlyOwner {
        admins[_DataHub] = true;
        admins[_deposit_vault] = true;
        admins[_oracle] = true;
        admins[_interest] = true;
        admins[_liquidator] = true;
        interestContract = IInterestData(_interest);
    }

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
        alterAdminRoles(
            _DataHub,
            _deposit_vault,
            oracle,
            _interest,
            _liquidator
        );
        Datahub = IDataHub(_DataHub);
        DepositVault = IDepositVault(_deposit_vault);
        Oracle = IOracle(oracle);
        Utilities = IUtilityContract(_utility);
        interestContract = IInterestData(_interest);
    }

    modifier checkRoleAuthority() {
        require(admins[msg.sender] == true, "Unauthorized");
        _;
    }

    /// @notice Keeps track of contract admins
    mapping(address => bool) public admins;

    /// @notice This is the function users need to submit an order to the exchange
    /// @dev Explain to a developer any extra details
    /// @param pair the pair of tokens being traded
    /// @param participants of the trade 2 nested arrays
    /// @param trade_amounts the trades amounts for each participant
    function SubmitOrder(
        bool feeSide,
        address[2] memory pair,
        address[][2] memory participants,
        uint256[][2] memory trade_amounts
    ) public {
        require(DepositVault.viewcircuitBreakerStatus() == false);
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
        require(
            maxBorrowCheck(pair, participants, trade_amounts),
            "This trade puts the protocol above maximum borrow proportion and cannot be completed"
        );

        require(
            processMargin(pair, participants, trade_amounts),
            "This trade failed the margin checks for one or more users"
        );

        Oracle.ProcessTrade(
            feeSide,
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
            newLiabilitiesIssued = EVO_LIBRARY.calculateTotal(
                trade_amounts[i]
            ) > Utilities.returnBulkAssets(participants[i], pair[i])
                ? EVO_LIBRARY.calculateTotal(trade_amounts[i]) -
                    Utilities.returnBulkAssets(participants[i], pair[i])
                : 0;

            if (newLiabilitiesIssued > 0) {
                return
                    EVO_LIBRARY.calculateBorrowProportionAfterTrades(
                        Datahub.returnAssetLogs(pair[i]),
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
                uint256 initalMarginFeeAmount = EVO_LIBRARY
                    .calculateinitialMarginFeeAmount(
                        Datahub.returnAssetLogs(pair),
                        tradeAmounts[i]
                    );
                initalMarginFeeAmount *= (Datahub
                    .returnAssetLogs(pair)
                    .assetPrice) / 10**18;

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

    address public USDT = address(0xdfc6a3f2d7daff1626Ba6c32B79bEE1e1d6259F0);

    /// @notice This called the execute trade functions on the particpants and checks if the assets are already in their portfolio
    /// @param pair the pair of assets involved in the trade
    /// @param takers the taker wallet addresses
    /// @param makers the maker wallet addresses
    /// @param taker_amounts the taker amounts in the trade
    /// @param maker_amounts the maker amounts in the trade
    /// @param TakerliabilityAmounts the new liabilities being issued to the takers
    /// @param MakerliabilityAmounts the new liabilities being issued to the makers
    function TransferBalances(
        bool feeSide,
        address[2] memory pair,
        address[] memory takers,
        address[] memory makers,
        uint256[] memory taker_amounts,
        uint256[] memory maker_amounts,
        uint256[] memory TakerliabilityAmounts,
        uint256[] memory MakerliabilityAmounts
    ) external checkRoleAuthority {
        require(DepositVault.viewcircuitBreakerStatus() == false);
        Datahub.checkIfAssetIsPresent(takers, pair[1]); /// charge the fee rate below on this
        Datahub.checkIfAssetIsPresent(makers, pair[0]);
        uint256[2] memory pair1Fees;
        uint256[2] memory pair0Fees;

        if (feeSide == true) {
            if (pair[1] != USDT) {
                // taker
                pair1Fees = Datahub.returnAssetLogs(pair[1]).Tradefees;
            } else {
                pair1Fees = Datahub.returnAssetLogs(pair[0]).Tradefees;
            }
            // pair1Fees[0]
        } else {
            if (pair[1] != USDT) {
                //maker
                pair0Fees = Datahub.returnAssetLogs(pair[1]).Tradefees;
            } else {
                pair0Fees = Datahub.returnAssetLogs(pair[0]).Tradefees;
            }
            // pair1Fees[1]
        }

        executeTrade(
            pair1Fees[0],
            takers,
            maker_amounts,
            taker_amounts,
            TakerliabilityAmounts,
            pair[0],
            pair[1]
        );

        executeTrade(
            pair0Fees[1],
            makers,
            taker_amounts,
            maker_amounts,
            MakerliabilityAmounts,
            pair[1],
            pair[0]
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
        uint256 feeRate,
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
                    EVO_LIBRARY.calculateMaintenanceRequirementForTrade(
                        Datahub.returnAssetLogs(in_token),
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
                Modifyimr(users[i], in_token, out_token, amounts_in_token[i]);
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
                    Modifyimr(
                        users[i],
                        in_token,
                        out_token,
                        amounts_in_token[i]
                    );
                }
                /*
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
*/
                (uint256 assets, , , , ) = Datahub.ReadUserData(
                    users[i],
                    in_token
                );

                if (assets > 0) {
                    debitAssetInterest(users[i], in_token);
                }
                // mark with the boolean 
                // if the boolean is true 
                // then lower the amount in token
                // return the amount to raise the out token by in the next order
                // 
                /*

                if(TakerOrder == true){
                   input_amount *= feeRate; // discount the amount in 
                   return the amount you lowered their in token
                }else{
                    multiply the  amount you lowered their in token by the price of the out_token to get the out_token equalivelent 
                    add that to the makers assets () - spread and send to evox dao wallet
                }

                */
                input_amount *= feeRate;
                // we add assets of the in token to maker and taker -->
                Datahub.addAssets(users[i], in_token, input_amount);

                // Conditions met assets changed, set flag to true
            }
        }
    }

    function debitAssetInterest(address user, address token) private {
        (uint256 assets, , , , ) = Datahub.ReadUserData(user, token);
        (
            uint256 interestCharge,
            uint256 OrderBookProviderCharge,
            uint256 DaoInterestCharge
        ) = interestContract.calculateCompoundedAssets(
                token,
                assets,
                Datahub.viewUsersInterestRateIndex(user, token)
            );
        Datahub.alterUsersEarningRateIndex(user, token);

        Datahub.addAssets(user, token, interestCharge);
        Datahub.addAssets(Datahub.fetchDaoWallet(), token, DaoInterestCharge);

        Datahub.addAssets(
            Datahub.fetchOrderBookProvider(),
            token,
            OrderBookProviderCharge
        );

        /// need to update earning index IMPORTANT change to earning index its  a must because of the withdraws
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
                EVO_LIBRARY.calculateInterestRate(
                    liabilitiesAccrued,
                    Datahub.returnAssetLogs(token),
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
        IDataHub.AssetData memory assetLogsOutToken = Datahub.returnAssetLogs(
            out_token
        );
        IDataHub.AssetData memory assetLogsInToken = Datahub.returnAssetLogs(
            in_token
        );
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

                uint256 liabilityMultiplier = EVO_LIBRARY
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

    function Modifyimr(
        address user,
        address in_token,
        address out_token,
        uint256 amount
    ) private {
        IDataHub.AssetData memory assetLogsOutToken = Datahub.returnAssetLogs(
            out_token
        );
        IDataHub.AssetData memory assetLogsInToken = Datahub.returnAssetLogs(
            in_token
        );
        if (amount <= Utilities.returnliabilities(user, in_token)) {
            uint256 StartingDollarIMR = (amount *
                assetLogsOutToken.initialMarginRequirement) / 10 ** 18; // check to make sure this is right
            if (
                StartingDollarIMR >
                Datahub.returnPairIMROfUser(user, in_token, out_token)
            ) {
                uint256 overage = (StartingDollarIMR -
                    Datahub.returnPairIMROfUser(user, in_token, out_token)) /
                    assetLogsInToken.initialMarginRequirement;

                Datahub.removeInitialMarginRequirement(
                    user,
                    in_token,
                    out_token,
                    Datahub.returnPairIMROfUser(user, in_token, out_token)
                );

                uint256 liabilityMultiplier = EVO_LIBRARY
                    .calculatedepositLiabilityRatio(
                        Utilities.returnliabilities(user, in_token),
                        overage
                    );

                address[] memory tokens = Datahub.returnUsersAssetTokens(user);

                for (uint256 i = 0; i < tokens.length; i++) {
                    Datahub.alterIMR(
                        user,
                        in_token,
                        tokens[i],
                        liabilityMultiplier
                    );
                }
            } else {
                Datahub.removeInitialMarginRequirement(
                    user,
                    in_token,
                    out_token,
                    StartingDollarIMR
                );
            }
        } else {
            for (
                uint256 i = 0;
                i < Datahub.returnUsersAssetTokens(user).length;
                i++
            ) {
                address[] memory tokens = Datahub.returnUsersAssetTokens(user);
                Datahub.removeInitialMarginRequirement(
                    user,
                    in_token,
                    tokens[i],
                    Datahub.returnPairIMROfUser(user, in_token, tokens[i])
                );
            }
        }
    }

    /*
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
    */

    /// @notice This returns all asset data from the asset data struct from IDatahub
    /// @param token the token we are fetching the data for
    /// @return assetLogs the asset logs for the asset
    /*
    function returnAssetLogs(
        address token
    ) public view returns (IDataHub.AssetData memory assetLogs) {
        IDataHub.AssetData memory assetlogs = Datahub.returnAssetLogs(token);
        return assetlogs;
    }
*/
    /// @notice Alters the Admin roles for the contract
    /// @param _datahub  the new address for the datahub
    /// @param _depositVault the new address for the deposit vault
    /// @param _oracle the new address for oracle
    /// @param _utility the new address for the utility contract
    /// @param  _int the new address for the interest contract
    function alterContractStrucutre(
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
