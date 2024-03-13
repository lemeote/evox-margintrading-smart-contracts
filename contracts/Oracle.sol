// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IDataHub.sol";
import "./interfaces/IDepositVault.sol";
import "./interfaces/IExecutor.sol";

contract Oracle is Ownable  {
    /** Data Hub + Deposit Vault  */

    IDataHub public Datahub;
    IExecutor public Executor;
    IDepositVault public DepositVault;

    address public USDT = address(0xdfc6a3f2d7daff1626Ba6c32B79bEE1e1d6259F0);

    /** Constructor  */
    constructor(
         address initialOwner,
        address _DataHub,
        address _deposit_vault,
        address _executor
    ) Ownable(initialOwner)  {
        Datahub = IDataHub(_DataHub);
        DepositVault = IDepositVault(_deposit_vault);
        Executor = IExecutor(_executor);
    }

    /** Mapping's  */
    mapping(bytes32 => string) public queryParamMap;
    mapping(uint256=> bool) public QueryApproval;
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
        uint256[] makerliabilityAmounts;
        uint256[] takerliabilityAmounts;
        string _id;
        // bool margin;
    }

    mapping(uint256 => Order) public OrderDetails;

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
        address[2] memory pair,
        address[][2] memory participants,
        uint256[][2] memory trade_amounts,
        uint256[] memory TakerliabilityAmounts,
        uint256[] memory MakerliabilityAmounts
       // address[3] memory airnode_details,
       // bytes32 endpointId,
       // bytes calldata parameters
    ) external checkRoleAuthority {

        uint256 orderId = 1;

        OrderDetails[orderId].taker_token = pair[0];
        OrderDetails[orderId].maker_token = pair[1];
        OrderDetails[orderId].taker_amounts = trade_amounts[0];
        OrderDetails[orderId].maker_amounts = trade_amounts[1];

        OrderDetails[orderId].takers = participants[0];
        OrderDetails[orderId].makers = participants[1];
        OrderDetails[orderId].takerliabilityAmounts = TakerliabilityAmounts;
        OrderDetails[orderId].makerliabilityAmounts = MakerliabilityAmounts;


        fulfill(orderId);


        emit QueryCalled("Query sent, please wait");
    }
 

    /// The AirnodeRrpV0.sol protocol contract will callback here.
    function fulfill(
        uint256 requestId
    ) internal  {
        if (requestId == 1) {
            address[2] memory pair;
            pair[0] = OrderDetails[requestId].taker_token;
            pair[1] = OrderDetails[requestId].maker_token;
   
            /// call static -> spoof airnode address  -> in process trade

            // if this reverts then revert
            Executor.TransferBalances(
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
     }else{
        QueryApproval[requestId] = false;
     }
    }


    receive() external payable {}
}
