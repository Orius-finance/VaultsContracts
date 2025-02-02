// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {DeployArcticArchitecture, ERC20, Deployer} from "script/ArchitectureDeployments/DeployArcticArchitecture.sol";
import {AddressToBytes32Lib} from "src/helper/AddressToBytes32Lib.sol";
import {ChainValues} from "test/resources/ChainValues.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {AccountantWithFixedRate} from "src/base/Roles/AccountantWithFixedRate.sol";
import {SimpleAuthority} from "src/SimpleAuthority.sol";
import {OriusFactory, VaultFactory, AccountantFactory, TellerFactory} from "src/OriusFactory.sol";
import {Authority} from "@solmate/auth/Auth.sol";
// Import Decoder and Sanitizer to deploy.
import {EtherFiLiquidEthDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/EtherFiLiquidEthDecoderAndSanitizer.sol";

/**
 * source .env && forge script script/DeployFactory.s.sol:DeployFactory --evm-version london --broadcast --etherscan-api-key $BASESCAN_KEY --verify
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeployFactory is Script {
    using AddressToBytes32Lib for address;

    function run() external {
        vm.startBroadcast();

        // SimpleAuthority authority = SimpleAuthority(0xF3C73A292E4E1ef2f7e1943E619Ada9AF1b2B3f2);

        VaultFactory vaultFactory = VaultFactory(0xC2C181f803E4717F188abeB0c2601992871aFCac);
        AccountantFactory accountantFactory = AccountantFactory(0xd2BFbA64e1Dd4fECA038e8829B11ff9f655521D1);
        TellerFactory tellerFactory = TellerFactory(0x322825F1Dc8407AB882E53e99669EdDfcF2bC632);

        OriusFactory factory = OriusFactory(0xC8E9CF4736d93783e2604C4f5a6b923952f44338);
        // OriusFactory factory = new OriusFactory(
        //     address(vaultFactory),
        //     address(accountantFactory),
        //     address(tellerFactory)
        // );
        // vaultFactory.setOwner(address(factory));
        // accountantFactory.setOwner(address(factory));
        // tellerFactory.setOwner(address(factory));
        // authority.setAllowed(address(factory), true);

        // vaultFactory.create("Valt", "SM");

        factory.createVault("Valt", "Simbol");

        // address[] memory targets = new address[](1);
        // targets[0] = 0x4200000000000000000000000000000000000006;
        
        // bytes[] memory data = new bytes[](1);
        // data[0] = abi.encodeWithSelector(0xa9059cbb, myAddress, 0.000001 ether);
        // // vm.parseBytes(string.concat(
        // //     "0xa9059cbb",
        // //     "0000000000000000000000004BEB1413d5B15B147458242Fc6E96bF8f6635F52",
        // //     ""
        // // ));

        // uint256[] memory values = new uint[](1);
        // values[0] = 0 ether;

        // vault.manage(
        //     targets, // address[] calldata targets, 
        //     data, // bytes[] calldata data, 
        //     values // uint256[] calldata values
        // );

        vm.stopBroadcast();
    }
}
