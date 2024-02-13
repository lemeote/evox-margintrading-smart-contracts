// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

interface IDataHub {
    struct UserData {
        mapping(address => uint256) asset_info; // tracks their portfolio (margined, and depositted)
        mapping(address => uint256) liability_info; // tracks what they owe per token * price
        mapping(address => mapping(address => uint256)) maintenance_margin_requirement; // tracks the MMR per token the user has in liabilities
        mapping(address => uint256) pending_balances;
        mapping(address => uint256) interestRateIndex;
        bool margined; // if user has open margin positions this is true
        address[] tokens; // these are the tokens that comprise their portfolio ( assets, and liabilites, margined funds)
    }

    //= [P (1 + i)n] – P
    // (liabilities * ( 1+ average_interest rate in the periods) ^ number of periods) - liabilities.
    // boom jackpot

    struct AssetData {
        uint256 initialMarginFee; // assigned in function Ex
        // inital margin fee -> add and charge on insuance of libilities -> goes to TINO + CONNER + WAKAKKIIIIII and maybe some to dao
        uint256 assetPrice;
        uint256 liquidationFee;
        uint256 initialMarginRequirement; // not for potantial removal - unnessecary
        uint256 MaintenanceMarginRequirement;
        uint256 totalAssetSupply;
        uint256 totalBorrowedAmount;
        uint256 optimalBorrowProportion; // need to brainsotrm on how to set this information
        uint256 maximumBorrowProportion; // we need an on the fly function for the current maximum borrowable AMOUNT  -- cant borrow the max available supply
        uint256 totalDepositors;
    }

    function addAssets(address user, address token, uint256 amount) external;

    function removeAssets(address user, address token, uint256 amount) external;

    function alterAssets(address user, address token, uint256 amount) external;

    function alterUsersInterestRateIndex(address user) external;

    function viewUsersInterestRateIndex(
        address user
    ) external view returns (uint256);

    function alterLiabilities(
        address user,
        address token,
        uint256 amount
    ) external;

    function alterMMR(
        address user,
        address in_token,
        address out_token,
        uint256 amount
    ) external;

    function addLiabilities(
        address user,
        address token,
        uint256 amount
    ) external;

    function removeLiabilities(
        address user,
        address token,
        uint256 amount
    ) external;

    function addMaintenanceMarginRequirement(
        address user,
        address in_token,
        address out_token,
        uint256 amount
    ) external;

    function removeMaintenanceMarginRequirement(
        address user,
        address in_token,
        address out_token,
        uint256 amount
    ) external;

    function addPendingBalances(
        address user,
        address token,
        uint256 amount
    ) external;

    function removePendingBalances(
        address user,
        address token,
        uint256 amount
    ) external;

    function SetMarginStatus(address user, bool onOrOff) external;

    function checkIfAssetIsPresent(
        address[] memory users,
        address token
    ) external returns (bool);

    function ReadUserData(
        address user,
        address token
    ) external view returns (uint256, uint256, uint256, bool, address[] memory);

    function removeAssetToken(address user, address token) external;

    function settotalAssetSupply(
        address token,
        uint256 amount,
        bool pos_neg
    ) external;

    function toggleInterestRate(address token, uint256 value) external;

    function returnAssetLogs(
        address token
    ) external view returns (AssetData memory);

    function FetchAssetInitilizationStatus(
        address token
    ) external view returns (bool);

    function setTotalBorrowedAmount(
        address token,
        uint256 amount,
        bool pos_neg
    ) external;

    function toggleAssetPrice(address token, uint256 value) external;

    function checkMarginStatus(
        address user,
        address token,
        uint256 BalanceToLeave
    ) external;

    function returnMaintenanceRequirementForTrade(
        address token,
        uint256 amount
    ) external view returns (uint256);

    function calculateMarginRequirement(
        address user,
        address token,
        uint256 BalanceToLeave,
        uint256 userAssets
    ) external view returns (bool);

    function calculateAMMRForUser(address user) external view returns (uint256);

    function calculateTotalPortfolioValue(
        address user
    ) external view returns (uint256);

    function changeMarginStatus(address user) external returns (bool);

    function returnUsersAssetTokens(
        address user
    ) external view returns (address[] memory);

    function returnPairMMROfUser(
        address user,
        address in_token,
        address out_token
    ) external view returns (uint256);
}
