// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;
import "../interfaces/IDataHub.sol";

interface IInterestData {
    struct interestDetails {
        uint256 lastUpdatedTime; // last updated time
        uint256 totalAssetSuplyAtIndex;
        uint256 totalLiabilitiesAtIndex;
        uint256 borrowProportionAtIndex;
        uint256[] rateInfo; ///minimumInterestRate,  optimalInterestRate, maximumInterestRate
        uint256 interestRate; // current interestRate
    }
    
    function fetchCurrentRate(address token) external view returns (uint256);

 
    function fetchLiabilitiesOfIndex(
        address token,
        uint256 index
    ) external view returns (uint256);

    function calculateAverageCumulativeInterest(
        uint256 startIndex,
        uint256 endIndex,
        address token
    ) external view returns (uint256);

    function calculateAverageCumulativeDepositInterest(
        uint256 startIndex,
        uint256 endIndex,
        address token
    ) external view returns (uint256);

    function fetchRateInfo(
        address token,
        uint256 index
    ) external view returns (interestDetails memory);

    function fetchCurrentRateIndex(
        address token
    ) external view returns (uint256);

    function chargeMassinterest(address token) external;

    function updateInterestIndex(
        address token,
        uint256 index,
        uint256 value
    ) external;
}
