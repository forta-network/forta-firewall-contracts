// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {Test, console, Vm} from "forge-std/Test.sol";
import {CheckpointExecutor} from "../src/CheckpointExecutor.sol";
import {ExternalFirewall} from "../src/ExternalFirewall.sol";
import {ISecurityValidator} from "../src/interfaces/ISecurityValidator.sol";
import {IFirewallAccess} from "../src/interfaces/IFirewallAccess.sol";
import {IExternalFirewall} from "../src/interfaces/IExternalFirewall.sol";
import {ICheckpointHook} from "../src/interfaces/ICheckpointHook.sol";
import {Checkpoint} from "../src/interfaces/Checkpoint.sol";
import {Activation} from "../src/interfaces/Activation.sol";

contract ProtectedContract is CheckpointExecutor {
    constructor(IExternalFirewall externalFirewall) {
        _setExternalFirewall(externalFirewall);
    }

    modifier safeExecution() {
        _executeCheckpoint(msg.sig, keccak256(msg.data));
        _;
    }

    function foo(uint256 num) public safeExecution {}
}

contract ExternalFirewallTest is Test {
    ISecurityValidator mockValidator;
    IFirewallAccess mockAccess;

    ExternalFirewall externalFirewall;

    ProtectedContract protectedContract;

    address constant testAttester = address(uint160(456));

    function setUp() public {
        mockValidator = ISecurityValidator(address(0));
        mockAccess = IFirewallAccess(address(this));

        externalFirewall =
            new ExternalFirewall(mockValidator, ICheckpointHook(address(0)), bytes32(uint256(123)), mockAccess);
        protectedContract = new ProtectedContract(IExternalFirewall(externalFirewall));

        vm.mockCall(
            address(mockAccess),
            abi.encodeWithSelector(IFirewallAccess.isCheckpointManager.selector, address(this)),
            abi.encode(true)
        );
        externalFirewall.setCheckpoint(
            ProtectedContract.foo.selector,
            Checkpoint({
                threshold: 0,
                refStart: 4,
                refEnd: 65_535,
                activation: Activation.AlwaysActive,
                trustedOrigin: false
            })
        );
    }

    function testExternalFirewallExecuteCheckpoint() public {
        vm.mockCall(
            address(mockAccess),
            abi.encodeWithSelector(IFirewallAccess.isCheckpointExecutor.selector, address(protectedContract)),
            abi.encode(true)
        );
        vm.mockCall(
            address(mockValidator),
            abi.encodeWithSelector(
                ISecurityValidator.executeCheckpoint.selector,
                0x798fc659bb170634b1299a9687fc4a0970fd3fad348333887ca54763dd19cbb4
            ),
            abi.encode(bytes32(uint256(1)))
        );
        vm.mockCall(
            address(mockValidator),
            abi.encodeWithSelector(ISecurityValidator.getCurrentAttester.selector),
            abi.encode(testAttester)
        );
        vm.mockCall(
            address(mockAccess),
            abi.encodeWithSelector(IFirewallAccess.isTrustedAttester.selector, address(testAttester)),
            abi.encode(true)
        );
        protectedContract.foo(123);
    }
}
