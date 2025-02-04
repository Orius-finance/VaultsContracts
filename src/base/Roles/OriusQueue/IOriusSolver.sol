// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

interface IOriusSolver {
    function oriusSolve(
        address initiator,
        address oriusVault,
        address solveAsset,
        uint256 totalShares,
        uint256 requiredAssets,
        bytes calldata solveData
    ) external;
}
