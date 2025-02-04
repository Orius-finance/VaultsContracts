// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {OriusVault} from "src/base/OriusVault.sol";
import {DeployArcticArchitecture, ERC20, Deployer} from "script/ArchitectureDeployments/DeployArcticArchitecture.sol";
import {AddressToBytes32Lib} from "src/helper/AddressToBytes32Lib.sol";
import {ChainValues} from "test/resources/ChainValues.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {AccountantWithFixedRate} from "src/base/Roles/AccountantWithFixedRate.sol";
import {SimpleAuthority} from "src/SimpleAuthority.sol";
import {Authority} from "@solmate/auth/Auth.sol";
// Import Decoder and Sanitizer to deploy.
import {EtherFiLiquidEthDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/EtherFiLiquidEthDecoderAndSanitizer.sol";

/**
 * source .env && forge script script/DeploySimple.s.sol:DeploySimple --evm-version london --broadcast --etherscan-api-key $BASESCAN_KEY --verify
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeploySimple is Script {
    using AddressToBytes32Lib for address;

    function run() external {
        vm.startBroadcast();

        uint16 platformFee = 0.01e4;
        uint16 performanceFee = 0.2e4;

        address WETH = 0x4200000000000000000000000000000000000006;
        address myAddress = 0x4BEB1413d5B15B147458242Fc6E96bF8f6635F52;

        OriusVault vault = OriusVault(payable(0xE22743990af80f48170f0360DA9387C9221c9d13));
        AccountantWithFixedRate accountant = AccountantWithFixedRate(address(0xDB6D48e3172Caff95903e7403D4041B4C2FE7858));
        TellerWithMultiAssetSupport teller = TellerWithMultiAssetSupport(address(0x63ACb8C6476c68231fDb78Ef9B342FF4FE53E356));
        Authority authority = Authority(address(0x0fe1166a6B4396567bd088222537533Bb698f4cE));

        // teller.setAuthority(Authority(authority));
        // vault.setAuthority(Authority(authority));

        // teller.updateAssetData(ERC20(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE), true, true, 0);
        uint depositAmount = 0.00001 ether;
        // teller.deposit{value: depositAmount}(
        //     ERC20(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE),
        //     depositAmount, 
        //     0 // minimum mint
        // );

        address[] memory targets = new address[](1);
        targets[0] = 0x4200000000000000000000000000000000000006;
        
        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeWithSelector(0xa9059cbb, myAddress, 0.000001 ether);
        uint256[] memory values = new uint[](1);
        values[0] = 0 ether;

        vault.manage(
            targets, // address[] calldata targets, 
            data, // bytes[] calldata data, 
            values // uint256[] calldata values
        );

        vm.stopBroadcast();
    }
}
