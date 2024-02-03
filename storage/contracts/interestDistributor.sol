// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IDataHub.sol";
import "./interfaces/IDepositVault.sol";
import "./libraries/REX_LIBRARY.sol";
import "./interfaces/IExecutor.sol";

import "hardhat/console.sol";

contract InterestRateDistributor is Ownable {
    /// on deposit and withdraw write to total historical users and user id

    uint256 public InterestRateDistributorCut = 2;
    uint256 public InterestRateREXCut = 18;
    uint256 public InterestRateFunderCut = 80;

    uint256 public lastInterestFeeDistribution;

    address[] private tokens_distributed;
    mapping(uint256 => address) userId;
    mapping(address => uint256) public InterestChargedPerToken;

    IDataHub public Datahub;
    IDepositVault public DepositVault;


    address private DAOTREASURY;

    address public USDT = address(0xdfc6a3f2d7daff1626Ba6c32B79bEE1e1d6259F0);

    /** Constructor  */
    constructor(
        address initialOwner,
        address _DataHub,
        address _deposit_vault
    ) Ownable(initialOwner) {
        Datahub = IDataHub(_DataHub);
        DepositVault = IDepositVault(_deposit_vault);
    }

    function alterFeeSplits(
        uint256 discut,
        uint256 rexcut,
        uint256 fundercut
    ) public onlyOwner {
        InterestRateDistributorCut = discut;
        InterestRateREXCut = rexcut;
        InterestRateFunderCut = fundercut;
    }

    function modifyMMR(
        address user,
        address in_token,
        uint256 amount,
        uint256 liabilities
    ) private {
        address[] memory tokens = Datahub.returnUsersAssetTokens(user);
        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 liabilityMultiplier = REX_LIBRARY
                .calculatedepositLiabilityRatio(
                    (amount / 10 ** 18),
                    liabilities
                ); // i switched these because its big amount divided by small amount --> scale up baby
            Datahub.alterMMR(user, in_token, tokens[i], liabilityMultiplier);
        }
    }

    // current liab / unadjusted liabilities
    function ChargeBulkInterest() public {
        require(
            block.timestamp >= lastInterestFeeDistribution + 1 hours,
            "can only be called once every hour"
        );
        for (uint256 i = 0; i < DepositVault.fetchtotalHistoricalUsers(); i++) {
            (, , , bool margined, address[] memory tokens) = Datahub
                .ReadUserData(userId[i], USDT);
            // what if i had a way of markeing how many user have liabilities?
            if (margined == true) {
                //userInitialized[user] == true && userData.margined == true

                for (uint256 j = 0; j < tokens.length; j++) {
                    (, uint256 liabilities, , , ) = Datahub.ReadUserData(
                        userId[i],
                        tokens[j]
                    );

                    if (liabilities > 0) {
                        uint256 interestRateForHour = REX_LIBRARY
                            .calculateInterestRate(
                                liabilities,
                                Datahub.returnAssetLogs(tokens[j])
                            );

                        uint256 interestChargedForHour = interestRateForHour *
                            liabilities;

                        uint256 unadjustedliabilities = liabilities;

                        Datahub.addLiabilities(
                            userId[i],
                            tokens[j],
                            interestRateForHour
                        );

                        modifyMMR(
                            userId[i],
                            tokens[j],
                            unadjustedliabilities,
                            liabilities
                        );

                        InterestChargedPerToken[
                            tokens[j]
                        ] += interestChargedForHour;

                        bool tokenFound = false;

                        if (tokens_distributed.length > 0) {
                            for (
                                uint256 l = 0;
                                l < tokens_distributed.length;
                                l++
                            ) {
                                if (tokens_distributed[l] == tokens[j]) {
                                    // Token found in the array
                                    tokenFound = true;
                                    break; // Exit the inner loop as soon as the token is found
                                }
                            }
                        } else {
                            tokens_distributed.push(tokens[j]);
                        }

                        if (!tokenFound) {
                            // Token not found for the current user, add it to the array
                            tokens_distributed.push(tokens[j]);
                        }
                    }
                }
            }

            for (uint256 y = 0; y < tokens_distributed.length; y++) {
                address token = tokens_distributed[y];
                uint256 PercentageRate = InterestChargedPerToken[token] / 100;

                uint256 CallerCut = PercentageRate * InterestRateDistributorCut;
                uint256 FunderCut = PercentageRate * InterestRateFunderCut;
                uint256 REXHolderCut = PercentageRate * InterestRateREXCut;

                Datahub.addAssets(msg.sender, token, CallerCut);

                Datahub.addAssets(DAOTREASURY, token, REXHolderCut);

                Datahub.addAssets(userId[i], token, FunderCut);
            }
        }
        lastInterestFeeDistribution = block.timestamp;
    }
}
