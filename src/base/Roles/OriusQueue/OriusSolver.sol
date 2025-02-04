// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Auth, Authority} from "@solmate/auth/Auth.sol";
import {OriusOnChainQueue, ERC20, SafeTransferLib} from "src/base/Roles/OriusQueue/OriusOnChainQueue.sol";
import {IOriusSolver} from "src/base/Roles/OriusQueue/IOriusSolver.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {Multicall} from "@openzeppelin/contracts/utils/Multicall.sol";

contract OriusSolver is IOriusSolver, Auth, Multicall {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    // ========================================= ENUMS =========================================
    enum SolveType {
        ORIUS_REDEEM, // Fill multiple user requests with a single transaction.
        ORIUS_REDEEM_MINT // Fill multiple user requests to redeem shares and mint new shares.

    }

    //============================== ERRORS ===============================
    error OriusSolver___WrongInitiator();
    error OriusSolver___OriusVaultTellerMismatch(address oriusVault, address teller);
    error OriusSolver___OnlySelf();
    error OriusSolver___FailedToSolve();
    error OriusSolver___OnlyQueue();

    //============================== IMMUTABLES ===============================

    OriusOnChainQueue internal immutable queue;

    constructor(address _owner, address _auth, address _queue) Auth(_owner, Authority(_auth)) {
        queue = OriusOnChainQueue(_queue);
    }

    //============================== ADMIN FUNCTIONS ===============================

    /**
     * @notice Allows the owner to rescue tokens from the contract.
     * @dev This should not normally be used, but it is possible that when performing a MIGRATION_REDEEM,
     *      the redemption of Cellar shares will return assets other than OriusVault shares.
     *      If the amount of assets is significant, it is very likely the solve will revert, but it is
     *      not guaranteed to revert, hence this function.
     */
    function rescueTokens(ERC20 token, uint256 amount) external requiresAuth {
        if (amount == type(uint256).max) amount = token.balanceOf(address(this));
        token.safeTransfer(msg.sender, amount);
    }

    //============================== ADMIN SOLVE FUNCTIONS ===============================

    /**
     * @notice Solve multiple user requests to redeem Orius Vault shares.
     */
    function oriusRedeemSolve(OriusOnChainQueue.OnChainWithdraw[] calldata requests, address teller)
        external
        requiresAuth
    {
        bytes memory solveData = abi.encode(SolveType.ORIUS_REDEEM, msg.sender, teller, true);

        queue.solveOnChainWithdraws(requests, solveData, address(this));
    }

    /**
     * @notice Solve multiple user requests to redeem Orius Vault shares and mint new Orius Vault shares.
     * @dev In order for this to work, the fromAccountant must have the toOriusVaults rate provider setup.
     */
    function oriusRedeemMintSolve(
        OriusOnChainQueue.OnChainWithdraw[] calldata requests,
        address fromTeller,
        address toTeller,
        address intermediateAsset
    ) external requiresAuth {
        bytes memory solveData =
            abi.encode(SolveType.ORIUS_REDEEM_MINT, msg.sender, fromTeller, toTeller, intermediateAsset, true);

        queue.solveOnChainWithdraws(requests, solveData, address(this));
    }

    //============================== USER SOLVE FUNCTIONS ===============================

    /**
     * @notice Allows a user to solve their own request to redeem Orius Vault shares.
     */
    function oriusRedeemSelfSolve(OriusOnChainQueue.OnChainWithdraw calldata request, address teller)
        external
        requiresAuth
    {
        if (request.user != msg.sender) revert OriusSolver___OnlySelf();

        OriusOnChainQueue.OnChainWithdraw[] memory requests = new OriusOnChainQueue.OnChainWithdraw[](1);
        requests[0] = request;

        bytes memory solveData = abi.encode(SolveType.ORIUS_REDEEM, msg.sender, teller, false);

        queue.solveOnChainWithdraws(requests, solveData, address(this));
    }

    /**
     * @notice Allows a user to solve their own request to redeem Orius Vault shares and mint new Orius Vault shares.
     * @dev In order for this to work, the fromAccountant must have the toOriusVaults rate provider setup.
     */
    function oriusRedeemMintSelfSolve(
        OriusOnChainQueue.OnChainWithdraw calldata request,
        address fromTeller,
        address toTeller,
        address intermediateAsset
    ) external requiresAuth {
        if (request.user != msg.sender) revert OriusSolver___OnlySelf();

        OriusOnChainQueue.OnChainWithdraw[] memory requests = new OriusOnChainQueue.OnChainWithdraw[](1);
        requests[0] = request;

        bytes memory solveData =
            abi.encode(SolveType.ORIUS_REDEEM_MINT, msg.sender, fromTeller, toTeller, intermediateAsset, false);

        queue.solveOnChainWithdraws(requests, solveData, address(this));
    }

    //============================== IORIUSSOLVER FUNCTIONS ===============================

    /**
     * @notice Implementation of the IOriusSolver interface.
     */
    function oriusSolve(
        address initiator,
        address oriusVault,
        address solveAsset,
        uint256 totalShares,
        uint256 requiredAssets,
        bytes calldata solveData
    ) external requiresAuth {
        if (msg.sender != address(queue)) revert OriusSolver___OnlyQueue();
        if (initiator != address(this)) revert OriusSolver___WrongInitiator();

        SolveType solveType = abi.decode(solveData, (SolveType));

        if (solveType == SolveType.ORIUS_REDEEM) {
            _oriusRedeemSolve(solveData, oriusVault, solveAsset, totalShares, requiredAssets);
        } else if (solveType == SolveType.ORIUS_REDEEM_MINT) {
            _oriusRedeemMintSolve(solveData, oriusVault, solveAsset, totalShares, requiredAssets);
        } else {
            // Added for future protection, if another enum is added, txs with that enum will revert,
            // if no changes are made here.
            revert OriusSolver___FailedToSolve();
        }
    }

    //============================== INTERNAL SOLVE FUNCTIONS ===============================

    /**
     * @notice Internal helper function to solve multiple user requests to redeem Orius Vault shares.
     */
    function _oriusRedeemSolve(
        bytes calldata solveData,
        address oriusVault,
        address solveAsset,
        uint256 totalShares,
        uint256 requiredAssets
    ) internal {
        (, address solverOrigin, TellerWithMultiAssetSupport teller, bool excessToSolver) =
            abi.decode(solveData, (SolveType, address, TellerWithMultiAssetSupport, bool));

        if (oriusVault != address(teller.vault())) {
            revert OriusSolver___OriusVaultTellerMismatch(oriusVault, address(teller));
        }

        ERC20 asset = ERC20(solveAsset);
        // Redeem the Orius Vault shares for Solve Asset.
        uint256 assetsOut = teller.bulkWithdraw(asset, totalShares, requiredAssets, address(this));

        // Transfer excess assets to solver origin or Orius Vault.
        // Assets are sent to solver to cover gas fees.
        // But if users are self solving, then the excess assets go to the Orius Vault.
        if (excessToSolver) {
            asset.safeTransfer(solverOrigin, assetsOut - requiredAssets);
        } else {
            asset.safeTransfer(oriusVault, assetsOut - requiredAssets);
        }

        // Approve Orius Queue to spend the required assets.
        asset.approve(address(queue), requiredAssets);
    }

    /**
     * @notice Internal helper function to solve multiple user requests to redeem Orius Vault shares and mint new Orius Vault shares.
     */
    function _oriusRedeemMintSolve(
        bytes calldata solveData,
        address fromOriusVault,
        address toOriusVault,
        uint256 totalShares,
        uint256 requiredShares
    ) internal {
        (
            ,
            address solverOrigin,
            TellerWithMultiAssetSupport fromTeller,
            TellerWithMultiAssetSupport toTeller,
            ERC20 intermediateAsset,
            bool excessToSolver
        ) = abi.decode(
            solveData, (SolveType, address, TellerWithMultiAssetSupport, TellerWithMultiAssetSupport, ERC20, bool)
        );

        if (fromOriusVault != address(fromTeller.vault())) {
            revert OriusSolver___OriusVaultTellerMismatch(fromOriusVault, address(fromTeller));
        }

        if (toOriusVault != address(toTeller.vault())) {
            revert OriusSolver___OriusVaultTellerMismatch(toOriusVault, address(toTeller));
        }

        // Redeem the fromOriusVault shares for Intermediate Asset.
        uint256 excessAssets = fromTeller.bulkWithdraw(intermediateAsset, totalShares, 0, address(this));
        {
            // Determine how many assets are needed to mint requiredAssets worth of toOriusVault shares.
            // Note mulDivUp is used to ensure we always mint enough assets to cover the requiredShares.
            uint256 assetsToMintRequiredShares = requiredShares.mulDivUp(
                toTeller.accountant().getRateInQuoteSafe(intermediateAsset), OriusOnChainQueue(queue).ONE_SHARE()
            );

            // Remove assetsToMintRequiredShares from excessAssets.
            excessAssets = excessAssets - assetsToMintRequiredShares;

            // Approve toOriusVault to spend the Intermediate Asset.
            intermediateAsset.safeApprove(toOriusVault, assetsToMintRequiredShares);

            // Mint to OriusVault shares using Intermediate Asset.
            toTeller.bulkDeposit(intermediateAsset, assetsToMintRequiredShares, requiredShares, address(this));
        }

        // Transfer excess assets to solver origin or Orius Vault.
        // Assets are sent to solver to cover gas fees.
        // But if users are self solving, then the excess assets go to the from Orius Vault.
        if (excessToSolver) {
            intermediateAsset.safeTransfer(solverOrigin, excessAssets);
        } else {
            intermediateAsset.safeTransfer(fromOriusVault, excessAssets);
        }

        // Approve Orius Queue to spend the required assets.
        ERC20(toOriusVault).approve(address(queue), requiredShares);
    }
}
