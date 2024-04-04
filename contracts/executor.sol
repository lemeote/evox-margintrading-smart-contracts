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
        address _util,
        address _interest,
        address _liquidator
    ) public onlyOwner {
        admins[_DataHub] = true;
        admins[_deposit_vault] = true;
        admins[_oracle] = true;
        admins[_util] = true;
        admins[_interest] = true;
        interestContract = IInterestData(_interest);
        admins[_liquidator] = true;
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
            _utility,
            _interest,
            _liquidator
        );
        Datahub = IDataHub(_DataHub);
        DepositVault = IDepositVault(_deposit_vault);
        Oracle = IOracle(oracle);
        Utilities = IUtilityContract(_utility);
        interestContract = IInterestData(_interest);
        OrderBookProviderWallet = msg.sender;
        DAO = msg.sender;
    }

    modifier checkRoleAuthority() {
        require(admins[msg.sender] == true, "Unauthorized");
        _;
    }

    address public OrderBookProviderWallet;
    address public DAO;

    function fetchOrderBookProvider() public view returns (address) {
        return OrderBookProviderWallet;
    }

    function fetchDaoWallet() public view returns (address) {
        return DAO;
    }

    function setOrderBookProvider(address _newwallet) public onlyOwner {
        OrderBookProviderWallet = _newwallet;
    }

    function setDaoWallet(address _dao) public onlyOwner {
        DAO = _dao;
    }

    /// @notice Keeps track of contract admins
    mapping(address => bool) public admins;

    /// @notice This is the function users need to submit an order to the exchange
    /// @dev Explain to a developer any extra details
    /// @param pair the pair of tokens being traded
    /// @param participants of the trade 2 nested arrays
    /// @param trade_amounts the trades amounts for each participant
    function SubmitOrder(
        address[2] memory pair,
        address[][2] memory participants,
        uint256[][2] memory trade_amounts,
        bool[][2] memory trade_side
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
            Utilities.maxBorrowCheck(pair, participants, trade_amounts),
            "This trade puts the protocol above maximum borrow proportion and cannot be completed"
        );

        require(
            Utilities.processMargin(pair, participants, trade_amounts),
            "This trade failed the margin checks for one or more users"
        );

        Oracle.ProcessTrade(
            pair,
            participants,
            trade_amounts,
            takerLiabilities,
            makerLiabilities,
            trade_side
        );
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
        bool[][2] memory trade_side,
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

        executeTrade(
            takers,
            trade_side[0],
            maker_amounts,
            taker_amounts,
            TakerliabilityAmounts,
            pair[0],
            pair[1]
        );

        executeTrade(
            makers,
            trade_side[1],
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
        address[] memory users,
        bool[] memory trade_side,
        uint256[] memory amounts_in_token,
        uint256[] memory amounts_out_token,
        uint256[] memory liabilityAmounts,
        address out_token,
        address in_token
    ) private {
        for (uint256 i = 0; i < users.length; i++) {
            // here is the amount we are adding to their liabilities it is calculated using the difference between their assets and the trade amounts
            // this is calcualte above in submit order
            uint256 amountToAddToLiabilities = liabilityAmounts[i];

            if (trade_side[i] == true) {} else {
                // This is where we take trade fees
                Datahub.addAssets(
                    fetchDaoWallet(),
                    out_token,
                    (amountToAddToLiabilities *
                        (Datahub.tradeFee(out_token, 0) -
                            Datahub.tradeFee(out_token, 1))) / 10 ** 18
                );
                amountToAddToLiabilities -
                    (amountToAddToLiabilities *
                        Datahub.tradeFee(out_token, 1)) /
                    10 ** 18;
            }

            if (amountToAddToLiabilities != 0) {
                // in this function we charge interest to the user and add to their liabilities
                chargeinterest(
                    users[i],
                    out_token,
                    amountToAddToLiabilities,
                    false
                );
                // this is where we add to their maintenance margin requirement because we are issuing them liabilities
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
            // if the amount coming into their wallet is larger than their current liabilities
            if (
                amounts_in_token[i] <=
                Utilities.returnliabilities(users[i], in_token)
            ) {
                // charge interest and subtract from their liabilities, do not add to assets just subtract from liabilities
                chargeinterest(users[i], in_token, amounts_in_token[i], true);

                // edit inital margin requirement, and maintenance margin requirement of the user
                modifyMarginValues(
                    users[i],
                    in_token,
                    out_token,
                    amounts_in_token[i]
                );
            } else {
                // at this point we know that the amount coming in is larger than their liabilities so we can zero their liabilities
                uint256 subtractedFromLiabilites = Utilities.returnliabilities(
                    users[i],
                    in_token
                );

                uint256 input_amount = amounts_in_token[i];

                // below we charge trade fees
                if (trade_side[i] == false) {} else {
                    input_amount =
                        input_amount -
                        (input_amount * Datahub.tradeFee(in_token, 0)) /
                        10 ** 18;
                }

                if (subtractedFromLiabilites > 0) {
                    input_amount -= Utilities.returnliabilities(
                        users[i],
                        in_token
                    );
                    // Charge a user interest and subtract from their liabilities
                    chargeinterest(
                        users[i],
                        in_token,
                        subtractedFromLiabilites,
                        true
                    );
                    // edit inital margin requirement, and maintenance margin requirement of the user
                    modifyMarginValues(
                        users[i],
                        in_token,
                        out_token,
                        input_amount
                    );
                }
                // remove their pending balances
                unFreezeBalance(users[i], out_token, amounts_out_token[i]);
                // give users their deposit interest accrued
                debitAssetInterest(users[i], in_token);
                // add remaining amount not subtracted from liabilities to assets
                Datahub.addAssets(users[i], in_token, input_amount);
            }
        }
    }

    function modifyMarginValues(
        address user,
        address in_token,
        address out_token,
        uint256 amount
    ) private {
        Utilities.Modifymmr(user, in_token, out_token, amount);
        Utilities.Modifyimr(user, in_token, out_token, amount);
    }

    function unFreezeBalance(
        address user,
        address token,
        uint256 amount
    ) private {
        amount > Utilities.returnPending(user, token)
            ? Datahub.removePendingBalances(
                user,
                token,
                Utilities.returnPending(user, token)
            )
            : Datahub.removePendingBalances(user, token, amount);
    }

    function debitAssetInterest(address user, address token) private {
        (uint256 assets, , , , ) = Datahub.ReadUserData(user, token);
    
        uint256 cumulativeinterest = 
         interestContract
            .calculateAverageCumulativeDepositInterest(
                Datahub.viewUsersEarningRateIndex(user, token),
                interestContract.fetchCurrentRateIndex(token),
                token
            );
            
        (
            uint256 interestCharge,
            uint256 OrderBookProviderCharge,
            uint256 DaoInterestCharge
        ) = EVO_LIBRARY.calculateCompoundedAssets(
                interestContract.fetchCurrentRateIndex(token),
                cumulativeinterest,
                assets,
                Datahub.viewUsersEarningRateIndex(user, token)
            );

        Datahub.alterUsersEarningRateIndex(user, token);

        Datahub.addAssets(user, token, interestCharge);
        Datahub.addAssets(fetchDaoWallet(), token, DaoInterestCharge);

        Datahub.addAssets(
            fetchOrderBookProvider(),
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
            
            (, uint256 liabilities, , , ) = Datahub.ReadUserData(user, token);

            uint256 interestCharge = EVO_LIBRARY.calculateCompoundedLiabilities(
                interestContract.fetchCurrentRateIndex(token),
                interestContract.calculateAverageCumulativeInterest(
                    Datahub.viewUsersInterestRateIndex(user, token),
                    interestContract.fetchCurrentRateIndex(token),
                    token
                ),
                Datahub.returnAssetLogs(token),
                interestContract.fetchRateInfo(
                    token,
                    interestContract.fetchCurrentRateIndex(token)
                ),
                liabilitiesAccrued,
                liabilities,
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
                Utilities.chargeStaticLiabilityInterest(
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
/*

       /*
            uint256 interestCharge = EVO_LIBRARY
                .calculateCompoundedLiabilities(
                    token,
                    liabilitiesAccrued,
                    Utilities.returnliabilities(user, token),
                    Datahub.viewUsersInterestRateIndex(user, token)
                );

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

*/
