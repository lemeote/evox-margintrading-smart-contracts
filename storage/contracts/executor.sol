// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IDataHub.sol";
import "./interfaces/IDepositVault.sol";
import "./interfaces/IOracle.sol";
import "./interfaces/IUtilityContract.sol";
import "./libraries/REX_LIBRARY.sol";
import "hardhat/console.sol";

contract REX_EXCHANGE is Ownable {
    /** Address's  */

    IDataHub public Datahub;

    IOracle public Oracle;

    IDepositVault public DepositVault;

    IUtilityContract public Utilities;

    address public FeeWallet =
        address(0x1167E56ABcf9d2dF6354e03610E301B8a2934955);



    /** Constructor  */
    constructor(
        address initialOwner,
        address _DataHub,
        address _deposit_vault,
        address oracle,
        address _utility
    ) Ownable(initialOwner) {
        Datahub = IDataHub(_DataHub);
        DepositVault = IDepositVault(_deposit_vault);
        Oracle = IOracle(oracle);
        Utilities = IUtilityContract(_utility);
    }

    modifier checkRoleAuthority() {
        require(msg.sender == address(Oracle), "Unauthorized");
        _;
    }

    function SubmitOrder(
        address[2] memory pair,
        address[][2] memory participants,
        uint256[][2] memory trade_amounts
    ) public {
        uint256[] memory TakerliabilityAmounts = new uint256[](
            participants[0].length
        );
        uint256[] memory MakerliabilityAmounts = new uint256[](
            participants[1].length
        );
        // this checks if the asset they are trying to trade isn't pass max borrow
        for (uint256 i = 0; i < pair.length; i++) {
            uint256 newLiabilitiesIssued = REX_LIBRARY.calculateTotal(
                trade_amounts[i]
            ) > Utilities.returnBulkAssets(participants[i], pair[i])
                ? REX_LIBRARY.calculateTotal(trade_amounts[i]) -
                    Utilities.returnBulkAssets(participants[i], pair[i])
                : 0;

            if (newLiabilitiesIssued > 0) {
                console.log(
                    REX_LIBRARY.calculateBorrowProportionAfterTrades(
                        Datahub.returnAssetLogs(pair[i]),
                        newLiabilitiesIssued
                    ),
                    "borrow proportion after trade"
                );

                require(
                    REX_LIBRARY.calculateBorrowProportionAfterTrades(
                        Datahub.returnAssetLogs(pair[i]),
                        newLiabilitiesIssued
                    ),
                    "asset is not tradeable because it would be over max borrow proportion of"
                );
            }
        }

        for (uint256 i = 0; i < participants[0].length; i++) {
            (uint256 assets, , , , , ) = Datahub.ReadUserData(
                participants[0][i],
                pair[0]
            );

            if (trade_amounts[0][i] > assets) {
                require(
                    Utilities.calculateMarginRequirement(
                        participants[0][i],
                        pair[0],
                        trade_amounts[0][i],
                        assets
                    ),
                    "you failed the margin requirements"
                );
                // now here right we know for a fucking fact this will be a margin trade should i mark it as such?

                if (
                    Utilities.validateMarginStatus(
                        participants[0][i],
                        pair[0]
                    ) == false
                ) {
                    Datahub.SetMarginStatus(participants[0][i], true);
                }
                uint256 TakeramountToAddToLiabilities = Utilities
                    .calculateAmountToAddToLiabilities(
                        participants[0][i],
                        pair[0],
                        trade_amounts[0][i]
                    );

                TakerliabilityAmounts[i] = TakeramountToAddToLiabilities;
                AlterPendingBalances(participants[0][i], pair[0], assets);
            } else {
                TakerliabilityAmounts[i] = 0;
                AlterPendingBalances(
                    participants[0][i],
                    pair[0],
                    trade_amounts[0][i]
                );
            }
        }

        for (uint256 i = 0; i < participants[1].length; i++) {
            (uint256 assets, , , , , ) = Datahub.ReadUserData(
                participants[1][i],
                pair[1]
            );
            if (trade_amounts[1][i] > assets) {
                require(
                    Utilities.calculateMarginRequirement(
                        participants[1][i],
                        pair[1],
                        trade_amounts[1][i],
                        assets
                    ),
                    "you failed the margin requirement"
                );
                if (
                    Utilities.validateMarginStatus(
                        participants[1][i],
                        pair[1]
                    ) == false
                ) {
                    Datahub.SetMarginStatus(participants[1][i], true);
                }

                /// becauswe we know that the trade amount is larger than that users assets
                // we calcualte how much to add to their liabilities right
                uint256 amountToAddToLiabilities = Utilities
                    .calculateAmountToAddToLiabilities(
                        participants[1][i],
                        pair[1],
                        trade_amounts[1][i]
                    );

                MakerliabilityAmounts[i] = amountToAddToLiabilities;

                AlterPendingBalances(participants[1][i], pair[1], assets);
            } else {
                MakerliabilityAmounts[i] = 0;
                AlterPendingBalances(
                    participants[1][i],
                    pair[1],
                    trade_amounts[1][i]
                );
            }
        }
        Oracle.ProcessTrade(
            pair,
            participants,
            trade_amounts,
            TakerliabilityAmounts,
            MakerliabilityAmounts
        );
    }

    function TransferBalances(
        address[2] memory pair,
        address[] memory takers,
        address[] memory makers,
        uint256[] memory taker_amounts,
        uint256[] memory maker_amounts,
        uint256[] memory TakerliabilityAmounts,
        uint256[] memory MakerliabilityAmounts
    ) external checkRoleAuthority {
        Datahub.checkIfAssetIsPresent(takers, pair[1]);
        Datahub.checkIfAssetIsPresent(makers, pair[0]);
        // checks if the asset is in the users portfolio already or not and adds it if it isnt
        for (uint256 i = 0; i < makers.length; i++) {
            executeTrade(
                makers,
                taker_amounts,
                maker_amounts,
                MakerliabilityAmounts,
                pair[1],
                pair[0]
            );
        }
        for (uint256 i = 0; i < takers.length; i++) {
            executeTrade(
                takers,
                maker_amounts,
                taker_amounts,
                TakerliabilityAmounts,
                pair[0],
                pair[1]
            );
        }
    }

    function executeTrade(
        address[] memory users,
        uint256[] memory amounts_in_token,
        uint256[] memory amounts_out_token,
        uint256[] memory liabilityAmounts,
        address out_token,
        address in_token
    ) private {
        for (uint256 i = 0; i < users.length; i++) {
            uint256 amountToAddToLiabilities = liabilityAmounts[i];

            if (amountToAddToLiabilities != 0) {
                if (block.timestamp % 3600 != 0) {
                    amountToAddToLiabilities += Utilities.handleHourlyFee(
                        out_token,
                        amountToAddToLiabilities
                    );
                }
                Datahub.addAssets(
                    FeeWallet,
                    out_token,
                    REX_LIBRARY.calculateinitialMarginFeeAmount(
                        returnAssetLogs(out_token),
                        amountToAddToLiabilities
                    )
                );

                Datahub.addLiabilities(
                    users[i],
                    out_token,
                    amountToAddToLiabilities
                );

                Datahub.setTotalBorrowedAmount(
                    out_token,
                    amountToAddToLiabilities,
                    true
                );
                /// here
                Datahub.updateInterestIndex(
                    out_token,
                    REX_LIBRARY.calculateInterestRate(
                        amountToAddToLiabilities,
                        returnAssetLogs(out_token)
                    )
                );

                Datahub.addMaintenanceMarginRequirement(
                    users[i],
                    out_token,
                    REX_LIBRARY.calculateMaintenanceRequirementForTrade(
                        returnAssetLogs(in_token),
                        amountToAddToLiabilities
                    )
                );
            }
            if (
                amounts_in_token[i] <=
                Utilities.returnliabilities(users[i], in_token)
            ) {
                modifyMMR(users[i], in_token, amounts_in_token[i]);

                Datahub.removeLiabilities(
                    users[i],
                    in_token,
                    amounts_in_token[i]
                );
                Datahub.setTotalBorrowedAmount(
                    out_token,
                    amounts_in_token[i],
                    false
                );

                Datahub.updateInterestIndex(
                    in_token,
                    REX_LIBRARY.calculateInterestRate(
                        amountToAddToLiabilities,
                        returnAssetLogs(in_token)
                    )
                );

                /// take the difference of amount out token and MMR
                /*
                    Datahub.removeMaintenanceMarginRequirement(
                        users[i],
                        out_token,
                        Datahub.returnMMROfUser(users[i], out_token)
                    );
                } else {
                    Datahub.removeMaintenanceMarginRequirement(
                        users[i],
                        out_token,
                        Utilities.returnMaintenanceRequirementForTrade(
                            out_token,
                            amounts_out_token[i]
                        )
                    );
                }
                */
                ///////////////////////////////////////////////////////////////////////////////////////////////////////////
            } else {
                uint256 subtractedFromLiabilites = Utilities.returnliabilities(
                    users[i],
                    in_token
                ); // we know its greater than or equal to its safe to 0

                uint256 input_amount = amounts_in_token[i];

                if (subtractedFromLiabilites > 0) {
                    input_amount =
                        amounts_in_token[i] -
                        Utilities.returnliabilities(users[i], in_token);

                    modifyMMR(users[i], in_token, amounts_in_token[i]);

                    Datahub.removeLiabilities(
                        users[i],
                        in_token,
                        subtractedFromLiabilites
                    );

                    Datahub.setTotalBorrowedAmount(
                        in_token,
                        subtractedFromLiabilites,
                        false
                    );
                    // calculate interest rate
                    Datahub.updateInterestIndex(
                        in_token,
                        REX_LIBRARY.calculateInterestRate(
                            0,
                            returnAssetLogs(in_token)
                        )
                    );
                }

                if (
                    amounts_out_token[i] >
                    Utilities.returnPending(users[i], out_token)
                ) {
                    Datahub.removePendingBalances(
                        users[i],
                        out_token,
                        Utilities.returnPending(users[i], out_token)
                    );
                } else {
                    Datahub.removePendingBalances(
                        users[i],
                        out_token,
                        amounts_out_token[i]
                    );
                }

                Datahub.addAssets(users[i], in_token, input_amount);

                // Conditions met assets changed, set flag to true
            }
        }
    }



    function modifyMMR(address user, address token, uint256 amount) private {
        uint256 liabilities = Utilities.returnliabilities(user, token);

        uint256 mmr = Datahub.returnMMROfUser(user, token);

        if (amount <= liabilities) {
            // if amount in is less
            uint256 liabilityMultiplier = REX_LIBRARY
                .calculatedepositLiabilityRatio(
                    Utilities.returnliabilities(user, token),
                    amount
                );

            for (
                uint256 i = 0;
                i < Datahub.returnUsersAssetTokens(user).length;
                i++
            ) {
                address[] memory tokens = Datahub.returnUsersAssetTokens(user);

                if (Datahub.returnMMROfUser(user, tokens[i]) > 0) {
                    Datahub.alterMMR(user, tokens[i], liabilityMultiplier);
                }
            }
        }
        // checks to see if the user has liabilities of that asset
        else {
            Datahub.removeMaintenanceMarginRequirement(user, token, mmr); // remove all mmr
        }
    }

    function AlterPendingBalances(
        address participant,
        address asset,
        uint256 trade_amount
    ) private {
        Datahub.removeAssets(participant, asset, trade_amount);
        Datahub.addPendingBalances(participant, asset, trade_amount);
    }

    function returnAssetLogsExternal(
        address token
    ) external view returns (IDataHub.AssetData memory assetLogs) {
        return Datahub.returnAssetLogs(token);
    }

    function returnAssetLogs(
        address token
    ) internal view returns (IDataHub.AssetData memory assetLogs) {
        return Datahub.returnAssetLogs(token);
    }

    function alterAdminRoles(
        address _datahub,
        address _depositVault,
        address _oracle,
        address _utility
    ) public onlyOwner {
        Datahub = IDataHub(_datahub);
        DepositVault = IDepositVault(_depositVault);
        Oracle = IOracle(_oracle);
        Utilities = IUtilityContract(_utility);
    }

    receive() external payable {}
}
