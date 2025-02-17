// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {DeployMinimalAccount} from "../script/DeployMinimalAcc.s.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {MinimumAccount} from "../src/MinimumAccount.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {SendPackedUserOp} from "../script/SendPackedUserOp.s.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IEntryPoint, PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/*//////////////////////////////////////////////////////////////
                                TESTING
    //////////////////////////////////////////////////////////////*/

contract MinimumAccountTest is Test {
    using MessageHashUtils for bytes32;

    ERC20Mock usdc;
    MinimumAccount minimumAccount;
    HelperConfig helperConfig;
    uint256 constant MINT_AMOUNT = 1e18 * 2;
    SendPackedUserOp sendPackedUserOp;

    function setUp() public {
        DeployMinimalAccount deployMinimalAccount = new DeployMinimalAccount();
        (helperConfig, minimumAccount) = deployMinimalAccount.deployMinimalAccount();
        usdc = new ERC20Mock();
        sendPackedUserOp = new SendPackedUserOp();
    }

    function testOwnerCanExecuteCommands() public {
        assertEq(usdc.balanceOf(address(minimumAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory funcData = abi.encodeWithSelector(usdc.mint.selector, address(minimumAccount), MINT_AMOUNT);
        vm.prank(minimumAccount.owner());
        minimumAccount.execute(dest, value, funcData);
        assertEq(usdc.balanceOf(address(minimumAccount)), MINT_AMOUNT);
    }

    function testNonOwnerCannotExecuteCommands() public {
        assertEq(usdc.balanceOf(address(minimumAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory funcData = abi.encodeWithSelector(usdc.mint.selector, address(minimumAccount), MINT_AMOUNT);
        vm.prank(address(8));
        vm.expectRevert(MinimumAccount.MinimumAccount__NOT_ENTRY_POINT_OR_OWNER.selector);
        minimumAccount.execute(dest, value, funcData);
    }

    function testRecoverSignedOp() public {
        assertEq(usdc.balanceOf(address(minimumAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory funcData = abi.encodeWithSelector(usdc.mint.selector, address(minimumAccount), MINT_AMOUNT);
        bytes memory executionData = abi.encodeWithSelector(minimumAccount.execute.selector, dest, value, funcData);
        PackedUserOperation memory packedUserOps = sendPackedUserOp.generateSignedUserOperation(
            helperConfig.getConfig(), executionData, address(minimumAccount)
        );

        bytes32 userOpsHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(packedUserOps);
        //Act
        address actualSigner = ECDSA.recover(userOpsHash.toEthSignedMessageHash(), packedUserOps.signature);
        //assert
        assertEq(actualSigner, minimumAccount.owner());
    }

    function testValidationOfUserOps() public {
        assertEq(usdc.balanceOf(address(minimumAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory funcData = abi.encodeWithSelector(usdc.mint.selector, address(minimumAccount), MINT_AMOUNT);
        bytes memory executionData = abi.encodeWithSelector(minimumAccount.execute.selector, dest, value, funcData);
        PackedUserOperation memory packedUserOps = sendPackedUserOp.generateSignedUserOperation(
            helperConfig.getConfig(), executionData, address(minimumAccount)
        );
        bytes32 userOpsHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(packedUserOps);
        vm.prank(helperConfig.getConfig().entryPoint);
        uint256 validationData = minimumAccount.validateUserOp(packedUserOps, userOpsHash, 1e18);
        assertEq(validationData, 0);
    }

    function testEntryPointCanExecuteCommand() public {
        assertEq(usdc.balanceOf(address(minimumAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory funcData = abi.encodeWithSelector(usdc.mint.selector, address(minimumAccount), MINT_AMOUNT);
        bytes memory executionData = abi.encodeWithSelector(minimumAccount.execute.selector, dest, value, funcData);
        PackedUserOperation memory packedUserOps = sendPackedUserOp.generateSignedUserOperation(
            helperConfig.getConfig(), executionData, address(minimumAccount)
        );
        bytes32 userOpsHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(packedUserOps);

        vm.deal(address(minimumAccount), 1e18);
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = packedUserOps;
        vm.prank(address(4));
        IEntryPoint(helperConfig.getConfig().entryPoint).handleOps(ops, payable(address(4)));
        assertEq(usdc.balanceOf(address(minimumAccount)), MINT_AMOUNT);
    }
}
