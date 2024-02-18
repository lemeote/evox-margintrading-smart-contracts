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

    constructor(
        address initialOwner,
        address _DataHub,
        address _executor
    ) Ownable(initialOwner) {
        Datahub = IDataHub(_DataHub);
        Executor = IExecutor(_executor);
    }

    function AlterAdmins(address _executor, address _DataHub) public onlyOwner {
        Executor = IExecutor(_executor);
        Datahub = IDataHub(_DataHub);
    }

    mapping(address => mapping(uint256 => IInterestData.interestDetails)) interestInfo;

    mapping(address => uint256) currentInterestIndex;

    function fetchRateInfo(
        address token,
        uint256 index
    ) public view returns (IInterestData.interestDetails memory) {
        return interestInfo[token][index];
    }
   function fetchRate(
        address token,
        uint256 index
    ) public view returns (uint256) {
        return interestInfo[token][index].interestRate;
    }

    function fetchCurrentRate(address token) public view returns(uint256){
        return interestInfo[token][currentInterestIndex[token]].interestRate;
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
    ) public checkRoleAuthority {
        currentInterestIndex[token] = index + 1; // fetch current plus 1?
        interestInfo[token][currentInterestIndex[token]].interestRate = value;
        interestInfo[token][currentInterestIndex[token]].lastUpdatedTime = block
            .timestamp;
        interestInfo[token][currentInterestIndex[token]]
            .rateInfo = interestInfo[token][index].rateInfo;

        interestInfo[token][index].totalLiabilitiesAtIndex = Datahub
            .fetchTotalBorrowedAmount(token);
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
    function chargeLiabilityDelta(
        address token,
        uint256 index
    ) public view returns (uint256) {
        uint256 LiabilityToCharge = Datahub.fetchTotalBorrowedAmount(token);
        uint256 LiabilityDelta;

        IInterestData.interestDetails memory interestDetails = fetchRateInfo(token, index);
        if (
            Datahub.fetchTotalBorrowedAmount(token) >
            interestDetails.totalLiabilitiesAtIndex
        ) {
            // LiabilityDelta = TotalLiabilityPoolNow - TotalLiabilityPoolAtIndex // check which one is bigger, subtract the smaller from the bigger
            LiabilityDelta =
                Datahub.fetchTotalBorrowedAmount(token) -
                interestDetails.totalLiabilitiesAtIndex;
            //LiabilityToCharge = TotalLiabilityPoolNow - LiabilityDelta

         //   LiabilityToCharge = Datahub.fetchTotalBorrowedAmount(token) - LiabilityDelta;
        } else {
            LiabilityDelta =
                interestDetails.totalLiabilitiesAtIndex -
                Datahub.fetchTotalBorrowedAmount(token);

            LiabilityToCharge = Datahub.fetchTotalBorrowedAmount(token) + LiabilityDelta;
        }
        //MassCharge = LiabilityToCharge * CurrentHourlyIndexInterest  //This means the index that just passed (i.e. we charge at 12:00:01 we use the interest rate for 12:00:00)
        uint256 MassCharge = (LiabilityToCharge *
            ((fetchCurrentRate(token)) / 8760)) / 10**18;

        //TotalLiabilityPoolNow += MassCharge
        return MassCharge;   //753750438539632926624n    753760763955881175172n
    }

    function chargeMassinterest(address token) public onlyOwner {

        if (
            fetchRateInfo(token, fetchCurrentRateIndex(token)).lastUpdatedTime +
                1 hours <
            block.timestamp
        ) {

      
            Datahub.setTotalBorrowedAmount(
                token,
                chargeLiabilityDelta(
                    token,
                    fetchCurrentRateIndex(token)
                ),
                true
            );

            toggleInterestRate(
                token,
                fetchCurrentRateIndex(token),
                REX_LIBRARY.calculateInterestRate(
                      chargeLiabilityDelta(
                    token,
                    fetchCurrentRateIndex(token)
                ),
                    Datahub.returnAssetLogs(token),
                    fetchRateInfo(token, fetchCurrentRateIndex(token))
                )
            );  
     }
    }

    receive() external payable {}
}
