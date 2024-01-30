// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./libraries/REX_LIBRARY.sol";
import "./interfaces/IDataHub.sol";
import "hardhat/console.sol";
contract DataHub is Ownable {
    modifier checkRoleAuthority() {
        require(
            msg.sender == owner() ||
                msg.sender == deposit_vault ||
                msg.sender == executor || msg.sender == oracle,
            "Unauthorized"
        );
        _;
    }

    constructor(address initialOwner, address _executor, address _deposit_vault, address _oracle)  Ownable(initialOwner) {
        executor = _executor;
        deposit_vault = _deposit_vault;
        oracle = _oracle;
 

    }

  
    address public executor;
    address public deposit_vault;
    address public oracle;

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

    uint256 private MAX_INT = type(uint256).max;

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
        address token,
        uint256 amount
    ) external checkRoleAuthority {
        userdata[user].maintenance_margin_requirement[token] *= amount;
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
        address token,
        uint256 amount
    ) external checkRoleAuthority {
        userdata[user].maintenance_margin_requirement[token] += amount;
    }

    function removeMaintenanceMarginRequirement(
        address user,
        address token,
        uint256 amount
    ) external checkRoleAuthority {
        userdata[user].maintenance_margin_requirement[token] -= amount;
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


    function returnMMROfUser(address user, address token) external view returns(uint256){
        uint256 mmr = userdata[user].maintenance_margin_requirement[token];
        return mmr;
    }

    function removeAssetToken(address user) external checkRoleAuthority {
        IDataHub.UserData storage userData = userdata[user];

        for (uint256 i = 0; i < userData.tokens.length; i++) {
            address token = userData.tokens[i];
            if (userData.tokens[i] == token) {
                userData.tokens[i] = userData.tokens[
                    userData.tokens.length - 1
                ];
                userData.tokens.pop();
                break; // Exit the loop once the token is found and removed
            }
        }
    }


    function returnUsersAssetTokens(address user) external view returns(address[] memory){
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

    function ReadUserData(
        address user,
        address token
    )
        external
        view
        returns (uint256, uint256, uint256, uint256, bool, address[] memory)
    {
        uint256 assets = userdata[user].asset_info[token]; // tracks their portfolio (margined, and depositted)
        uint256 liabilities = userdata[user].liability_info[token];
        uint256 mmr = userdata[user].maintenance_margin_requirement[token];
        uint256 pending = userdata[user].pending_balances[token];
        bool margined = userdata[user].margined;
        address[] memory tokens = userdata[user].tokens;
        return (assets, liabilities, mmr, pending, margined, tokens);
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
        uint256 value
    ) external checkRoleAuthority {
        assetdata[token].interestRate = value;
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
        uint256 maximumBorrowProportion,
        uint256 interestRate,
        uint256[] memory interestRateInfo
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
            totalDepositors: 0,
            interestRate: interestRate,
            interestRateInfo: interestRateInfo
        });
    
            assetInitialized[token] = true;
        
    }


    function toggleInterestRates(
        address token,
        uint256 optimalBorrowProportion,
        uint256 maximumBorrowProportion,
        uint256[] memory interestRateInfo
    ) public onlyOwner {
        assetdata[token].optimalBorrowProportion = optimalBorrowProportion;
        assetdata[token].maximumBorrowProportion = maximumBorrowProportion;
        assetdata[token].interestRateInfo[0] = interestRateInfo[0];
        assetdata[token].interestRateInfo[1] = interestRateInfo[1];
        assetdata[token].interestRateInfo[2] = interestRateInfo[2];
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


    function changeMarginStatus(address user) external checkRoleAuthority  returns (bool) {
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
                userdata[user].asset_info[token]) / 10**18;  // want to get like a whole normal number so balance and price correction
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
                userdata[user].liability_info[token]) / 10**18;// want to get like a whole normal number so balance and price correction
        }
        return sumOfliabilities;
    }

    function calculateTotalPortfolioValue(
        address user
    ) external view returns (uint256) {
        return calculateTotalAssetValue(user) - calculateLiabilitiesValue(user);
    }


    function calculateAMMRForUser(address user) external view returns (uint256) {
        uint256 AMMRValue;

        for (uint256 i = 0; i < userdata[user].tokens.length; i++) {
            address token = userdata[user].tokens[i];

            // here we use the function calculateMaintenanceRequirementForTrade to return the MMR of the users individual positions
            if (userdata[user].liability_info[token] > 0) {
                AMMRValue +=
                    ((REX_LIBRARY.calculateMaintenanceRequirementForTrade(
                        assetdata[token],
                        userdata[user].liability_info[token]
                    ) *
                    assetdata[token].assetPrice) / 10 **18);
            }
        }
        return AMMRValue;
    }
    receive() external payable {}
}
