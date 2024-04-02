// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IDataHub.sol";
import "./interfaces/IDepositVault.sol";
import "./interfaces/IExecutor.sol";
import "@api3/airnode-protocol/contracts/rrp/requesters/RrpRequesterV0.sol";

contract Oracle is Ownable, RrpRequesterV0 {
    /** Data Hub + Deposit Vault  */

    IDataHub public Datahub;
    IExecutor public Executor;
    IDepositVault public DepositVault;

    address public USDT = address(0xaBAD60e4e01547E2975a96426399a5a0578223Cb);

    uint256 public lastOracleFufillTime;

    bytes32 public lastRequestId;

    error Error_FufillUnSuccessful(
        bytes32 requestid,
        uint256 timeStamp,
        bytes data
    );
    event Error(bytes32 requestid, uint256 timeStamp, bytes data);

    /** Constructor  */
    constructor(
        address initialOwner,
        address _DataHub,
        address _deposit_vault,
        address airnodeRrpAddress,
        address _executor
    ) Ownable(initialOwner) RrpRequesterV0(airnodeRrpAddress) {
        Datahub = IDataHub(_DataHub);
        DepositVault = IDepositVault(_deposit_vault);
        Executor = IExecutor(_executor);
    }

    /** Mapping's  */
    mapping(bytes32 => string) public queryParamMap;
    mapping(bytes32 => bool) public QueryApproval;
    mapping(bytes32 => bool) public incomingFulfillments;
    mapping(bytes32 => int256) public fulfilledData;

    modifier checkRoleAuthority() {
        require(msg.sender == address(Executor), "Nice Try Buster");
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
     //   bool[][2] trade_sides;
        uint256[] takerliabilityAmounts;
        uint256[] makerliabilityAmounts;
        string _id;
        // bool margin;
    }

    mapping(bytes32 => Order) public OrderDetails;

    /** event's  */
    event ValueUpdated(string result);
    event QueryCalled(string description, uint256 timestamp, bytes32 requestId);
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

    function alterAdminRoles(
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

    /// @notice Checks the Airnodes status, see dev notes for a link to the contract to see its return values
    /// @dev https://cardona-zkevm.polygonscan.com/address/0x9499a917cf8ca139c0e06f9728e1c6a0f7a1f5f2#code ( Line 1078 )
    /// @param requestId query lastRequestId on the contract and see if the last order was a success
    /// @return if the order queried returned success, fail, or null  --> if this returns true trades are open, if this returns false trading is closed.
    function checkAirnodeStatus(bytes32 requestId) public view returns (bool) {
        return airnodeRrp.requestIsAwaitingFulfillment(requestId);
    }

    function ProcessTrade(
        address[2] memory pair,
        address[][2] memory participants,
        uint256[][2] memory trade_amounts,
        //bool[][2] memory trade_side,
        uint256[] memory TakerliabilityAmounts,
        uint256[] memory MakerliabilityAmounts,
        address[3] memory airnode_details,
        bytes32 endpointId,
        bytes calldata parameters
    ) external checkRoleAuthority {
        freezeTempBalance(pair, participants, trade_amounts);//, trade_side

        bytes32 orderId = makeRequest(
            airnode_details[0],
            endpointId,
            airnode_details[1],
            airnode_details[2],
            parameters
        );

        OrderDetails[orderId].taker_token = pair[0];
        OrderDetails[orderId].maker_token = pair[1];
        OrderDetails[orderId].taker_amounts = trade_amounts[0];
        OrderDetails[orderId].maker_amounts = trade_amounts[1];
        //OrderDetails[orderId].trade_sides = trade_side;

        OrderDetails[orderId].takers = participants[0];
        OrderDetails[orderId].makers = participants[1];
        OrderDetails[orderId].takerliabilityAmounts = TakerliabilityAmounts;
        OrderDetails[orderId].makerliabilityAmounts = MakerliabilityAmounts;

        emit QueryCalled("Query sent,", block.timestamp, orderId);
    }

    function makeRequest(
        address airnode,
        bytes32 endpointId,
        address sponsor,
        address sponsorWallet,
        bytes calldata parameters
    ) internal returns (bytes32) {
        bytes32 requestId = airnodeRrp.makeFullRequest(
            airnode, // airnode address
            endpointId, // endpointId
            sponsor, // sponsor's address
            sponsorWallet, // sponsorWallet
            address(this), // fulfillAddress
            this.fulfill.selector, // fulfillFunctionId
            parameters // encoded API parameters
        );
        incomingFulfillments[requestId] = true;
        lastRequestId = requestId;

        return requestId;
    }

    /// @notice This simulates an airnode call to see if it is a success or fail
    /// @param pair the pair of tokens being traded
    /// @param participants of the trade 2 nested arrays
    /// @param trade_amounts the trades amounts for each participant
    function freezeTempBalance(
        address[2] memory pair,
        address[][2] memory participants,
        uint256[][2] memory trade_amounts
       // bool[][2] memory trade_side
    ) private {
        //(success, returnValue) = abi.decode(address(this).call(abi.encodeWithSignature("myFunction(uint256)", _newValue)), (bool, uint256));
        alterPending(participants[0], trade_amounts[0], pair[0]);// trade_side[0],
        alterPending(participants[1], trade_amounts[1], pair[1]);// trade_side[1],
    }

    /// @notice Processes a trade details
    /// @param  participants the participants on the trade
    /// @param  tradeAmounts the trade amounts in the trade
    /// @param  pair the token involved in the trade
    function alterPending(
        address[] memory participants,
        uint256[] memory tradeAmounts,
       // bool[] memory tradeside,
        address pair
    ) internal returns (bool) {
        for (uint256 i = 0; i < participants.length; i++) {
            (uint256 assets, , , , ) = Datahub.ReadUserData(
                participants[i],
                pair
            );
            /*
            // this is the amount out token for both fuckers
            if (tradeside[i] == true) {
                // taker --> don't take anything from amount out token for the makers
            } else {

            tradeAmounts[i] = (tradeAmounts[i] * Datahub.tradeFee(pair, 1))/ 10**18 ;

            }
            */
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
       // Datahub.addPendingBalances(participant, asset, trade_amount);
    }

    /// The AirnodeRrpV0.sol protocol contract will callback here.
    function fulfill(
        bytes32 requestId,
        bytes calldata data
    ) external onlyAirnodeRrp {
        require(incomingFulfillments[requestId], "No such request made");
        delete incomingFulfillments[requestId];
        lastOracleFufillTime = block.timestamp;
        int256 decodedData = abi.decode(data, (int256));
        fulfilledData[requestId] = decodedData;
        if (decodedData != 1) {

            /*
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
*/
            emit Error(requestId, block.timestamp, data); //
        } else {
            address[2] memory pair;
            pair[0] = OrderDetails[requestId].taker_token;
            pair[1] = OrderDetails[requestId].maker_token;

            Executor.TransferBalances(
                pair,
              //  OrderDetails[requestId].trade_sides,
                OrderDetails[requestId].takers,
                OrderDetails[requestId].makers,
                OrderDetails[requestId].taker_amounts,
                OrderDetails[requestId].maker_amounts,
                OrderDetails[requestId].takerliabilityAmounts,
                OrderDetails[requestId].makerliabilityAmounts
            );

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
