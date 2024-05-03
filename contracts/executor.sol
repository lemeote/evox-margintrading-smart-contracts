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
        bool[][2] memory trade_side
    ) public {
        console.log("========================submit order function==========================");
        require(DepositVault.viewcircuitBreakerStatus() == false);
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

        console.log("taker liabilities", takerLiabilities[0]);
        console.log("maker liabilities", makerLiabilities[0]);

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
        console.log("===========================executeTrade Function===========================");
        for (uint256 i = 0; i < users.length; i++) {
            // here is the amount we are adding to their liabilities it is calculated using the difference between their assets and the trade amounts
            // this is calcualte above in submit order
            uint256 amountToAddToLiabilities = liabilityAmounts[i];
            console.log("amount to add to liabilities", amountToAddToLiabilities);
            console.log("tradefee0", Datahub.tradeFee(out_token, 0));
            console.log("tradefee1", Datahub.tradeFee(out_token, 1));
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

            // (uint256 assets, uint256 liabilities, uint256 pending, bool margined, ) = Datahub.ReadUserData(
            //     fetchDaoWallet(),
            //     out_token
            // );
            // console.log("assets after process fee", assets);
            // console.log("liabilities after process fee", liabilities);
            // console.log("pending after process fee", pending);
            // console.log("margined after process fee", margined);
            // console.log("tokens after process fee", tokens);

            console.log("amountToAddToLiabilities after process fee", amountToAddToLiabilities);

            if (amountToAddToLiabilities != 0) {
                // in this function we charge interest to the user and add to their liabilities
                chargeinterest(
                    users[i],
                    out_token,
                    amountToAddToLiabilities,
                    false
                );

                // (uint256 assets, uint256 liabilities, uint256 pending, bool margined, ) = Datahub.ReadUserData(
                //     users[i],
                //     out_token
                // );

                // console.log("assets after after charge", assets);
                // console.log("liabilities after charge", liabilities);
                // console.log("pending after charge", pending);
                // console.log("margined after charge", margined);
                // // console.log("tokens after charge", tokens);

                console.log("amountToAddToLiabilities after charge", amountToAddToLiabilities);

                console.log("maintenancerequirementfortrade", EVO_LIBRARY.calculateMaintenanceRequirementForTrade( // 150
                    Datahub.returnAssetLogs(in_token),
                    amountToAddToLiabilities
                ));

                // this is where we add to their maintenance margin requirement because we are issuing them liabilities
                Datahub.addMaintenanceMarginRequirement(
                    users[i],
                    out_token,
                    in_token,
                    EVO_LIBRARY.calculateMaintenanceRequirementForTrade( // 150
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
        console.log("====================debit asset interest function======================");
        (uint256 assets, , , , ) = Datahub.ReadUserData(user, token);
        console.log("assets", assets);

        uint256 cumulativeinterest = interestContract
            .calculateAverageCumulativeDepositInterest(
                Datahub.viewUsersEarningRateIndex(user, token),
                interestContract.fetchCurrentRateIndex(token),
                token
            );
        
        console.log("cumulative interest", cumulativeinterest);

        (
            uint256 interestCharge,
            uint256 OrderBookProviderCharge,
            uint256 DaoInterestCharge
        ) = EVO_LIBRARY.calculateCompoundedAssets(
                interestContract.fetchCurrentRateIndex(token),
                (cumulativeinterest / 10 ** 18),
                assets,
                Datahub.viewUsersEarningRateIndex(user, token)
            );

        console.log("interestCharge", interestCharge);
        console.log("OrderBookProviderCharge", OrderBookProviderCharge);
        console.log("DaoInterestCharge", DaoInterestCharge);

        Datahub.alterUsersEarningRateIndex(user, token);

        console.log("currentUsersEarningRateIndex", Datahub.viewUsersEarningRateIndex(user, token));

        Datahub.addAssets(user, token, (interestCharge / 10 ** 18));

        (uint256 assets_test, uint256 liabilities, uint256 pending, bool margined, ) = Datahub.ReadUserData(
            user,
            token
        );

        console.log("assets after after add assets", assets_test);
        console.log("liabilities after add assets", liabilities);
        console.log("pending after add assets", pending);
        console.log("margined after add assets", margined);
        // console.log("tokens after add assets", tokens);

        Datahub.addAssets(
            fetchDaoWallet(),
            token,
            (DaoInterestCharge / 10 ** 18)
        );

        (assets, liabilities, pending, margined, ) = Datahub.ReadUserData(
            fetchDaoWallet(),
            token
        );

        console.log("assets after after add assets", assets);
        console.log("liabilities after add assets", liabilities);
        console.log("pending after add assets", pending);
        console.log("margined after add assets", margined);
        // console.log("tokens after add assets", tokens);

        Datahub.addAssets(
            fetchOrderBookProvider(),
            token,
            (OrderBookProviderCharge / 10 ** 18)
        );

        (assets, liabilities, pending, margined, ) = Datahub.ReadUserData(
            fetchOrderBookProvider(),
            token
        );

        console.log("assets after after add assets", assets);
        console.log("liabilities after add assets", liabilities);
        console.log("pending after add assets", pending);
        console.log("margined after add assets", margined);
        // console.log("tokens after add assets", tokens);
    }

    /// @notice This fetches a users accrued deposit interest
    /// @dev when a user deposits to the exchange they earn interest on their deposit paid for by margined users who have liabilities
    /// @param user the user we are wishing to see the deposit interest for
    /// @param token the token the user is earning deposit interest on
    /// @return interestCharge the amount of deposit interest the user has accrued
    function fetchUsersDepositInterest(
        address user,
        address token
    ) public view returns (uint256) {
        (uint256 assets, , , , ) = Datahub.ReadUserData(user, token);
        uint256 cumulativeinterest = interestContract
            .calculateAverageCumulativeDepositInterest(
                Datahub.viewUsersEarningRateIndex(user, token),
                interestContract.fetchCurrentRateIndex(token),
                token
            );

        (uint256 interestCharge, , ) = EVO_LIBRARY.calculateCompoundedAssets(
            interestContract.fetchCurrentRateIndex(token),
            (cumulativeinterest / 10 ** 18),
            assets,
            Datahub.viewUsersEarningRateIndex(user, token)
        );
        return interestCharge;
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

        console.log("=====================chargeinterest function===================");
        //Step 1) charge mass interest on outstanding liabilities
        interestContract.chargeMassinterest(token);

        (uint256 assets, uint256 liabilities, uint256 pending, bool margined, ) = Datahub.ReadUserData(
            user,
            token
        );
        console.log("assets after charge massin interest", assets);
        console.log("liabilities after charge massin interest", liabilities);
        console.log("pending after charge massin interest", pending);
        console.log("margined after charge massin interest", margined);
        // console.log("tokens after charge massin interest", tokens);

        console.log("total borrow amount after charge massin interest", Datahub.returnAssetLogs(token).totalBorrowedAmount);

        if (minus == false) {
            //Step 2) calculate the trade's liabilities + interest
            uint256 interestCharge = interestContract.returnInterestCharge(
                user,
                token,
                liabilitiesAccrued
            );

            console.log("interest charge after returnInterestCharge", interestCharge);

            Datahub.addLiabilities(
                user,
                token,
                liabilitiesAccrued + interestCharge
            );

            (uint256 assets, uint256 liabilities, uint256 pending, bool margined, ) = Datahub.ReadUserData(
                user,
                token
            );

            console.log("assets after add liabilities", assets);
            console.log("liabilities after add liabilities", liabilities);
            console.log("pending after add liabilities", pending);
            console.log("margined after add liabilities", margined);
            // console.log("tokens after add liabilities", tokens);

            console.log("total borrow amount after charge massin interest", Datahub.returnAssetLogs(token).totalBorrowedAmount);

            Datahub.setTotalBorrowedAmount(
                token,
                (liabilitiesAccrued + interestCharge),
                true
            );

            console.log("total borrow amount after setting borrow amount", Datahub.returnAssetLogs(token).totalBorrowedAmount);

            Datahub.alterUsersInterestRateIndex(user, token);
        } else {
            uint256 interestCharge = interestContract.returnInterestCharge(
                user,
                token,
                0
            );

            console.log("interest charge after returnInterestCharge", interestCharge);

            Datahub.addLiabilities(user, token, interestCharge);

            (uint256 assets, uint256 liabilities, uint256 pending, bool margined, ) = Datahub.ReadUserData(
                user,
                token
            );

            console.log("assets after add liabilities", assets);
            console.log("liabilities after add liabilities", liabilities);
            console.log("pending after add liabilities", pending);
            console.log("margined after add liabilities", margined);
            // console.log("tokens after add liabilities", tokens);

            Datahub.removeLiabilities(user, token, liabilitiesAccrued);

            (assets, liabilities, pending, margined, ) = Datahub.ReadUserData(
                user,
                token
            );

            console.log("assets after remove liabilities", assets);
            console.log("liabilities after remove liabilities", liabilities);
            console.log("pending after remove liabilities", pending);
            console.log("margined after remove liabilities", margined);
            // console.log("tokens after remove liabilities", tokens);

            Datahub.setTotalBorrowedAmount(
                token,
                (liabilitiesAccrued - interestCharge),
                false
            );

            console.log("total borrow amount after charge massin interest", Datahub.returnAssetLogs(token).totalBorrowedAmount);

            Datahub.alterUsersInterestRateIndex(user, token);
        }
    }

    receive() external payable {}
}

/*

    function chargeinterest(
        address user,
        address token,
        uint256 liabilitiesAccrued,
        bool minus
    ) private {
        // minus = false if we are adding to liability pool 
        // token false, liabilities
        bool InterestUpdated = UpdateIndex(token, minus, liabilitiesAccrued);

        if (minus == false) {
            uint256 interestCharge = interestContract.returnInterestCharge(
                user,
                token,
                liabilitiesAccrued
            );
            
            Datahub.addLiabilities(
                user,
                token,
                liabilitiesAccrued + interestCharge
            );

            Datahub.alterUsersInterestRateIndex(user, token);

            if (InterestUpdated) {
                Datahub.setTotalBorrowedAmount(token, (interestCharge), true);
            } else {
                Datahub.setTotalBorrowedAmount(
                    token,
                    (liabilitiesAccrued + interestCharge),
                    true
                );
            }
        }
        if (minus == true) {
            uint256 interestCharge = interestContract.returnInterestCharge(
                user,
                token,
                liabilitiesAccrued
            );

            if (InterestUpdated) {
                Datahub.setTotalBorrowedAmount(token, (interestCharge), false);
            } else {
                Datahub.setTotalBorrowedAmount(
                    token,
                    (liabilitiesAccrued + interestCharge),
                    false
                );
            }
            Datahub.addLiabilities(user, token, interestCharge);

            Datahub.removeLiabilities(user, token, liabilitiesAccrued);
        }
    }



    function checkIfInterestIndexUpdateIsRequired(
        address token
    ) private view returns (bool) {
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
            return true;
        } else {
            return false;
        }
    }


    function UpdateIndex(
        address token,
        bool minus,
        uint256 liabilitiesAccrued
    ) private returns (bool) {
        if (checkIfInterestIndexUpdateIsRequired(token)) {
            if (!minus) { 
                Datahub.setTotalBorrowedAmount(
                    token,
                    liabilitiesAccrued,
                    true
                );
            } else {
                // here its taking away to total borrowed 
                Datahub.setTotalBorrowedAmount(token, liabilitiesAccrued, false);
            }

            updateInterestIndex(token, liabilitiesAccrued);
            return true;
        } else {
            return false;
        }
    }
*/

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
