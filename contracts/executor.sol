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

/// @title This is the EVO Exchange contract
/// @author EVO X Labs.
/// @notice This contract is responsible for sending trade requests to the Oracle
/// contract to be validated by the API3 Airnodes and executing the trades once confirmed

contract EVO_EXCHANGE is Ownable {
    /** Address's  */

    /// @notice Datahub contract
    IDataHub public Datahub;

    /// @notice Oracle contract
    IOracle public Oracle;

    /// @notice Deposit vaultcontract
    IDepositVault public DepositVault;

    /// @notice Interest contract
    IInterestData public interestContract;

    /// @notice The Utilities contract
    IUtilityContract public Utilities;
    /// @notice The Order book provider wallet address
    address public OrderBookProviderWallet;
    /// @notice The Liquidator contract address
    address public Liquidator;
    /// @notice The DAO wallet address
    address public DAO;

    /// @notice The current Airnode address
    address private airnodeAddress =
        address(0xbb9094538DfBB7949493D3E1E93832F36c3fBE8a);

    /// @notice Alters the Admin roles for the contract
    /// @param _datahub  the new address for the datahub
    /// @param _deposit_vault the new address for the deposit vault
    /// @param _oracle the new address for oracle
    /// @param _util the new address for the utility contract
    /// @param  _int the new address for the interest contract
    /// @param _liquidator the liquidator addresss
    function alterAdminRoles(
        address _datahub,
        address _deposit_vault,
        address _oracle,
        address _util,
        address _int,
        address _liquidator
    ) public onlyOwner {
        admins[_datahub] = true;
        Datahub = IDataHub(_datahub);
        admins[_deposit_vault] = true;
        DepositVault = IDepositVault(_deposit_vault);
        admins[_oracle] = true;
        Oracle = IOracle(_oracle);
        admins[_util] = true;
        Utilities = IUtilityContract(_util);
        admins[_int] = true;
        interestContract = IInterestData(_int);
        admins[_liquidator] = true;
        Liquidator = _liquidator;
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
        Liquidator = _liquidator;
    }

    /// @notice checks the role authority of the caller to see if they can change the state
    modifier checkRoleAuthority() {
        require(admins[msg.sender] == true, "Unauthorized");
        _;
    }

    /// @notice Keeps track of contract admins
    mapping(address => bool) public admins;

    /// @notice Fetches the current orderbook provider wallet
    function fetchOrderBookProvider() public view returns (address) {
        return OrderBookProviderWallet;
    }

    /// @notice Fetches the current DAO wallet
    function fetchDaoWallet() public view returns (address) {
        return DAO;
    }

    /// @notice Sets a new Airnode Address
    function setAirnodeAddress(address airnode) public onlyOwner {
        airnodeAddress = airnode;
    }

    /// @notice Sets a new orderbook provider wallet
    function setOrderBookProvider(address _newwallet) public onlyOwner {
        OrderBookProviderWallet = _newwallet;
    }

    /// @notice Sets a new DAO wallet
    function setDaoWallet(address _dao) public onlyOwner {
        DAO = _dao;
    }

    /// @notice This is the function users need to submit an order to the exchange
    /// @dev It first goes through some validation by checking if the circuit breaker is on, or if the airnode address is the right one
    /// @dev It calculates the amount to add to their liabilities by fetching their current assets and seeing the difference between the trade amount and assets
    /// @dev it then checks that the trade will not exceed the max borrow proportion, and that the user can indeed take more margin
    /// @dev it then calls the oracle
    /// @param pair the pair of tokens being traded
    /// @param participants of the trade 2 nested arrays
    /// @param trade_amounts the trades amounts for each participant
    function SubmitOrder(
        address[2] memory pair,
        address[][2] memory participants,
        uint256[][2] memory trade_amounts,
        bool[][2] memory trade_side,
        address[3] memory airnode_details,
        bytes32 endpointId,
        bytes calldata parameters
    ) public {
        require(DepositVault.viewcircuitBreakerStatus() == false);
        require(
            airnode_details[0] == airnodeAddress,
            "Must insert the airnode address to conduct a trade"
        );
        // require(airnode address == airnode address set on deployment )
        // (bool success, ) = payable(airnode_details[2]).call{value: msg.value}(
        //     ""
        //  );

        //  require(success);

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
            trade_side,
            takerLiabilities,
            makerLiabilities,
            airnode_details,
            endpointId,
            parameters
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
        address[] memory takers,
        address[] memory makers,
        uint256[] memory taker_amounts,
        uint256[] memory maker_amounts,
        uint256[] memory TakerliabilityAmounts,
        uint256[] memory MakerliabilityAmounts,
        bool[][2] memory trade_side
    ) external checkRoleAuthority {
        require(DepositVault.viewcircuitBreakerStatus() == false);
        Datahub.checkIfAssetIsPresent(takers, pair[1]);
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

    /// @notice This is called to execute the trade
    /// @dev Read the code comments to follow along on the logic
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

            if (msg.sender != address(Liquidator)) {
                if (trade_side[i] == true) {} else {
                    // This is where we take trade fees it is not called if the msg.sender is the liquidator
                    Datahub.addAssets(
                        fetchDaoWallet(),
                        out_token,
                        (amountToAddToLiabilities *
                            (Datahub.tradeFee(out_token, 0) -
                                Datahub.tradeFee(out_token, 1))) / 10 ** 18
                    );
                    amountToAddToLiabilities =
                        (amountToAddToLiabilities *
                            Datahub.tradeFee(out_token, 1)) /
                        10 ** 18;
                }
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
                // This will check to see if they are technically still margined and turn them off of margin status if they are eligable
                Datahub.changeMarginStatus(msg.sender);

                uint256 input_amount = amounts_in_token[i];

                if (msg.sender != address(Liquidator)) {
                    // below we charge trade fees it is not called if the msg.sender is the liquidator

                    if (trade_side[i] == false) {} else {
                        input_amount =
                            (input_amount * Datahub.tradeFee(in_token, 0)) /
                            10 ** 18;
                    }
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

    /// @notice This sets the users Initial Margin Requirement, and Maintenance Margin Requirements
    /// @dev This calls the Utilities contract
    /// @param user the user we are modifying
    /// @param in_token the token that has come into their account
    /// @param out_token the token that is leaving hteir account
    /// @param amount the amount to be adjusted
    function modifyMarginValues(
        address user,
        address in_token,
        address out_token,
        uint256 amount
    ) private {
        Utilities.Modifymmr(user, in_token, out_token, amount);
        Utilities.Modifyimr(user, in_token, out_token, amount);
    }

    /// @notice This unfreezes the users out_token balance, we do this so a user can't take out more trades as their trade is being processed
    /// @dev Explain to a developer any extra details
    /// @param user the user who we are unfreezing the balance of
    /// @param token the token that was involved in their trade
    /// @param amount the amount to be removed from pending
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

    /// @notice This pays out the user for depositted assets
    /// @param user the user to be debitted
    /// @param token the token they have accred deposit interest on
    function debitAssetInterest(address user, address token) private {
        (uint256 assets, , , , ) = Datahub.ReadUserData(user, token);

        uint256 cumulativeinterest = interestContract
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
    }

    /// @notice This will charge interest to a user if they are accuring new liabilities
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
        interestContract.chargeMassinterest(token);
 
    }

    receive() external payable {}
}
       /*
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
        */