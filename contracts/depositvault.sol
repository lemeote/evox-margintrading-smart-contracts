// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol" as ERC20;
import "@openzeppelin/contracts/interfaces/IERC20.sol" as IERC20;
import "./libraries/REX_LIBRARY.sol";
import "./interfaces/IExecutor.sol";
import "./interfaces/IinterestData.sol";

//  userId[totalHistoricalUsers] = msg.sender;
contract DepositVault is Ownable {
    constructor(
        address initialOwner,
        address dataHub,
        address executor,
        address interest
    ) Ownable(initialOwner) {
        Datahub = IDataHub(dataHub);
        Executor = IExecutor(executor);
        interestContract = IInterestData(interest);
    }

    IDataHub public Datahub;
    IExecutor public Executor;
    IInterestData public interestContract;

    using REX_LIBRARY for uint256;

    uint256 public totalHistoricalUsers;

    uint256 public totalDepositors;

    mapping(address => bool) public userInitialized;
    mapping(uint256 => address) public userId;

    /// @notice fetches and returns a tokens decimals
    /// @param token the token you want the decimals for
    /// @return Token.decimals() the token decimals

    function fetchDecimals(address token) public view returns (uint256) {
        ERC20.ERC20 Token = ERC20.ERC20(token);
        return Token.decimals();
    }

    /// @notice This reutrns the number of histrocial users
    /// @return totalHistoricalUsers the total historical users of the exchange
    function fetchtotalHistoricalUsers() external view returns (uint256) {
        return totalHistoricalUsers;
    }

    /// @notice This function checks if this user has been initilized
    /// @dev Explain to a developer any extra details
    /// @param user the user you want to fetch their status for
    /// @return bool if they are initilized or not
    function fetchstatus(address user) external view returns (bool) {
        if (userInitialized[user] == true) {
            return true;
        } else {
            return false;
        }
    }

    /// @notice This function modifies the mmr of the user on deposit
    /// @param user the user being targetted
    /// @param in_token the token coming into their wallet
    /// @param amount the amount being transfered into their wallet
    function modifyMMROnDeposit(
        address user,
        address in_token,
        uint256 amount
    ) private {
        address[] memory tokens = Datahub.returnUsersAssetTokens(user);
        (, uint256 liabilities, , , ) = Datahub.ReadUserData(
            msg.sender,
            in_token
        );
        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 liabilityMultiplier = REX_LIBRARY
                .calculatedepositLiabilityRatio(liabilities, amount);
            Datahub.alterMMR(user, in_token, tokens[i], liabilityMultiplier);
        }
    }

    /* DEPOSIT FUNCTION */
    /// @notice This deposits tokens and inits the user struct, and asset struct if new assets.
    /// @dev Explain to a developer any extra details
    /// @param token - the address of the token to be depositted
    /// @param amount - the amount of tokens to be depositted

    function deposit_token(
        address token,
        uint256 amount
    ) external returns (bool) {
        require(
            Datahub.FetchAssetInitilizationStatus(token) == true,
            "this asset is not available to be depositted or traded"
        );
        IERC20.IERC20 ERC20Token = IERC20.IERC20(token);
        require(ERC20Token.transferFrom(msg.sender, address(this), amount));

        Datahub.settotalAssetSupply(token, amount, true);

        (, uint256 liabilities, , , address[] memory tokens) = Datahub
            .ReadUserData(msg.sender, token);

        if (tokens.length == 0) {
            totalHistoricalUsers += 1;
            //    Datahub.alterUsersInterestRateIndex(msg.sender);
        }

        ///
        // checks to see if user is in the sytem and inits their struct if not
        if (liabilities > 0) {
            // checks to see if the user has liabilities of that asset

            if (amount <= liabilities) {
                // if the amount is less or equal to their current liabilities -> lower their liabilities using the multiplier

                uint256 liabilityMultiplier = REX_LIBRARY
                    .calculatedepositLiabilityRatio(liabilities, amount);

                Datahub.alterLiabilities(
                    msg.sender,
                    token,
                    ((10 ** 18) - liabilityMultiplier)
                );

                Datahub.setTotalBorrowedAmount(token, amount, false);

                interestContract.chargeMassinterest(token);

                return true;
            } else {
                modifyMMROnDeposit(msg.sender, token, amount);
                // if amount depositted is bigger that liability info 0 it out
                uint256 amountAddedtoAssets = amount - liabilities; // amount - outstanding liabilities

                Datahub.addAssets(msg.sender, token, amountAddedtoAssets); // add to assets

                Datahub.removeLiabilities(msg.sender, token, liabilities); // remove all liabilities

                Datahub.setTotalBorrowedAmount(token, liabilities, false);

                Datahub.changeMarginStatus(msg.sender);
                interestContract.chargeMassinterest(token);

                return true;
            }
        } else {
            address[] memory users = new address[](1);
            users[0] = msg.sender;

            Datahub.checkIfAssetIsPresent(users, token);
            Datahub.addAssets(msg.sender, token, amount);

            return true;
        }
    }

    /* WITHDRAW FUNCTION */

    /// @notice This withdraws tokens from the exchange
    /// @dev Explain to a developer any extra details
    /// @param token - the address of the token to be withdrawn
    /// @param amount - the amount of tokens to be withdrawn
    /// @return returns a bool to let the user know if withdraw was successful.

    // IMPORTANT MAKE SURE USERS CAN'T WITHDRAW PAST THE LIMIT SET FOR AMOUNT OF FUNDS BORROWED
    function withdraw_token(
        address token,
        uint256 amount
    ) external returns (bool) {
        (uint256 assets, , uint256 pending, , ) = Datahub.ReadUserData(
            msg.sender,
            token
        );

        require(pending == 0);
        require(amount <= assets);

        IDataHub.AssetData memory assetInformation = Datahub.returnAssetLogs(
            token
        );

        uint256 AssetPriceCalulation = (assetInformation.assetPrice * amount) /
            10 ** 18; // this is 10*18 dnominated price of asset amount

        uint256 usersAMMR = Datahub.calculateAMMRForUser(msg.sender);

        uint256 usersTPV = Datahub.calculateTotalPortfolioValue(msg.sender);

        bool UnableToWithdraw = usersAMMR + AssetPriceCalulation > usersTPV;
        // if the users AMMR + price of the withdraw is bigger than their TPV dont let them withdraw this

        bool borrowProportion = REX_LIBRARY
            .calculateBorrowProportionAfterTrades(
                Executor.returnAssetLogs(token),
                amount
            );

        require(!UnableToWithdraw && borrowProportion);

        if (amount == assets) {
            // remove assets and asset token from their portfolio
            Datahub.removeAssets(msg.sender, token, amount);
            Datahub.removeAssetToken(msg.sender, token);
        } else {
            Datahub.removeAssets(msg.sender, token, amount);
        }

        IERC20.IERC20 ERC20Token = IERC20.IERC20(token);
        ERC20Token.transfer(msg.sender, amount);

        Datahub.settotalAssetSupply(token, amount, false);

        IDataHub.AssetData memory assetLogs = Datahub.returnAssetLogs(token);

        // recalculate interest rate because total asset supply is changing
        if (assetLogs.totalBorrowedAmount > 0) {
            interestContract.chargeMassinterest(token);
        }
        return true;
    }

    /// @notice This alters the datahub
    /// @param _datahub this is the new address for the datahub
    function alterdataHub(address _datahub) public onlyOwner {
        Datahub = IDataHub(_datahub);
    }

    /// @notice This fetches a users primary account information assets, liabilities, and pending balances
    /// @param token the token you want the data for
    /// @param user the user we are wanting to fetch the information for
    /// @return [assets, liabilities, pending] the assets liabilities and pending balances for the user
    function GetTokenDepositInfo(
        address token,
        address user
    ) public view returns (uint256[3] memory) {
        (uint256 assets, uint256 liabilities, uint256 pending, , ) = Datahub
            .ReadUserData(user, token);
        return [assets, liabilities, pending];
    }

    receive() external payable {}
}
