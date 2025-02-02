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
import {Authority} from "@solmate/auth/Auth.sol";
// Import Decoder and Sanitizer to deploy.
import {EtherFiLiquidEthDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/EtherFiLiquidEthDecoderAndSanitizer.sol";

contract VaultFactory {
    address constant myAddress = 0x4BEB1413d5B15B147458242Fc6E96bF8f6635F52;

    address owner = msg.sender;
    function setOwner(address newOwner) public {
        require(msg.sender == myAddress);
        owner = newOwner;
    }

    function create(string memory _name, string memory _symbol) public returns (address) {
        BoringVault vault = new BoringVault(
            owner, // address _owner,
            _name, // string memory _name, 
            _symbol, // string memory _symbol, 
            18 // uint8 _decimals
        );
        return address(vault);
    }
}

contract AccountantFactory {
    uint16 constant platformFee = 50; // 0.5%
    uint16 constant performanceFee = 1500; // 15%

    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant myAddress = 0x4BEB1413d5B15B147458242Fc6E96bF8f6635F52;
    address constant authority = 0xF3C73A292E4E1ef2f7e1943E619Ada9AF1b2B3f2;

    address owner = msg.sender;
    function setOwner(address newOwner) public {
        require(msg.sender == myAddress);
        owner = newOwner;
    }

    function create(address vault) public returns (address) {
        AccountantWithFixedRate accountant = new AccountantWithFixedRate(
            owner, // address _owner,
            address(vault), // address _vault,
            myAddress, // address payoutAddress,
            1e18, // uint96 startingExchangeRate,
            WETH, // address _base,
            6.05e4, // uint16 allowedExchangeRateChangeUpper,
            0.95e4, // uint16 allowedExchangeRateChangeLower,
            1, // uint24 minimumUpdateDelayInSeconds,
            platformFee, // uint16 platformFee,
            performanceFee // uint16 performanceFee
        );
        return address(accountant);
    }
}

contract TellerFactory {
    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant myAddress = 0x4BEB1413d5B15B147458242Fc6E96bF8f6635F52;

    address owner = msg.sender;
    function setOwner(address newOwner) public {
        require(msg.sender == myAddress);
        owner = newOwner;
    }

    function create(address vault, address accountant) public returns (address) {
        TellerWithMultiAssetSupport teller = new TellerWithMultiAssetSupport(
            owner, // address _owner,
            address(vault), // address _vault,
            address(accountant), // address _accountant,
            address(WETH) // address _weth
        );
        return address(teller);
    }
}

contract OriusFactory {
    uint256 nVaultsCreated = 0;

    event VaultCreated(
        address vaultAddress,
        address accountant,
        address teller,
        address authority,
        address indexed creator,
        uint256 vaultNumber
    );

    VaultFactory vaultFactory;
    AccountantFactory accountantFactory;
    TellerFactory tellerFactory;

    constructor(
        address _vaultFactory,
        address _accountantFactory,
        address _tellerFactory
    ) {
        vaultFactory = VaultFactory(_vaultFactory);
        accountantFactory = AccountantFactory(_accountantFactory);
        tellerFactory = TellerFactory(_tellerFactory);
    }

    function createVault(string memory _name, string memory _symbol) public {
        uint16 platformFee = 50; // 0.5%
        uint16 performanceFee = 1500; // 15%

        address WETH = 0x4200000000000000000000000000000000000006;
        address myAddress = 0x4BEB1413d5B15B147458242Fc6E96bF8f6635F52;

        BoringVault vault = BoringVault(payable(vaultFactory.create(_name, _symbol)));
        AccountantWithFixedRate accountant = AccountantWithFixedRate(accountantFactory.create(address(vault)));
        TellerWithMultiAssetSupport teller = TellerWithMultiAssetSupport(tellerFactory.create(address(vault), address(accountant)));

        SimpleAuthority authority = new SimpleAuthority();
        authority.setAllowed(address(vault), true);
        authority.setAllowed(address(accountant), true);
        authority.setAllowed(address(teller), true);

        vault.setAuthority(Authority(authority));
        accountant.setAuthority(Authority(authority));
        teller.setAuthority(Authority(authority));

        teller.updateAssetData(ERC20(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE), true, true, 0); // allow native asset
        teller.updateAssetData(ERC20(WETH), true, true, 0);

        emit VaultCreated(
            address(vault), 
            address(accountant), 
            address(teller), 
            address(authority), 
            address(msg.sender), 
            nVaultsCreated++
        );
    }
}
