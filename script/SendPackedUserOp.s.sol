// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract SendPackedUserOp is Script {
    using MessageHashUtils for bytes32;

    uint256 constant ANVIL_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    function run() public {}

    function generateSignedUserOperation(
        HelperConfig.NetworkConfig memory config,
        bytes memory callData,
        address minimumAccount
    ) public returns (PackedUserOperation memory) {
        // 1.Generate unsigned data
        uint256 nonce = vm.getNonce(config.account) - 2;
        PackedUserOperation memory unSignedUserOperation =
            _generateUnsignedUserOperation(minimumAccount, nonce, callData);
        // 2. get userop

        bytes32 userOpHash = IEntryPoint(config.entryPoint).getUserOpHash(unSignedUserOperation);
        bytes32 digest = userOpHash.toEthSignedMessageHash();
        // 3.sign it
        uint8 v;
        bytes32 r;
        bytes32 s;
        if (block.chainid == 31337) {
            (v, r, s) = vm.sign(ANVIL_PRIVATE_KEY, digest);
        } else {
            (v, r, s) = vm.sign(config.account, digest);
        }

        unSignedUserOperation.signature = abi.encodePacked(r, s, v);
        return unSignedUserOperation; //actually signed
    }

    function _generateUnsignedUserOperation(address sender, uint256 nonce, bytes memory callData)
        public
        returns (PackedUserOperation memory)
    {
        uint128 verificationGasLimit = 16777216;
        uint128 callGasLimit = verificationGasLimit;
        uint128 maxPriorityFeePerGas = 256;
        uint128 maxFeePerGas = maxPriorityFeePerGas;
        return PackedUserOperation({
            sender: sender,
            nonce: nonce,
            initCode: hex"",
            callData: callData,
            accountGasLimits: bytes32(uint256(verificationGasLimit) << 128 | callGasLimit),
            preVerificationGas: verificationGasLimit,
            gasFees: bytes32(uint256(maxPriorityFeePerGas) << 128 | maxFeePerGas),
            paymasterAndData: hex"",
            signature: hex""
        });
    }
}
