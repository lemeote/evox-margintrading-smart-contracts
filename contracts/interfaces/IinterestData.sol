// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;
import "../interfaces/IDataHub.sol";

interface IInterestData {
    struct interestDetails {
        uint256 lastUpdatedTime; // last updated time
        uint256 totalLiabilitiesAtIndex;
        uint256 borrowProportionAtIndex;
        uint256[] rateInfo; ///minimumInterestRate,  optimalInterestRate, maximumInterestRate
        uint256 interestRate; // current interestRate
    }

    function calculateCompoundedLiabilities(
        address token,
        uint256 newLiabilities,
        uint256 usersLiabilities,
        uint256 usersOriginIndex
    ) external view returns (uint256);

   function calculateCompoundedAssets(
        address token,
        uint256 usersAssets,
        uint256 usersOriginIndex
    ) external view returns (uint256, uint256, uint256) ;

    function fetchRateInfo(
        address token,
        uint256 index
    ) external view returns (interestDetails memory);

    function fetchRate(
        address token,
        uint256 index
    ) external view returns (uint256);

    function fetchCurrentRateIndex(
        address token
    ) external view returns (uint256);

    function chargeMassinterest(address token) external;

    function fetchCurrentRate(address token) external view returns (uint256);

    function updateInterestIndex(
        address token,
        uint256 index,
        uint256 value
    ) external;

    function chargeStaticLiabilityInterest(
        address token,
        uint256 index
    ) external view returns (uint256);
}
