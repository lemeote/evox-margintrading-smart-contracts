// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IDataHub.sol";
import "./interfaces/IDepositVault.sol";
import "./interfaces/IExecutor.sol";
import "hardhat/console.sol";
contract Oracle is Ownable{
    /// @notice Keeps track of contract admins
    mapping(address => bool) public admins;

    IDataHub public Datahub;
    IExecutor public Executor;
    IDepositVault public DepositVault;

    address public USDT = address(0xaBAD60e4e01547E2975a96426399a5a0578223Cb);

    uint256 public lastOracleFufillTime;

    bytes32 public lastRequestId;

    error Error_FufillUnSuccessful(bytes32 requestid, uint256 timeStamp);

    /** Constructor  */
    constructor(
        address initialOwner,
        address _DataHub,
        address _deposit_vault,
        address _executor
    ) Ownable(initialOwner) {
        Datahub = IDataHub(_DataHub);
        DepositVault = IDepositVault(_deposit_vault);
        Executor = IExecutor(_executor);
    }

    function alterAdminRoles(
        address _ex,
        address _DataHub,
        address _deposit_vault
    ) public onlyOwner {
        admins[_ex] = true;
        Datahub = IDataHub(_DataHub);
        DepositVault = IDepositVault(_deposit_vault);
        Executor = IExecutor(_ex);
    }

    /** Mapping's  */
    mapping(bytes32 => uint256) requestTime;
    mapping(bytes32 => bool) public incomingFulfillments;
    mapping(bytes32 => int256) public fulfilledData;

    modifier checkRoleAuthority() {
        require(admins[msg.sender] == true, "Unauthorized");
        _;
    }

    /** Struct's  */
    struct Order {
        address taker_token;
        address maker_token;
        address[] takers;
        address[] makers;
        uint256[] taker_amounts;
        uint256[] maker_amounts;
        bool[][2] trade_sides;
        uint256[] takerliabilityAmounts;
        uint256[] makerliabilityAmounts;
        string _id;
    }

    mapping(bytes32 => Order) public OrderDetails;

    /** event's  */
    event QueryCalled(string description, uint256 timestamp, bytes32 requestId);
    event TradeExecuted(uint256 blocktimestamp);

    event TradeReverted(
        bytes32 requestId,
        address taker_token,
        address maker_token,
        address[] takers,
        address[] makers,
        uint256[] taker_amounts,
        uint256[] maker_amounts
    );




    function revertTrade(bytes32 requestId) public {
        if (
            incomingFulfillments[requestId] =
                true &&
                requestTime[requestId] + 1 hours > block.timestamp
        ) {
            delete incomingFulfillments[requestId];

            address[2] memory pair;
            pair[0] = OrderDetails[requestId].taker_token;
            pair[1] = OrderDetails[requestId].maker_token;

            revertTrade(
                pair,
                OrderDetails[requestId].takers,
                OrderDetails[requestId].makers,
                OrderDetails[requestId].taker_amounts,
                OrderDetails[requestId].maker_amounts
            );

            emit TradeReverted(
                requestId,
                pair[0],
                pair[1],
                OrderDetails[requestId].takers,
                OrderDetails[requestId].makers,
                OrderDetails[requestId].taker_amounts,
                OrderDetails[requestId].maker_amounts
            );
        }
    }
    function ProcessTrade(
        address[2] memory pair,
        address[][2] memory participants,
        uint256[][2] memory trade_amounts,
        uint256[] memory TakerliabilityAmounts,
        uint256[] memory MakerliabilityAmounts,
        bool[][2] memory trade_side
    )
        external
        checkRoleAuthority
    {
        bytes32 orderId = bytes32(
            uint256(2636288841321219110873651998422106944)
        );

        OrderDetails[orderId].taker_token = pair[0];
        OrderDetails[orderId].maker_token = pair[1];
        OrderDetails[orderId].taker_amounts = trade_amounts[0];
        OrderDetails[orderId].maker_amounts = trade_amounts[1];
        OrderDetails[orderId].trade_sides = trade_side;

        OrderDetails[orderId].takers = participants[0];
        OrderDetails[orderId].makers = participants[1];
        OrderDetails[orderId].takerliabilityAmounts = TakerliabilityAmounts;
        OrderDetails[orderId].makerliabilityAmounts = MakerliabilityAmounts;

        makeRequest(orderId, pair, participants, trade_amounts, trade_side);

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
        // console.log("================alterPending Function================");

        for (uint256 i = 0; i < participants.length; i++) {
            (uint256 assets, , , , ) = Datahub.ReadUserData(
                participants[i],
                pair
            );
            if (tradeside[i] == true) {} else {
                uint256 trade1 = Datahub.tradeFee(pair, 1);
                tradeAmounts[i] = (trade1 * tradeAmounts[i]) / 10 ** 18;
            }
            uint256 balanceToAdd = tradeAmounts[i] > assets ? assets : tradeAmounts[i];
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
        Datahub.removeAssets(participant, asset, trade_amount);
        Datahub.addPendingBalances(participant, asset, trade_amount);
    }

    function makeRequest(
        bytes32 requestId,
        address[2] memory pair,
        address[][2] memory participants,
        uint256[][2] memory trade_amounts,
        bool[][2] memory trade_side
    ) internal returns (uint) {

        // console.log("=================make request funciton================");

        freezeTempBalance(pair, participants, trade_amounts, trade_side);

        // (uint256 assets, uint256 liabilities, uint256 pending, bool margined, ) = Datahub.ReadUserData(
        //     participants[0][0],
        //     pair[0]
        // );
        // console.log("assets after freeze", assets);
        // console.log("liabilities after freeze", liabilities);
        // console.log("pending after freeze", pending);
        // console.log("margined after freeze", margined);
        // console.log("tokens after freeze", tokens);

        requestId = bytes32(uint256(2636288841321219110873651998422106944));

        fulfill(requestId);

        return 1;
    }

    /// The AirnodeRrpV0.sol protocol contract will callback here.
    function fulfill(bytes32 requestId) internal {
        if (
            requestId != bytes32(uint256(2636288841321219110873651998422106944))
        ) {

            revert Error_FufillUnSuccessful(requestId, block.timestamp); //
        } else {
            // console.log("=====================fulfill function=================");
            address[2] memory pair;
            pair[0] = OrderDetails[requestId].taker_token;
            pair[1] = OrderDetails[requestId].maker_token;

            Executor.TransferBalances(
             pair,
                OrderDetails[requestId].takers,
                OrderDetails[requestId].makers,
                OrderDetails[requestId].taker_amounts,
                OrderDetails[requestId].maker_amounts,
                OrderDetails[requestId].takerliabilityAmounts,
                OrderDetails[requestId].makerliabilityAmounts,
                OrderDetails[requestId].trade_sides
            );

            // (uint256 assets, uint256 liabilities, uint256 pending, bool margined, ) = Datahub.ReadUserData(
            //     OrderDetails[requestId].takers[0],
            //     pair[0]
            // );
            // console.log("assets after transfer", assets);
            // console.log("liabilities after transfer", liabilities);
            // console.log("pending after transfer", pending);
            // console.log("margined after transfer", margined);
            // console.log("tokens after transfer", tokens);

            // The reason why we update price AFTER we make the call to the executor is because if it fails, the prices wont update
            // and the update prices wll not be included in the  TX
            if (pair[0] == USDT) {
                // console.log("taker amount", OrderDetails[requestId].taker_amounts[
                //     OrderDetails[requestId].taker_amounts.length - 1
                // ]);
                // console.log("decimal", DepositVault.fetchDecimals(pair[1]));
                // console.log("maker amount", OrderDetails[requestId].maker_amounts[
                //     OrderDetails[requestId].maker_amounts.length - 1
                // ]);
                // console.log("result", ((OrderDetails[requestId].taker_amounts[
                //     OrderDetails[requestId].taker_amounts.length - 1
                // ] * (10 ** DepositVault.fetchDecimals(pair[1]))) /
                //     OrderDetails[requestId].maker_amounts[
                //         OrderDetails[requestId].maker_amounts.length - 1
                //     ]));
                uint256 decimals = DepositVault.fetchDecimals(pair[1]);
                Datahub.toggleAssetPrice(
                    pair[1],
                    ((OrderDetails[requestId].taker_amounts[
                        OrderDetails[requestId].taker_amounts.length - 1
                    ] * (10 ** decimals)) /
                        OrderDetails[requestId].maker_amounts[
                            OrderDetails[requestId].maker_amounts.length - 1
                        ])
                );
            } else {
                // console.log("maker amount", OrderDetails[requestId].maker_amounts[
                //     OrderDetails[requestId].maker_amounts.length - 1
                // ]);
                // console.log("decimal", DepositVault.fetchDecimals(pair[0]));
                // console.log("taker amount", OrderDetails[requestId].taker_amounts[
                //     OrderDetails[requestId].maker_amounts.length - 1
                // ]);
                // console.log("result", ((OrderDetails[requestId].maker_amounts[
                //     OrderDetails[requestId].maker_amounts.length - 1
                // ] * (10 ** DepositVault.fetchDecimals(pair[0]))) /
                //     OrderDetails[requestId].taker_amounts[
                //         OrderDetails[requestId].taker_amounts.length - 1
                //     ]));
                uint256 decimals = DepositVault.fetchDecimals(pair[0]);
                Datahub.toggleAssetPrice(
                    pair[0],
                    ((OrderDetails[requestId].maker_amounts[
                        OrderDetails[requestId].maker_amounts.length - 1
                    ] * (10 ** decimals)) /
                        OrderDetails[requestId].taker_amounts[
                            OrderDetails[requestId].taker_amounts.length - 1
                        ])
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
    ) private {
        uint256 balanceToAdd;
        uint256 MakerbalanceToAdd;
        for (uint256 i = 0; i < takers.length; i++) {
            (uint256 assets, , , , ) = Datahub.ReadUserData(takers[i], pair[0]);
            balanceToAdd = taker_amounts[i] > assets
                ? assets
                : taker_amounts[i];

            Datahub.addAssets(takers[i], pair[0], balanceToAdd);
            Datahub.removePendingBalances(takers[i], pair[0], balanceToAdd);
        }

        for (uint256 i = 0; i < makers.length; i++) {
            (uint256 assets, , , , ) = Datahub.ReadUserData(makers[i], pair[1]);
            MakerbalanceToAdd = maker_amounts[i] > assets
                ? assets
                : maker_amounts[i];

            Datahub.addAssets(makers[i], pair[1], MakerbalanceToAdd);
            Datahub.removePendingBalances(
                makers[i],
                pair[0],
                MakerbalanceToAdd
            );
        }
    }

    receive() external payable {}
}
