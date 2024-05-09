// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IDataHub.sol";
import "./interfaces/IDepositVault.sol";
import "./interfaces/IOracle.sol";
import "./libraries/EVO_LIBRARY.sol";
import "./interfaces/IExecutor.sol";
import "./interfaces/IinterestData.sol";
import "hardhat/console.sol";

contract Utility is Ownable {
    function alterAdminRoles(
        address _DataHub,
        address _deposit_vault,
        address _oracle,
        address _interest,
        address _liquidator,
        address _ex
    ) public onlyOwner {
        admins[_DataHub] = true;
        Datahub = IDataHub(_DataHub);
        admins[_deposit_vault] = true;
        DepositVault = IDepositVault(_deposit_vault);
        admins[_oracle] = true;
        Oracle = IOracle(_oracle);
        admins[_interest] = true;
        interestContract = IInterestData(_interest);
        admins[_liquidator] = true;
        admins[_ex] = true;
    }

    /// @notice Alters the Admin roles for the contract
    /// @param _datahub  the new address for the datahub
    /// @param _depositVault the new address for the deposit vault
    /// @param _oracle the new address for oracle
    /// @param  _int the new address for the interest contract
    function alterContractStrucutre(
        address _datahub,
        address _depositVault,
        address _oracle,
        address _int
    ) public onlyOwner {
        Datahub = IDataHub(_datahub);
        DepositVault = IDepositVault(_depositVault);
        Oracle = IOracle(_oracle);
        interestContract = IInterestData(_int);
    }

    modifier checkRoleAuthority() {
        require(admins[msg.sender] == true, "Unauthorized");
        _;
    }

    /// @notice Keeps track of contract admins
    mapping(address => bool) public admins;

    IDataHub public Datahub;

    IOracle public Oracle;

    IDepositVault public DepositVault;

    IExecutor public Executor;

    IInterestData public interestContract;

    /** Constructor  */
    constructor(
        address initialOwner,
        address _DataHub,
        address _deposit_vault,
        address oracle,
        address _executor,
        address _interest
    ) Ownable(initialOwner) {
        Datahub = IDataHub(_DataHub);
        DepositVault = IDepositVault(_deposit_vault);
        Oracle = IOracle(oracle);
        Executor = IExecutor(_executor);
        interestContract = IInterestData(_interest);
    }

    /// @notice Explain to an end user what this does
    /// @dev Explain to a developer any extra details
    /// @param user being argetted
    /// @param token being argetted
    function validateMarginStatus(
        address user,
        address token
    ) public view returns (bool) {
        (, , , bool margined, ) = Datahub.ReadUserData(user, token);
        return margined;
    }

    //// @notice calcualtes aimmr
    /// @dev Explain to a developer any extra details
    /// @param user being argetted
    /// @param token being argetted
    /// @param BalanceToLeave the balance to leave
    function calculateAIMRRequirement(
        address user,
        address token,
        uint256 BalanceToLeave
    ) external view returns (bool) {
        if (
            Datahub.calculateAIMRForUser(user, token, BalanceToLeave) <=
            Datahub.calculateTotalPortfolioValue(user)
        ) {
            return true;
        } else {
            return false;
        }
    }

    //// @notice Explain to an end user what this does
    /// @dev Explain to a developer any extra details
    /// @param user being argetted
    /// @param token being argetted
    /// @param BalanceToLeave the balance to leave
    /// @param userAssets the users assets
    function calculateMarginRequirement(
        address user,
        address token,
        uint256 BalanceToLeave,
        uint256 userAssets
    ) external view returns (bool) {
        uint256 liabilities = (BalanceToLeave - userAssets);
        if (
            Datahub.calculateAMMRForUser(user) +
                (EVO_LIBRARY.calculateMaintenanceRequirementForTrade(
                    Datahub.returnAssetLogs(token),
                    liabilities
                ) * Datahub.returnAssetLogs(token).assetPrice) <=
            Datahub.calculateTotalPortfolioValue(user)
        ) {
            return true;
        } else {
            return false;
        }
    }

    //// @notice calcualtes aimmr
    /// @dev Explain to a developer any extra details
    /// @param user being argetted
    function calculateAMMRRequirement(
        address user
    ) external view returns (bool) {
        if (
            Datahub.calculateAMMRForUser(user) <=
            Datahub.calculateTotalPortfolioValue(user)
        ) {
            return true;
        } else {
            return false;
        }
    }
    /// @notice Takes a single users address and returns the amount of liabilities that are going to be issued to that user
    function calculateAmountToAddToLiabilities(
        address user,
        address token,
        uint256 amount
    ) public view returns (uint256) {
        (uint256 assets, , , , ) = Datahub.ReadUserData(user, token);
        return amount > assets ? amount - assets : 0;
    }
    /// @notice Cycles through two lists of users and checks how many liabilities are going to be issued to each user
    function calculateTradeLiabilityAddtions(
        address[2] memory pair,
        address[][2] memory participants,
        uint256[][2] memory trade_amounts
    ) public view returns (uint256[] memory, uint256[] memory) {
        // console.log("================calculateTradeLiabilityAddtions Function=====================");
        uint256[] memory TakerliabilityAmounts = new uint256[](
            participants[0].length
        );
        uint256[] memory MakerliabilityAmounts = new uint256[](
            participants[1].length
        );

        for (uint256 i = 0; i < participants[0].length; i++) {
            uint256 TakeramountToAddToLiabilities = calculateAmountToAddToLiabilities(
                    participants[0][i],
                    pair[0],
                    trade_amounts[0][i]
                );
            
            // console.log("TakeramountToAddToLiabilities", TakeramountToAddToLiabilities);

            TakerliabilityAmounts[i] = TakeramountToAddToLiabilities;
        }

        for (uint256 i = 0; i < participants[1].length; i++) {
            uint256 MakeramountToAddToLiabilities = calculateAmountToAddToLiabilities(
                    participants[1][i],
                    pair[1],
                    trade_amounts[1][i]
                );
            // console.log("MakeramountToAddToLiabilities", MakeramountToAddToLiabilities);
            MakerliabilityAmounts[i] = MakeramountToAddToLiabilities;
        }

        return (TakerliabilityAmounts, MakerliabilityAmounts);
    }
    /// @notice Cycles through a list of users and returns the bulk assets sum
    function returnBulkAssets(
        address[] memory users,
        address token
    ) public view returns (uint256) {
        uint256 bulkAssets;
        for (uint256 i = 0; i < users.length; i++) {
            (uint256 assets, , , , ) = Datahub.ReadUserData(users[i], token);

            bulkAssets += assets;
        }
        return bulkAssets;
    }

    /// @notice Explain to an end user what this does
    /// @dev Explain to a developer any extra details
    /// @param user being argetted
    /// @param token being argetted
    /// @return assets
    function returnAssets(
        address user,
        address token
    ) external view returns (uint256) {
        (uint256 assets, , , , ) = Datahub.ReadUserData(user, token);
        return assets;
    }

    function returnliabilities(
        address user,
        address token
    ) public view returns (uint256) {
        (, uint256 liabilities, , , ) = Datahub.ReadUserData(user, token);
        return liabilities;
    }

    /// @notice Explain to an end user what this does
    /// @dev Explain to a developer any extra details
    /// @param user being targetted
    /// @param token being targetted
    /// @return pending balance
    function returnPending(
        address user,
        address token
    ) external view returns (uint256) {
        (, , uint256 pending, , ) = Datahub.ReadUserData(user, token);
        return pending;
    }

    function returnMaintenanceRequirementForTrade(
        address token,
        uint256 amount
    ) external view returns (uint256) {
        IDataHub.AssetData memory assetLogs = Datahub.returnAssetLogs(token);
        uint256 maintenace = assetLogs.MaintenanceMarginRequirement;
        return ((maintenace * (amount)) / 10 ** 18); //
    }

    /// @notice Checks that the trade will not push the asset over maxBorrowProportion
    function maxBorrowCheck(
        address[2] memory pair,
        address[][2] memory participants,
        uint256[][2] memory trade_amounts
    ) public view returns (bool) {
        uint256 newLiabilitiesIssued;
        for (uint256 i = 0; i < pair.length; i++) {
            newLiabilitiesIssued = EVO_LIBRARY.calculateTotal(
                trade_amounts[i]
            ) > returnBulkAssets(participants[i], pair[i]) // sum of users assets
                ? EVO_LIBRARY.calculateTotal(trade_amounts[i]) -
                    returnBulkAssets(participants[i], pair[i])
                : 0;

            if (newLiabilitiesIssued > 0) {
                return
                    EVO_LIBRARY.calculateBorrowProportionAfterTrades(
                        Datahub.returnAssetLogs(pair[i]),
                        newLiabilitiesIssued
                    );
            }
        }
        return true;
    }

    /// @notice this function runs the margin checks, changes margin status if applicable and adds pending balances
    /// @param pair the pair of tokens being traded
    /// @param participants of the trade 2 nested arrays
    /// @param trade_amounts the trades amounts for each participant
    function processMargin(
        address[2] memory pair,
        address[][2] memory participants,
        uint256[][2] memory trade_amounts
    ) external returns (bool) {
        bool takerTradeConfirmation = processChecks(
            participants[0],
            trade_amounts[0],
            pair[0]
        );
        bool makerTradeConfirmation = processChecks(
            participants[1],
            trade_amounts[1],
            pair[1]
        );

        if (!makerTradeConfirmation || !takerTradeConfirmation) {
            return false;
        } else {
            return true;
        }
    }

    /// @notice Processes a trade details
    /// @param  participants the participants on the trade
    /// @param  tradeAmounts the trade amounts in the trade
    /// @param  pair the token involved in the trade
    function processChecks(
        address[] memory participants,
        uint256[] memory tradeAmounts,
        address pair
    ) internal returns (bool) {
        for (uint256 i = 0; i < participants.length; i++) {
            (uint256 assets, , , , ) = Datahub.ReadUserData(
                participants[i],
                pair
            );

            if (tradeAmounts[i] > assets) {
                uint256 initalMarginFeeAmount = EVO_LIBRARY
                    .calculateinitialMarginFeeAmount(
                        Datahub.returnAssetLogs(pair),
                        tradeAmounts[i]
                    );
                initalMarginFeeAmount *=
                    (Datahub.returnAssetLogs(pair).assetPrice) /
                    10 ** 18;

                if (
                    Datahub.calculateCollateralValue(participants[i]) <=
                    Datahub.calculateAIMRForUser(participants[i]) +
                        initalMarginFeeAmount
                ) {
                    return false;
                }

                if (!validateMarginStatus(participants[i], pair)) {
                    Datahub.SetMarginStatus(participants[i], true);
                }
            }
        }
        return true;
    }

    /// @notice This modify's a users maintenance margin requirement
    /// @dev Explain to a developer any extra details
    /// @param user the user we are modifying the mmr of
    /// @param in_token the token entering the users wallet
    /// @param out_token the token leaving the users wallet
    /// @param amount the amount being adjected
    function Modifymmr(
        address user,
        address in_token,
        address out_token,
        uint256 amount
    ) external checkRoleAuthority {
        IDataHub.AssetData memory assetLogsOutToken = Datahub.returnAssetLogs(
            out_token
        );
        IDataHub.AssetData memory assetLogsInToken = Datahub.returnAssetLogs(
            in_token
        );
        if (amount <= returnliabilities(user, in_token)) {
            uint256 StartingDollarMMR = (amount *
                assetLogsOutToken.MaintenanceMarginRequirement) / 10 ** 18; // check to make sure this is right
            if (
                StartingDollarMMR >
                Datahub.returnPairMMROfUser(user, in_token, out_token)
            ) {
                uint256 overage = (StartingDollarMMR -
                    Datahub.returnPairMMROfUser(user, in_token, out_token)) * (10 ** 18) /
                    assetLogsInToken.MaintenanceMarginRequirement;

                Datahub.removeMaintenanceMarginRequirement(
                    user,
                    in_token,
                    out_token,
                    Datahub.returnPairMMROfUser(user, in_token, out_token)
                );

                uint256 liabilityMultiplier = EVO_LIBRARY
                    .calculatedepositLiabilityRatio(
                        returnliabilities(user, in_token),
                        overage
                    );

                address[] memory tokens = Datahub.returnUsersAssetTokens(user);

                for (uint256 i = 0; i < tokens.length; i++) {
                    Datahub.alterMMR(
                        user,
                        in_token,
                        tokens[i],
                        liabilityMultiplier
                    );
                }
            } else {
                Datahub.removeMaintenanceMarginRequirement(
                    user,
                    in_token,
                    out_token,
                    StartingDollarMMR
                );
            }
        } else {
            for (
                uint256 i = 0;
                i < Datahub.returnUsersAssetTokens(user).length;
                i++
            ) {
                address[] memory tokens = Datahub.returnUsersAssetTokens(user);
                Datahub.removeMaintenanceMarginRequirement(
                    user,
                    in_token,
                    tokens[i],
                    Datahub.returnPairMMROfUser(user, in_token, tokens[i])
                );
            }
        }
    }

    function Modifyimr(
        address user,
        address in_token,
        address out_token,
        uint256 amount
    ) external checkRoleAuthority {
        IDataHub.AssetData memory assetLogsOutToken = Datahub.returnAssetLogs(
            out_token
        );
        IDataHub.AssetData memory assetLogsInToken = Datahub.returnAssetLogs(
            in_token
        );
        if (amount <= returnliabilities(user, in_token)) {
            uint256 StartingDollarIMR = (amount *
                assetLogsOutToken.initialMarginRequirement) / 10 ** 18; // check to make sure this is right
            if (
                StartingDollarIMR >
                Datahub.returnPairIMROfUser(user, in_token, out_token)
            ) {
                uint256 overage = (StartingDollarIMR -
                    Datahub.returnPairIMROfUser(user, in_token, out_token)) * (10 ** 18) /
                    assetLogsInToken.initialMarginRequirement;

                Datahub.removeInitialMarginRequirement(
                    user,
                    in_token,
                    out_token,
                    Datahub.returnPairIMROfUser(user, in_token, out_token)
                );

                uint256 liabilityMultiplier = EVO_LIBRARY
                    .calculatedepositLiabilityRatio(
                        returnliabilities(user, in_token),
                        overage
                    );

                address[] memory tokens = Datahub.returnUsersAssetTokens(user);

                for (uint256 i = 0; i < tokens.length; i++) {
                    Datahub.alterIMR(
                        user,
                        in_token,
                        tokens[i],
                        liabilityMultiplier
                    );
                }
            } else {
                Datahub.removeInitialMarginRequirement(
                    user,
                    in_token,
                    out_token,
                    StartingDollarIMR
                );
            }
        } else {
            for (
                uint256 i = 0;
                i < Datahub.returnUsersAssetTokens(user).length;
                i++
            ) {
                address[] memory tokens = Datahub.returnUsersAssetTokens(user);
                Datahub.removeInitialMarginRequirement(
                    user,
                    in_token,
                    tokens[i],
                    Datahub.returnPairIMROfUser(user, in_token, tokens[i])
                );
            }
        }
    }
/*
    /// @notice Explain to an end user what this does
    /// @dev Explain to a developer any extra details
    /// @param token the token being targetted
    /// @param index the index of the period
    /// @return MassCharge
    function chargeStaticLiabilityInterest(
        address token,
        uint256 index
    ) public view returns (uint256) {
        uint256 LiabilityToCharge = Datahub.returnAssetLogs(token).totalBorrowedAmount;
        uint256 LiabilityDelta;

        if (
            Datahub.returnAssetLogs(token).totalBorrowedAmount >
            interestContract.fetchLiabilitiesOfIndex(token, index)
        ) {
            LiabilityDelta =
                Datahub.returnAssetLogs(token).totalBorrowedAmount -
                interestContract.fetchLiabilitiesOfIndex(token, index);
            LiabilityToCharge += LiabilityDelta;
        } else {
            LiabilityDelta =
                interestContract.fetchLiabilitiesOfIndex(token, index) -
                Datahub.returnAssetLogs(token).totalBorrowedAmount;

            LiabilityToCharge -= LiabilityDelta;
        }

        uint256 MassCharge = (LiabilityToCharge *
            ((interestContract.fetchCurrentRate(token)) / 8736)) / 10 ** 18;
        return MassCharge;
    }
*/
    function fetchBorrowProportionList(
        uint256 dimension,
        uint256 startingIndex,
        uint256 endingIndex,
        address token
    ) public view returns (uint256[] memory) {
        uint256[] memory BorrowProportionsForThePeriod = new uint256[](
            (endingIndex) - startingIndex + 1
        );
        uint counter = 0;
        for (uint256 i = startingIndex; i <= endingIndex; i++) {
            BorrowProportionsForThePeriod[counter] = interestContract
                .fetchTimeScaledRateIndex(dimension, token, i)
                .borrowProportionAtIndex;

            counter += 1;
        }
        return BorrowProportionsForThePeriod;
    }
    function fetchRatesList(
        uint256 dimension,
        uint256 startingIndex,
        uint256 endingIndex,
        address token
    ) external view returns (uint256[] memory) {
        // console.log("====================================rate list==============================");
        // console.log("dimension", dimension);
        // console.log("start", startingIndex);
        // console.log("endingIndex", endingIndex);

        uint256[] memory interestRatesForThePeriod = new uint256[](
            (endingIndex) - startingIndex + 1
        );
        uint counter = 0;
        for (uint256 i = startingIndex; i <= endingIndex; i++) {
            // console.log("i", i);
            interestRatesForThePeriod[counter] = interestContract
            .fetchTimeScaledRateIndex(dimension, token, i).interestRate;
            // console.log("interest reate", interestRatesForThePeriod[counter]);
            counter += 1;
        }
        // console.log("counter", counter);
        // console.log("=========================end==============================");
        return interestRatesForThePeriod;
    }

    /// @notice Fetches the total amount borrowed of the token
    /// @param token the token being queried
    /// @return the total borrowed amount
    function fetchTotalAssetSupply(
        address token
    ) external view returns (uint256) {
        return  Datahub.returnAssetLogs(token).totalAssetSupply;
    }
    receive() external payable {}
}
