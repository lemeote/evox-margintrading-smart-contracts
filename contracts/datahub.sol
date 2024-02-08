// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IDataHub.sol";
import "hardhat/console.sol";

contract DataHub is Ownable {
    modifier checkRoleAuthority() {
        require(
            msg.sender == owner() ||
                msg.sender == deposit_vault ||
                msg.sender == executor ||
                msg.sender == oracle,
            "Unauthorized"
        );
        _;
    }

    constructor(
        address initialOwner,
        address _executor,
        address _deposit_vault,
        address _oracle
    ) Ownable(initialOwner) {
        executor = _executor;
        deposit_vault = _deposit_vault;
        oracle = _oracle;
    }

    address public executor;
    address public deposit_vault;
    address public oracle;

    uint256 public CurrentRateIndex;

    function AlterAdminRoles(
        address _deposit_vault,
        address _executor,
        address _oracle
    ) public onlyOwner {
        executor = _executor;
        deposit_vault = _deposit_vault;
        oracle = _oracle;
    }

    mapping(address => bool) public assetInitialized;

    mapping(address => IDataHub.UserData) public userdata;

    mapping(address => IDataHub.AssetData) public assetdata;

    mapping(address => mapping(uint256 => IDataHub.interestDetails)) interestInfo;

    uint256 private MAX_INT = type(uint256).max;

    function fetchRates(
        address token,
        uint256 index
    ) external view returns (IDataHub.interestDetails memory) {
        return interestInfo[token][index];
    }

    function fetchCurrentRateIndex() external view returns (uint256) {
        return CurrentRateIndex;
    }

    function alterUsersInterestRateIndex(
        address user
    ) external checkRoleAuthority {
        userdata[user].interestRateIndex = CurrentRateIndex;
    }

    function viewUsersInterestRateIndex(
        address user
    ) external view returns (uint256) {
        return userdata[user].interestRateIndex;
    }

    function addAssets(
        address user,
        address token,
        uint256 amount
    ) external checkRoleAuthority {
        userdata[user].asset_info[token] += amount;
    }

    function removeAssets(
        address user,
        address token,
        uint256 amount
    ) external checkRoleAuthority {
        userdata[user].asset_info[token] -= amount;
    }

    function alterAssets(
        address user,
        address token,
        uint256 amount
    ) external checkRoleAuthority {
        userdata[user].asset_info[token] *= amount;
    }

    function alterMMR(
        address user,
        address in_token,
        address out_token,
        uint256 amount
    ) external checkRoleAuthority {
        userdata[user].maintenance_margin_requirement[in_token][
            out_token
        ] *= amount;
    }

    function alterLiabilities(
        address user,
        address token,
        uint256 amount
    ) external checkRoleAuthority {
        userdata[user].liability_info[token] *= amount;
    }

    function addLiabilities(
        address user,
        address token,
        uint256 amount
    ) external checkRoleAuthority {
        userdata[user].liability_info[token] += amount;
    }

    function removeLiabilities(
        address user,
        address token,
        uint256 amount
    ) external checkRoleAuthority {
        userdata[user].liability_info[token] -= amount;
    }

    function addMaintenanceMarginRequirement(
        address user,
        address in_token,
        address out_token,
        uint256 amount
    ) external checkRoleAuthority {
        userdata[user].maintenance_margin_requirement[in_token][
            out_token
        ] += amount;
    }

    function removeMaintenanceMarginRequirement(
        address user,
        address in_token,
        address out_token,
        uint256 amount
    ) external checkRoleAuthority {
        userdata[user].maintenance_margin_requirement[in_token][
            out_token
        ] -= amount;
    }

    function addPendingBalances(
        address user,
        address token,
        uint256 amount
    ) external checkRoleAuthority {
        userdata[user].pending_balances[token] += amount;
    }

    function removePendingBalances(
        address user,
        address token,
        uint256 amount
    ) external checkRoleAuthority {
        userdata[user].pending_balances[token] -= amount;
    }

    function SetMarginStatus(
        address user,
        bool onOrOff
    ) external checkRoleAuthority {
        userdata[user].margined = onOrOff;
    }

    function removeAssetToken(
        address user,
        address tokenToRemove
    ) external checkRoleAuthority {
        IDataHub.UserData storage userData = userdata[user];

        for (uint256 i = 0; i < userData.tokens.length; i++) {
            address token = userData.tokens[i];
            if (token == tokenToRemove) {
                userData.tokens[i] = userData.tokens[
                    userData.tokens.length - 1
                ];
                userData.tokens.pop();
                break; // Exit the loop once the token is found and removed
            }
        }
    }

    function returnUsersAssetTokens(
        address user
    ) external view returns (address[] memory) {
        IDataHub.UserData storage userData = userdata[user];
        return userData.tokens;
    }

    function checkIfAssetIsPresent(
        address[] memory users,
        address token
    ) external checkRoleAuthority returns (bool) {
        bool tokenFound = false;

        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];

            for (uint256 j = 0; j < userdata[user].tokens.length; j++) {
                if (userdata[user].tokens[j] == token) {
                    // Token found in the array
                    tokenFound = true;
                    break; // Exit the inner loop as soon as the token is found
                }
            }

            if (!tokenFound) {
                // Token not found for the current user, add it to the array
                userdata[user].tokens.push(token);
            }
        }

        // Return true if the token is found for at least one user
        return tokenFound;
    }

    function FetchAssetInitilizationStatus(
        address token
    ) external view returns (bool) {
        return assetInitialized[token];
    }

    function returnPairMMROfUser(
        address user,
        address in_token,
        address out_token
    ) external view returns (uint256) {
        uint256 mmr = userdata[user].maintenance_margin_requirement[in_token][
            out_token
        ];
        return mmr;
    }

    function ReadUserData(
        address user,
        address token
    )
        external
        view
        returns (uint256, uint256, uint256, bool, address[] memory)
    {
        uint256 assets = userdata[user].asset_info[token]; // tracks their portfolio (margined, and depositted)
        uint256 liabilities = userdata[user].liability_info[token];
        uint256 pending = userdata[user].pending_balances[token];
        bool margined = userdata[user].margined;
        address[] memory tokens = userdata[user].tokens;
        return (assets, liabilities, pending, margined, tokens);
    }

    function settotalAssetSupply(
        address token,
        uint256 amount,
        bool pos_neg
    ) external checkRoleAuthority {
        if (pos_neg == true) {
            assetdata[token].totalAssetSupply += amount;
        } else {
            assetdata[token].totalAssetSupply -= amount;
        }
    }

    function setTotalBorrowedAmount(
        address token,
        uint256 amount,
        bool pos_neg
    ) external checkRoleAuthority {
        if (pos_neg == true) {
            assetdata[token].totalBorrowedAmount += amount;
        } else {
            assetdata[token].totalBorrowedAmount -= amount;
        }
    }

    function toggleInterestRate(
        address token,
        uint256 index,
        uint256 value
    ) external checkRoleAuthority {

        interestInfo[token][index].interestRate = value;
        // assetdata[token].interestRate = value;
    }

    function initInterest(address token, uint256 index, uint256[] memory rateInfo, uint256 interestRate ) external checkRoleAuthority{
        interestInfo[token][index].lastUpdatedTime = block.timestamp;
        interestInfo[token][index].rateInfo = rateInfo;
        interestInfo[token][index].interestRate = interestRate;
    }

    function toggleAssetPrice(
        address token,
        uint256 value
    ) external checkRoleAuthority {
        assetdata[token].assetPrice = value;
    }

    /* INITILIZATION FUNCTIONS */

    function InitTokenMarket(
        address token,
        uint256 assetPrice,
        uint256 initialMarginFee,
        uint256 liquidationFee,
        uint256 initialMarginRequirement,
        uint256 MaintenanceMarginRequirement,
        uint256 optimalBorrowProportion,
        uint256 maximumBorrowProportion
    ) external onlyOwner {
        require(!assetInitialized[token]);

        assetdata[token] = IDataHub.AssetData({
            initialMarginFee: initialMarginFee,
            assetPrice: assetPrice,
            liquidationFee: liquidationFee,
            initialMarginRequirement: initialMarginRequirement,
            MaintenanceMarginRequirement: MaintenanceMarginRequirement,
            totalAssetSupply: 0,
            totalBorrowedAmount: 0,
            optimalBorrowProportion: optimalBorrowProportion,
            maximumBorrowProportion: maximumBorrowProportion,
            totalDepositors: 0
        });

        assetInitialized[token] = true;
    }

 
    function returnAssetLogs(
        address token
    ) external view returns (IDataHub.AssetData memory) {
        return assetdata[token];
    }

    function checkMarginStatus(
        address user,
        address token,
        uint256 BalanceToLeave
    ) external checkRoleAuthority {
        uint256 AssetBalance = userdata[user].asset_info[token];
        //  - userdata[user].pending_balances[token];
        if (userdata[user].margined == false) {
            if (AssetBalance < BalanceToLeave) {
                userdata[user].margined = true;
            }
            return;
        }
        return;
    }

    function changeMarginStatus(
        address user
    ) external checkRoleAuthority returns (bool) {
        bool isMargined = false;
        for (uint256 j = 0; j < userdata[user].tokens.length; j++) {
            if (userdata[user].liability_info[userdata[user].tokens[j]] > 0) {
                // Token found in the array
                isMargined = true;
                break;
            }
        }

        userdata[user].margined = isMargined;
        return isMargined;
    }

    function calculateTotalAssetValue(
        address user
    ) public view returns (uint256) {
        uint256 sumOfAssets;
        for (uint256 i = 0; i < userdata[user].tokens.length; i++) {
            address token = userdata[user].tokens[i];
            sumOfAssets +=
                (assetdata[token].assetPrice *
                    userdata[user].asset_info[token]) /
                10 ** 18; // want to get like a whole normal number so balance and price correction
        }
        return sumOfAssets;
    }

    function calculateLiabilitiesValue(
        address user
    ) public view returns (uint256) {
        uint256 sumOfliabilities;
        for (uint256 i = 0; i < userdata[user].tokens.length; i++) {
            address token = userdata[user].tokens[i];
            sumOfliabilities +=
                (assetdata[token].assetPrice *
                    userdata[user].liability_info[token]) /
                10 ** 18; // want to get like a whole normal number so balance and price correction
        }
        return sumOfliabilities;
    }

    // add pending balances in here?
    function calculateTotalPortfolioValue(
        address user
    ) external view returns (uint256) {
        return calculateTotalAssetValue(user) - calculateLiabilitiesValue(user);
    }

    function calculateAMMRForUser(
        address user
    ) external view returns (uint256) {
        uint256 AMMR;
        for (uint256 i = 0; i < userdata[user].tokens.length; i++) {
            address token = userdata[user].tokens[i];
            uint256 liabilities = userdata[user].liability_info[token];
            if (liabilities > 0) {
                for (uint256 j = 0; j < userdata[user].tokens.length; j++) {
                    address token_2 = userdata[user].tokens[j];
                    if (
                        userdata[user].maintenance_margin_requirement[token][
                            token_2
                        ] > 0
                    ) {
                        console.log(token);
                        console.log(token_2);
                        console.log(assetdata[token].assetPrice);
                        AMMR +=
                            (assetdata[token].assetPrice *
                                userdata[user].maintenance_margin_requirement[
                                    token
                                ][token_2]) /
                            10 ** 18;
                    }
                }
            }
        }
        return AMMR;
    }

    receive() external payable {}
}
