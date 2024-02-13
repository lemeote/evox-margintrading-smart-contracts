// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IDataHub.sol";
import "hardhat/console.sol";
import "./interfaces/IinterestData.sol";

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

    IInterestData interestContract; 


    function AlterAdminRoles(
        address _deposit_vault,
        address _executor,
        address _oracle,
        address _interest
    ) public onlyOwner {
        executor = _executor;
        deposit_vault = _deposit_vault;
        oracle = _oracle;
        interestContract = IInterestData(_interest);
    }
/// @notice checks to see if the asset has been initilized 
/// @dev once an asset is tradeable this is true
    mapping(address => bool) public assetInitialized;

/// @notice Keeps track of a users data
/// @dev Go to IDatahub for more details 
    mapping(address => IDataHub.UserData) public userdata;

/// @notice Keeps track of an assets data
/// @dev Go to IDatahub for more details 
    mapping(address => IDataHub.AssetData) public assetdata;

    uint256 private MAX_INT = type(uint256).max;



/// @notice Alters the users interest rate index (or epoch)
/// @dev This is to change the users rate epoch, it would be changed after they pay interest.
/// @param user the users address
/// @param token the token being targetted
        function alterUsersInterestRateIndex(
        address user,
        address token
    ) external checkRoleAuthority {
        userdata[user].interestRateIndex[token] = interestContract.fetchCurrentRateIndex(
        token
    );
    }
/// @notice provides to the caller the users current rate epoch
/// @dev This is to keep track of the last epoch the user paid at 
/// @param user the users address
/// @param token the token being targetted
    function viewUsersInterestRateIndex(
        address user,
        address token
    ) external view returns (uint256) {
        return userdata[user].interestRateIndex[token];
    }

  /// -----------------------------------------------------------------------
  /// Assets
  /// -----------------------------------------------------------------------


/// @notice This adds to the users assets 
/// @dev this function is to add to the users assets of a token
/// @param user the users address
/// @param token the token being targetted
/// @param amount the amount to be added to their balance
    function addAssets(
        address user,
        address token,
        uint256 amount
    ) external checkRoleAuthority {
        userdata[user].asset_info[token] += amount;
    }
/// @notice This removes balance from the users assets 
/// @dev this function is to remove assets from the users assets of a token
/// @param user the users address
/// @param token the token being targetted
/// @param amount the amount to be removed to their balance
    function removeAssets(
        address user,
        address token,
        uint256 amount
    ) external checkRoleAuthority {
        userdata[user].asset_info[token] -= amount;
    }


  /// -----------------------------------------------------------------------
  /// Maintenance Margin Requirement
  /// -----------------------------------------------------------------------


/// @notice This alters a users maintenance margin requirement of a given asset pair
/// @param user the users address
/// @param in_token the base token being targetted
/// @param out_token the other token of the pair being targetted
/// @param amount the amount to multiply their MMR by
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
/// @notice This adds to  a users maintenance margin requirement of a given asset pair
/// @param user the users address
/// @param in_token the base token being targetted
/// @param out_token the other token of the pair being targetted
/// @param amount the amount to add to their MMR
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
/// @notice This removes maintenance margin requirement of a given asset pair
/// @param user the users address
/// @param in_token the base token being targetted
/// @param out_token the other token of the pair being targetted
/// @param amount the amount to remove from MMR 
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

/// @notice This returns the users current MMR
/// @param user the users address
/// @param in_token the base token being targetted
/// @param out_token the other token of the pair being targetted
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

  /// -----------------------------------------------------------------------
  /// Liabilities
  /// -----------------------------------------------------------------------

/// @notice Alters a users liabilities 
/// @param user being targetted 
/// @param token being targetted
/// @param amount to alter liabilities by 
    function alterLiabilities(
        address user,
        address token,
        uint256 amount
    ) external checkRoleAuthority {
        userdata[user].liability_info[token] *= amount;
    }
/// @notice Adds to a users liabilities 
/// @param user being targetted 
/// @param token being targetted
/// @param amount to alter liabilities by 
    function addLiabilities(
        address user,
        address token,
        uint256 amount
    ) external checkRoleAuthority {
        userdata[user].liability_info[token] += amount;
    }
/// @notice removes a users liabilities 
/// @param user being targetted 
/// @param token being targetted
/// @param amount to alter liabilities by 
    function removeLiabilities(
        address user,
        address token,
        uint256 amount
    ) external checkRoleAuthority {
        userdata[user].liability_info[token] -= amount;
    }

  /// -----------------------------------------------------------------------
  /// Pending Balances --> when a trade is being executed the balance of the trade is moved to pending
  /// -----------------------------------------------------------------------


/// @notice This adds a pending balance for the user on a token they are trading
/// @dev We do this because when the oracle is called there is a gap in time where the user should not have assets because the trade is not finalized
/// @param user being targetted 
/// @param token being targetted
/// @param amount to add to pending balances
    function addPendingBalances(
        address user,
        address token,
        uint256 amount
    ) external checkRoleAuthority {
        userdata[user].pending_balances[token] += amount;
    }
/// @notice This removes a pending balance for the user on a token they are trading
/// @dev We do this when the trade is cleared by the oracle and the trade is executed. 
/// @param user being targetted 
/// @param token being targetted
/// @param amount to remove from pending balances
    function removePendingBalances(
        address user,
        address token,
        uint256 amount
    ) external checkRoleAuthority {
        userdata[user].pending_balances[token] -= amount;
    }



  /// -----------------------------------------------------------------------
  /// Margin modifiers.
  /// -----------------------------------------------------------------------

/// @notice This sets the users margin status 
/// @dev if the user does a margined trade we want to record them on the contract as having margin already
/// @param user user address being targetted 
/// @param onOrOff this determines whether they are being turned as having margin or not 
    function SetMarginStatus(
        address user,
        bool onOrOff
    ) external checkRoleAuthority {
        userdata[user].margined = onOrOff;
    }
/// @notice This checks the users margin status and if they should be in that status state, and changes it if they should not be
/// @param user the user being targetted
/// @param token the token being traded or targetted
/// @param BalanceToLeave the balance leaving their account
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
/// @notice This changes the users margin status 
/// @dev if they don't have any margined positions this should turn them into a "spot" user
/// @param user the user being targetted
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

  /// -----------------------------------------------------------------------
  /// Portfolio make-up  --> when a user has assets they are added to an array these function return or change that array
  /// -----------------------------------------------------------------------


/// @notice This function removes an asset from a users portfolio 
/// @dev it removes a token address from their tokens[] array in user data so it doesnt touch their assets this is called after they have no assets or liabiltiies of the token
/// @param user the user being targetted
/// @param tokenToRemove the token to remove from the portfolio
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
/// @notice This function returns the users tokens array ( the tokens in their portfolio) 
/// @param user the user being targetted
    function returnUsersAssetTokens(
        address user
    ) external view returns (address[] memory) {
        IDataHub.UserData storage userData = userdata[user];
        return userData.tokens;
    }
/// @notice This function rchecks if a token is present in a users potrfolio
/// @param users the users being targetted
/// @param token being targetted
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




  /// -----------------------------------------------------------------------
  /// Asset Pool functions  --> 
  /// -----------------------------------------------------------------------

/// @notice This increases or decreases the asset supply of a given tokens
/// @param token the token being targetted
/// @param amount the amount to add or remove
/// @param pos_neg if its adding or removing asset supply 
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
/// @notice This increases or decreases the total borrowed amount of a given tokens
/// @param token the token being targetted
/// @param amount the amount to add or remove
/// @param pos_neg if its adding or removing from the borrowed amount
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
  /// -----------------------------------------------------------------------
  /// Asset Data functions  --> 
  /// -----------------------------------------------------------------------

  /// @notice This returns the asset data of a given asset see Idatahub for more details on what it returns 
  /// @param token the token being targetted
  /// @return returns the assets data
    function returnAssetLogs(
        address token
    ) external view returns (IDataHub.AssetData memory) {
        return assetdata[token];
    }

  /// @notice This returns the asset data of a given asset see Idatahub for more details on what it returns 
  /// @param token the token being targetted
  /// @return returns the assets data
    function FetchAssetInitilizationStatus(
        address token
    ) external view returns (bool) {
        return assetInitialized[token];
    }

  /// @notice This returns the asset data of a given asset see Idatahub for more details on what it returns 
  /// @param token the token being targetted
  /// @param assetPrice the starting asset price of the token 
  /// @param initialMarginFee the fee charged when they take out margin on the token
  /// @param liquidationFee the fee they pay when being liquidated
  /// @param initialMarginRequirement the amount they have to have in their portfolio to take out margin
  /// @param MaintenanceMarginRequirement the amount they need to hold in their account to sustain a margin position of the asset
  /// @param optimalBorrowProportion the optimal borrow proportion
  /// @param maximumBorrowProportion the maximum borrow proportion of the asset 
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
/// @notice Changes the assets price 
/// @param token the token being targetted 
/// @param value the new price 
    function toggleAssetPrice(
        address token,
        uint256 value
    ) external checkRoleAuthority {
        assetdata[token].assetPrice = value;
    }
 



  /// -----------------------------------------------------------------------
  /// User Data functions --> 
  /// -----------------------------------------------------------------------

/// @notice Returns a users data 
/// @param user being targetted
/// @param token the users data of the token being queried
/// @return a tuple containing their info of the token 

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
/// @notice calculates the total dollar value of the users assets 
/// @param user the address of the user we want to query
/// @return sumOfAssets the cumulative value of all their assets 
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
/// @notice calculates the total dollar value of the users liabilities
/// @param user the address of the user we want to query
/// @return sumOfliabilities the cumulative value of all their liabilities
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
/// @notice calculates the total dollar value of the users portfolio
/// @param user the address of the user we want to query
/// @return returns their assets - liabilities value in dollars 
    function calculateTotalPortfolioValue(
        address user
    ) external view returns (uint256) {
        return calculateTotalAssetValue(user) - calculateLiabilitiesValue(user);
    }
/// @notice calculates the total dollar value of the users Aggregate maintenance margin requirement 
/// @param user the address of the user we want to query
/// @return returns their AMMR
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
