// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IDataHub.sol";
import "./interfaces/IExecutor.sol";
import "./interfaces/IinterestData.sol";
import "hardhat/console.sol";
import "./libraries/REX_LIBRARY.sol";

contract interestData is Ownable {
    modifier checkRoleAuthority() {
        require(
            msg.sender == owner() ||
                msg.sender == address(Datahub) ||
                msg.sender == address(Executor),
            "Unauthorized"
        );
        _;
    }

    IDataHub public Datahub;
    IExecutor public Executor;

    constructor(address initialOwner, address _DataHub) Ownable(initialOwner) {
        Datahub = IDataHub(_DataHub);
    }

    function AlterAdmins(address _executor, address _DataHub) public onlyOwner {
        Executor = IExecutor(_executor);
        Datahub = IDataHub(_DataHub);
    }

    mapping(address => mapping(uint256 => IInterestData.interestDetails)) interestInfo;

    mapping(address => uint256) currentInterestIndex;

    function fetchRates(
        address token,
        uint256 index
    ) public view returns (IInterestData.interestDetails memory) {
        return interestInfo[token][index];
    }

    function fetchCurrentRateIndex(
        address token
    ) public view returns (uint256) {
        return currentInterestIndex[token];
    }

    function toggleInterestRate(
        address token,
        uint256 index,
        uint256 value
    ) external checkRoleAuthority {
        currentInterestIndex[token] = index + 1; // fetch current plus 1?
        interestInfo[token][currentInterestIndex[token]].interestRate = value;
        interestInfo[token][currentInterestIndex[token]].lastUpdatedTime = block
            .timestamp;
        interestInfo[token][currentInterestIndex[token]]
            .rateInfo = interestInfo[token][index].rateInfo;

        interestInfo[token][index].totalLiabilitiesAtIndex = Datahub
            .returnAssetLogs(token)
            .totalBorrowedAmount;
    }

    function initInterest(
        address token,
        uint256 index,
        uint256[] memory rateInfo,
        uint256 interestRate
    ) external checkRoleAuthority {
        interestInfo[token][index].lastUpdatedTime = block.timestamp;
        interestInfo[token][index].rateInfo = rateInfo;
        interestInfo[token][index].interestRate = interestRate;
        currentInterestIndex[token] = index;
    }


function chargeMassinterest(address token) public{
           if (
            fetchRates(token, fetchCurrentRateIndex(token))
                .lastUpdatedTime +
                1 hours <
            block.timestamp
        ) {
       
            Datahub.setTotalBorrowedAmount(token, Executor.chargeLiabilityDelta(
                token,
                fetchCurrentRateIndex(token)
            ), true);

            Datahub.toggleInterestRate(
                token,
                REX_LIBRARY.calculateInterestRate(
                    0,
                    Datahub.returnAssetLogs(token),
                    fetchRates(
                        token,
                        fetchCurrentRateIndex(token)
                    )
                )
            );
        }
}
    receive() external payable {}
}
