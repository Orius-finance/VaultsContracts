// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.21;

import {DeployArcticArchitecture, ERC20, Deployer} from "script/ArchitectureDeployments/DeployArcticArchitecture.sol";
import {OriusGovernance} from "src/base/Governance/OriusGovernance.sol";
import {AddressToBytes32Lib} from "src/helper/AddressToBytes32Lib.sol";
import {BaseAddresses} from "test/resources/BaseAddresses.sol";

// Import Decoder and Sanitizer to deploy.
import {EtherFiLiquidEthDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/EtherFiLiquidEthDecoderAndSanitizer.sol";

/**
 *  source .env && forge script script/ArchitectureDeployments/Base/DeployETHFIStaking.s.sol:DeployETHFIStakingScript --with-gas-price 40000000 --evm-version london --broadcast --etherscan-api-key $BASESCAN_KEY --verify
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeployETHFIStakingScript is DeployArcticArchitecture, BaseAddresses {
    using AddressToBytes32Lib for address;

    uint256 public privateKey;

    // Deployment parameters
    string public oriusVaultName = "Staked ETHFI";
    string public oriusVaultSymbol = "sETHFI";
    uint8 public oriusVaultDecimals = 18;
    address public owner = dev0Address;

    function setUp() external {
        privateKey = vm.envUint("ETHERFI_LIQUID_DEPLOYER");
        vm.createSelectFork("base");
    }

    function run() external {
        // Configure the deployment.
        configureDeployment.deployContracts = true;
        configureDeployment.setupRoles = true;
        configureDeployment.setupDepositAssets = true;
        configureDeployment.setupWithdrawAssets = true;
        configureDeployment.finishSetup = true;
        configureDeployment.setupTestUser = true;
        configureDeployment.saveDeploymentDetails = true;
        configureDeployment.deployerAddress = deployerAddress;
        configureDeployment.balancerVault = balancerVault;
        configureDeployment.WETH = address(WETH);

        // Set oriusCreationCode so we deploy OriusGovernance.
        oriusCreationCode = type(OriusGovernance).creationCode;

        // Save deployer.
        deployer = Deployer(configureDeployment.deployerAddress);

        // Define names to determine where contracts are deployed.
        names.rolesAuthority = StakedETHFIRolesAuthorityName;
        names.lens = ArcticArchitectureLensName;
        names .oriusVault = StakedETHFIName;
        names.manager = StakedETHFIManagerName;
        names.accountant = StakedETHFIAccountantName;
        names.teller = StakedETHFITellerName;
        names.rawDataDecoderAndSanitizer = StakedETHFIDecoderAndSanitizerName;
        names.delayedWithdrawer = StakedETHFIDelayedWithdrawer;

        // Define Accountant Parameters.
        accountantParameters.payoutAddress = liquidPayoutAddress;
        accountantParameters.base = ETHFI;
        // Decimals are in terms of `base`.
        accountantParameters.startingExchangeRate = 1e18;
        //  4 decimals
        accountantParameters.platformFee = 0;
        accountantParameters.performanceFee = 0;
        accountantParameters.allowedExchangeRateChangeLower = 0.995e4;
        accountantParameters.allowedExchangeRateChangeUpper = 1.005e4;
        // Minimum time(in seconds) to pass between updated without triggering a pause.
        accountantParameters.minimumUpateDelayInSeconds = 1 days / 4;

        // Define Decoder and Sanitizer deployment details.
        bytes memory creationCode = type(EtherFiLiquidEthDecoderAndSanitizer).creationCode;
        bytes memory constructorArgs =
            abi.encode(deployer.getAddress(names .oriusVault), uniswapV3NonFungiblePositionManager);

        // Setup withdraw assets.
        withdrawAssets.push(
            WithdrawAsset({
                asset: ETHFI,
                withdrawDelay: 3 days,
                completionWindow: 7 days,
                withdrawFee: 0,
                maxLoss: 0.01e4
            })
        );

        bool allowPublicDeposits = true;
        bool allowPublicWithdraws = false;
        uint64 shareLockPeriod = 1 days;
        address delayedWithdrawFeeAddress = liquidPayoutAddress;

        vm.startBroadcast(privateKey);

        _deploy(
            "Base/StakedETHFIDeployment.json",
            owner,
            oriusVaultName,
            oriusVaultSymbol,
            oriusVaultDecimals,
            creationCode,
            constructorArgs,
            delayedWithdrawFeeAddress,
            allowPublicDeposits,
            allowPublicWithdraws,
            shareLockPeriod,
            dev1Address
        );

        vm.stopBroadcast();

        // Make sure we actually deployed a OriusGovernance vault.
        require(
            address(OriusGovernance(payable(address(oriusVault))).shareLocker()) == address(0),
            "Share locker should not be set"
        );
    }
}
