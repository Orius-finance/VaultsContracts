// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract OriusDecoderAndSanitizer {
    //============================== IMMUTABLES ===============================

    /**
     * @notice The OriusVault contract address.
     */
    address internal immutable oriusVault;

    constructor(address _oriusVault) {
        oriusVault = _oriusVault;
    }

    function approve(address spender, uint256) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(spender);
    }
}
