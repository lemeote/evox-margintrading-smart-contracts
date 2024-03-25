// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IDataHub.sol";
import "./interfaces/IDepositVault.sol";
import "./interfaces/IExecutor.sol";

contract Oracle is Ownable {
    /** Data Hub + Deposit Vault  */

    IDataHub public Datahub;
    IExecutor public Executor;
    IDepositVault public DepositVault;

    bytes32 private lastRequestId;

    error Error_FufillUnSuccessful(bytes32 requestid, uint256 timeStamp);

    address public USDT = address(0xdfc6a3f2d7daff1626Ba6c32B79bEE1e1d6259F0);

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
        waitPeriod = 10000;
    }

    /** Mapping's  */
    mapping(bytes32 => string) public queryParamMap;
    mapping(uint256 => bool) public QueryApproval;
    mapping(bytes32 => bool) public incomingFulfillments;
    mapping(bytes32 => int256) public fulfilledData;

    modifier checkRoleAuthority() {
        require(msg.sender == address(Executor), "Nice Try Buster");
        _;
    }

    /** Struct's  */
    struct Order {
        bool fee_side;
        address taker_token;
        address maker_token;
        address[] takers;
        address[] makers;
        uint256[] taker_amounts;
        uint256[] maker_amounts;
        uint256[] makerliabilityAmounts;
        uint256[] takerliabilityAmounts;
        string _id;
        // bool margin;
    }

    mapping(bytes32 => Order) public OrderDetails;
    mapping(uint256 => bytes32) public TimeOfRequest;

    uint256 lastOracleRequestTime;
    uint256 waitPeriod;

    /** event's  */
    event ValueUpdated(string result);
    event QueryCalled(string description);
    event TradeExecuted(uint256 blocktimestamp);
    event OutOfGasFunds(uint256 blocktimestamp);

    event TradeReverted(
        bytes32 requestId,
        address taker_token,
        address maker_token,
        address[] takers,
        address[] makers,
        uint256[] taker_amounts,
        uint256[] maker_amounts
    );

    event RequestCalled(
        bytes32 requestId,
        address taker_token,
        address maker_token,
        address[] takers,
        address[] makers,
        uint256[] taker_amounts,
        uint256[] maker_amounts
    );

    function AlterAdminRoles(
        address _deposit_vault,
        address _executor,
        address _DataHub
    ) public onlyOwner {
        Datahub = IDataHub(_DataHub);
        DepositVault = IDepositVault(_deposit_vault);
        Executor = IExecutor(_executor);
    }

    function AlterExecutor(address _new_executor) public onlyOwner {
        Executor = IExecutor(_new_executor);
    }

    // function mock tx? if no just set balances back

    function ProcessTrade(
        bool feeSide,
        address[2] memory pair,
        address[][2] memory participants,
        uint256[][2] memory trade_amounts,
        uint256[] memory TakerliabilityAmounts,
        uint256[] memory MakerliabilityAmounts
    )
        external
        // address[3] memory airnode_details,
        // bytes32 endpointId,
        // bytes calldata parameters
        checkRoleAuthority
    {
        bytes32 orderId = bytes32(
            uint256(2636288841321219110873651998422106944)
        ); 
        
        OrderDetails[orderId].fee_side = feeSide;
        OrderDetails[orderId].taker_token = pair[0];
        OrderDetails[orderId].maker_token = pair[1];
        OrderDetails[orderId].taker_amounts = trade_amounts[0];
        OrderDetails[orderId].maker_amounts = trade_amounts[1];

        OrderDetails[orderId].takers = participants[0];
        OrderDetails[orderId].makers = participants[1];
        OrderDetails[orderId].takerliabilityAmounts = TakerliabilityAmounts;
        OrderDetails[orderId].makerliabilityAmounts = MakerliabilityAmounts;

        makeRequest(orderId, pair, participants, trade_amounts);

        emit QueryCalled("Query sent, please wait");
    }

    /// @notice This simulates an airnode call to see if it is a success or fail
    /// @param pair the pair of tokens being traded
    /// @param participants of the trade 2 nested arrays
    /// @param trade_amounts the trades amounts for each participant
    function freezeTempBalance(
        address[2] memory pair,
        address[][2] memory participants,
        uint256[][2] memory trade_amounts
    ) private {
        //(success, returnValue) = abi.decode(address(this).call(abi.encodeWithSignature("myFunction(uint256)", _newValue)), (bool, uint256));
       alterPending(
            participants[0],
            trade_amounts[0],
            pair[0]
        );
         alterPending(
            participants[1],
            trade_amounts[1],
            pair[1]
        );
    }

    /// @notice Processes a trade details
    /// @param  participants the participants on the trade
    /// @param  tradeAmounts the trade amounts in the trade
    /// @param  pair the token involved in the trade
    function alterPending(
        address[] memory participants,
        uint256[] memory tradeAmounts,
        address pair
    ) internal returns (bool) {
        for (uint256 i = 0; i < participants.length; i++) {
            (uint256 assets, , , , ) = Datahub.ReadUserData(
                participants[i],
                pair
            );
            AlterPendingBalances(
                participants[i],
                pair,
                tradeAmounts[i] > assets ? assets : tradeAmounts[i]
            );
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
      //  Datahub.addPendingBalances(participant, asset, trade_amount);
    }

    function makeRequest(
        bytes32 requestId,
        address[2] memory pair,
        address[][2] memory participants,
        uint256[][2] memory trade_amounts
    ) internal returns (uint) {
      
        freezeTempBalance(pair, participants, trade_amounts);
      
        requestId = bytes32(uint256(2636288841321219110873651998422106944));

        fulfill(requestId);

        return 1;
    }

    /// The AirnodeRrpV0.sol protocol contract will callback here.
    function fulfill(bytes32 requestId) internal {
        if (
            requestId != bytes32(uint256(2636288841321219110873651998422106944))
        ) {
            address[2] memory pair;
            pair[0] = OrderDetails[requestId].taker_token;
            pair[1] = OrderDetails[requestId].maker_token;

            Executor.revertTrade(
                pair,
                OrderDetails[requestId].takers,
                OrderDetails[requestId].makers,
                OrderDetails[requestId].taker_amounts,
                OrderDetails[requestId].maker_amounts
            );
            revert Error_FufillUnSuccessful(requestId, block.timestamp); //
        } else {
            address[2] memory pair;
            pair[0] = OrderDetails[requestId].taker_token;
            pair[1] = OrderDetails[requestId].maker_token;

            Executor.TransferBalances(
                OrderDetails[requestId].fee_side,
                pair,
                OrderDetails[requestId].takers,
                OrderDetails[requestId].makers,
                OrderDetails[requestId].taker_amounts,
                OrderDetails[requestId].maker_amounts,
                OrderDetails[requestId].takerliabilityAmounts,
                OrderDetails[requestId].makerliabilityAmounts
            );

            // The reason why we update price AFTER we make the call to the executor is because if it fails, the prices wont update
            // and the update prices wll not be included in the  TX
            if (pair[0] == USDT) {
                Datahub.toggleAssetPrice(
                    pair[1],
                    ((OrderDetails[requestId].taker_amounts[
                        OrderDetails[requestId].taker_amounts.length - 1
                    ] * (10 ** DepositVault.fetchDecimals(pair[1]))) /
                        OrderDetails[requestId].maker_amounts[
                            OrderDetails[requestId].maker_amounts.length - 1
                        ])
                );
            } else {
                Datahub.toggleAssetPrice(
                    pair[0],
                    ((OrderDetails[requestId].maker_amounts[
                        OrderDetails[requestId].maker_amounts.length - 1
                    ] * (10 ** DepositVault.fetchDecimals(pair[0]))) /
                        OrderDetails[requestId].taker_amounts[
                            OrderDetails[requestId].taker_amounts.length - 1
                        ])
                );
            }
        }
    }

    receive() external payable {}
}
