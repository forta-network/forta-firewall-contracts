// SPDX-License-Identifier: GNU General Public License Version 3
// See license at: https://github.com/forta-network/forta-firewall-contracts/blob/master/LICENSE-GPLv3.md
pragma solidity ^0.8.25;

import {Test, console, Vm} from "forge-std/Test.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IEVC, EthereumVaultConnector} from "evc/EthereumVaultConnector.sol";
import "./helpers/DummyVault.sol";
import {SecurityValidator, BYPASS_FLAG} from "../src/SecurityValidator.sol";
import {Quantization} from "../src/Quantization.sol";
import "../src/interfaces/Checkpoint.sol";
import "../src/interfaces/FirewallDependencies.sol";
import "../src/TrustedAttesters.sol";
import "../src/interfaces/ITrustedAttesters.sol";

contract SecurityValidatorTest is Test {
    using Quantization for uint256;

    uint256 attesterPrivateKey;
    address attester;
    uint256 userPrivateKey;
    address user;
    uint256 otherUserPrivateKey;
    address otherUser;

    SecurityValidator validator;
    IEVC evc;
    DummyVault vault;
    TrustedAttesters trustedAttesters;

    Attestation attestation;
    bytes attestationSignature;

    bytes32 executionHash1;
    bytes32 executionHash2;

    function setUp() public {
        attesterPrivateKey = vm.parseUint("0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80");
        attester = vm.addr(attesterPrivateKey);
        userPrivateKey = uint256(keccak256("user"));
        user = vm.addr(userPrivateKey);
        otherUserPrivateKey = uint256(keccak256("otherUser"));
        otherUser = vm.addr(otherUserPrivateKey);

        trustedAttesters = new TrustedAttesters(address(this));
        trustedAttesters.grantRole(ATTESTER_MANAGER_ROLE, address(this));
        trustedAttesters.grantRole(TRUSTED_ATTESTER_ROLE, address(attester));

        validator = new SecurityValidator(ITrustedAttesters(trustedAttesters));
        evc = new EthereumVaultConnector();
        vault = new DummyVault(ISecurityValidator(address(validator)));

        /// very large - in seconds
        attestation.deadline = 1000000000;

        _computeAttestationHashes(address(vault));
        _signAttestation();
    }

    function _computeAttestationHashes(address caller) public {
        uint256 ref1 = 123;
        bytes32 checkpointHash1 =
            keccak256(abi.encode(address(evc), address(vault), DummyVault.doFirst.selector, ref1.quantize()));
        executionHash1 = validator.executionHashFrom(checkpointHash1, caller, bytes32(uint256(0)));

        uint256 ref2 = 456;
        bytes32 checkpointHash2 =
            keccak256(abi.encode(address(evc), address(vault), DummyVault.doSecond.selector, ref2.quantize()));
        executionHash2 = validator.executionHashFrom(checkpointHash2, caller, executionHash1);

        attestation.executionHashes = new bytes32[](2);
        attestation.executionHashes[0] = executionHash1;
        attestation.executionHashes[1] = executionHash2;
    }

    function _signAttestation() internal {
        bytes32 hashOfAttestation = validator.hashAttestation(attestation);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(attesterPrivateKey, hashOfAttestation);
        attestationSignature = abi.encodePacked(r, s, v);
    }

    function test_attestedEVCBatch() public {
        IEVC.BatchItem[] memory batch = new IEVC.BatchItem[](3);

        /// Save the attestation first.
        batch[0] = IEVC.BatchItem({
            targetContract: address(validator),
            onBehalfOfAccount: user,
            value: 0,
            data: abi.encodeWithSelector(SecurityValidator.saveAttestation.selector, attestation, attestationSignature)
        });

        /// Call the first vault function.
        batch[1] = IEVC.BatchItem({
            targetContract: address(vault),
            onBehalfOfAccount: user,
            value: 0,
            data: abi.encodeWithSelector(DummyVault.doFirst.selector, 123)
        });

        /// Call the second vault function.
        batch[2] = IEVC.BatchItem({
            targetContract: address(vault),
            onBehalfOfAccount: user,
            value: 0,
            data: abi.encodeWithSelector(DummyVault.doSecond.selector, 456)
        });

        vm.broadcast(userPrivateKey);
        evc.batch(batch);
    }

    function test_attestedEVCBatch_overwrite() public {
        IEVC.BatchItem[] memory batch = new IEVC.BatchItem[](4);

        /// Save the attestation first.
        batch[0] = IEVC.BatchItem({
            targetContract: address(validator),
            onBehalfOfAccount: user,
            value: 0,
            data: abi.encodeWithSelector(SecurityValidator.saveAttestation.selector, attestation, attestationSignature)
        });

        // Save the attestation again.
        batch[1] = IEVC.BatchItem({
            targetContract: address(validator),
            onBehalfOfAccount: user,
            value: 0,
            data: abi.encodeWithSelector(SecurityValidator.saveAttestation.selector, attestation, attestationSignature)
        });

        /// Call the first vault function.
        batch[2] = IEVC.BatchItem({
            targetContract: address(vault),
            onBehalfOfAccount: user,
            value: 0,
            data: abi.encodeWithSelector(DummyVault.doFirst.selector, 123)
        });

        /// Call the second vault function.
        batch[3] = IEVC.BatchItem({
            targetContract: address(vault),
            onBehalfOfAccount: user,
            value: 0,
            data: abi.encodeWithSelector(DummyVault.doSecond.selector, 456)
        });

        vm.expectRevert();
        vm.broadcast(userPrivateKey);
        evc.batch(batch);
    }

    function test_attestedEVCBatch_twoTx() public {
        vm.broadcast(userPrivateKey);
        /// Store the attestation in the first transaction.
        validator.storeAttestation(attestation, attestationSignature);

        IEVC.BatchItem[] memory batch = new IEVC.BatchItem[](2);

        /// Exclude the attestation from the batch.

        /// Call the first vault function.
        batch[0] = IEVC.BatchItem({
            targetContract: address(vault),
            onBehalfOfAccount: user,
            value: 0,
            data: abi.encodeWithSelector(DummyVault.doFirst.selector, 123)
        });

        /// Call the second vault function.
        batch[1] = IEVC.BatchItem({
            targetContract: address(vault),
            onBehalfOfAccount: user,
            value: 0,
            data: abi.encodeWithSelector(DummyVault.doSecond.selector, 456)
        });

        /// Send the batch - it should be able to use the attestation from the first tx.
        vm.broadcast(userPrivateKey);
        evc.batch(batch);

        /// The second try should fail as there are no attestations anymore.
        vm.expectRevert();
        evc.batch(batch);
    }

    function test_attestedEVCBatch_twoTx_storeForOrigin() public {
        vm.broadcast(attesterPrivateKey);
        /// Store the attestation in the first transaction.
        validator.storeAttestationForOrigin(attestation, attestationSignature, user);

        IEVC.BatchItem[] memory batch = new IEVC.BatchItem[](2);

        /// Exclude the attestation from the batch.

        /// Call the first vault function.
        batch[0] = IEVC.BatchItem({
            targetContract: address(vault),
            onBehalfOfAccount: user,
            value: 0,
            data: abi.encodeWithSelector(DummyVault.doFirst.selector, 123)
        });

        /// Call the second vault function.
        batch[1] = IEVC.BatchItem({
            targetContract: address(vault),
            onBehalfOfAccount: user,
            value: 0,
            data: abi.encodeWithSelector(DummyVault.doSecond.selector, 456)
        });

        /// Send the batch - it should be able to use the attestation from the first tx.
        vm.broadcast(userPrivateKey);
        evc.batch(batch);

        /// The second try should fail as there are no attestations anymore.
        vm.expectRevert();
        evc.batch(batch);
    }

    function test_attestedEVCBatch_storeSaveExecute() public {
        vm.broadcast(userPrivateKey);
        /// Store the attestation in the first transaction.
        validator.storeAttestation(attestation, attestationSignature);

        IEVC.BatchItem[] memory batch = new IEVC.BatchItem[](5);

        /// Inlcude the same attestation in the batch and execute real batch items twice.

        /// Save the attestation first.
        batch[0] = IEVC.BatchItem({
            targetContract: address(validator),
            onBehalfOfAccount: user,
            value: 0,
            data: abi.encodeWithSelector(SecurityValidator.saveAttestation.selector, attestation, attestationSignature)
        });

        /// Call the first vault function.
        batch[1] = IEVC.BatchItem({
            targetContract: address(vault),
            onBehalfOfAccount: user,
            value: 0,
            data: abi.encodeWithSelector(DummyVault.doFirst.selector, 123)
        });

        /// Call the second vault function.
        batch[2] = IEVC.BatchItem({
            targetContract: address(vault),
            onBehalfOfAccount: user,
            value: 0,
            data: abi.encodeWithSelector(DummyVault.doSecond.selector, 456)
        });

        /// Call the first vault function again.
        batch[3] = IEVC.BatchItem({
            targetContract: address(vault),
            onBehalfOfAccount: user,
            value: 0,
            data: abi.encodeWithSelector(DummyVault.doFirst.selector, 123)
        });

        /// Call the second vault function again.
        batch[4] = IEVC.BatchItem({
            targetContract: address(vault),
            onBehalfOfAccount: user,
            value: 0,
            data: abi.encodeWithSelector(DummyVault.doSecond.selector, 456)
        });

        /// Send the batch - it should be able to use the attestation in the batch and then
        /// from the first tx.
        vm.broadcast(userPrivateKey);
        evc.batch(batch);
    }

    function test_attestedEVCBatch_twoTx_overwrite() public {
        /// Store the attestation in the first transaction.
        vm.broadcast(userPrivateKey);
        validator.storeAttestation(attestation, attestationSignature);

        // Store the attestation for the second time: it should fail because it's an overwrite.
        vm.expectRevert();
        vm.broadcast(userPrivateKey);
        validator.storeAttestation(attestation, attestationSignature);
    }

    function test_attestedEVCBatch_twoTx_overwriteSave() public {
        /// Store the attestation in the first transaction.
        vm.broadcast(userPrivateKey);
        validator.storeAttestation(attestation, attestationSignature);

        IEVC.BatchItem[] memory batch = new IEVC.BatchItem[](3);

        /// Call the first vault function.
        batch[0] = IEVC.BatchItem({
            targetContract: address(vault),
            onBehalfOfAccount: user,
            value: 0,
            data: abi.encodeWithSelector(DummyVault.doFirst.selector, 123)
        });

        // Saving an attestation should fail because there is an active and unfinished attestation.
        batch[1] = IEVC.BatchItem({
            targetContract: address(validator),
            onBehalfOfAccount: user,
            value: 0,
            data: abi.encodeWithSelector(SecurityValidator.saveAttestation.selector, attestation, attestationSignature)
        });

        /// Call the second vault function.
        batch[2] = IEVC.BatchItem({
            targetContract: address(vault),
            onBehalfOfAccount: user,
            value: 0,
            data: abi.encodeWithSelector(DummyVault.doSecond.selector, 456)
        });

        vm.expectRevert();
        vm.broadcast(userPrivateKey);
        evc.batch(batch);
    }

    function test_attestedEVCBatch_saveAfterFinished() public {
        IEVC.BatchItem[] memory batch = new IEVC.BatchItem[](4);

        /// Save the attestation first.
        batch[0] = IEVC.BatchItem({
            targetContract: address(validator),
            onBehalfOfAccount: user,
            value: 0,
            data: abi.encodeWithSelector(SecurityValidator.saveAttestation.selector, attestation, attestationSignature)
        });

        /// Call the first vault function.
        batch[1] = IEVC.BatchItem({
            targetContract: address(vault),
            onBehalfOfAccount: user,
            value: 0,
            data: abi.encodeWithSelector(DummyVault.doFirst.selector, 123)
        });

        /// Call the second vault function.
        batch[2] = IEVC.BatchItem({
            targetContract: address(vault),
            onBehalfOfAccount: user,
            value: 0,
            data: abi.encodeWithSelector(DummyVault.doSecond.selector, 456)
        });

        // Save the attestation again - it should work since the previous was fully consumed.
        batch[3] = IEVC.BatchItem({
            targetContract: address(validator),
            onBehalfOfAccount: user,
            value: 0,
            data: abi.encodeWithSelector(SecurityValidator.saveAttestation.selector, attestation, attestationSignature)
        });

        vm.broadcast(userPrivateKey);
        evc.batch(batch);
    }

    function test_bypassFlag() public {
        IEVC.BatchItem[] memory batch = new IEVC.BatchItem[](2);

        /// Skip attestation.

        /// Call the first vault function.
        batch[0] = IEVC.BatchItem({
            targetContract: address(vault),
            onBehalfOfAccount: user,
            value: 0,
            data: abi.encodeWithSelector(DummyVault.doFirst.selector, 123)
        });

        /// Call the second vault function.
        batch[1] = IEVC.BatchItem({
            targetContract: address(vault),
            onBehalfOfAccount: user,
            value: 0,
            data: abi.encodeWithSelector(DummyVault.doSecond.selector, 456)
        });

        /// Avoid revert without attestation by using the bypass flag.
        /// This useful for the attester when it tries to capture execution hashes from trace
        /// by using a state override.
        vm.etch(BYPASS_FLAG, bytes("1"));
        vm.recordLogs();
        vm.broadcast(userPrivateKey);
        evc.batch(batch);
    }

    function test_validationFailure() public {
        IEVC.BatchItem[] memory batch = new IEVC.BatchItem[](2);

        /// Save the attestation first.
        batch[0] = IEVC.BatchItem({
            targetContract: address(validator),
            onBehalfOfAccount: user,
            value: 0,
            data: abi.encodeWithSelector(SecurityValidator.saveAttestation.selector, attestation, attestationSignature)
        });

        /// Call the second vault function only.
        batch[1] = IEVC.BatchItem({
            targetContract: address(vault),
            onBehalfOfAccount: user,
            value: 0,
            data: abi.encodeWithSelector(DummyVault.doSecond.selector, 456)
        });

        vm.broadcast(userPrivateKey);
        bytes32 expectedHash = 0x4c09b2b277b76e9cb03821213d6233db07a068297fdde52bd66c313b6dfdd2cb;
        bytes32 computedHash = 0x61ef62ddde88dd8f814f90d380304decab34c76e0b80d30b61d7f13edc0947f6;
        vm.expectRevert(
            abi.encodeWithSelector(
                SecurityValidator.InvalidExecutionHash.selector, address(validator), expectedHash, computedHash
            )
        );
        evc.batch(batch);
    }

    function test_attestationGas_saveAttestation() public {
        _computeAttestationHashes(address(vault));
        _signAttestation();

        vm.startPrank(address(evc), user);
        validator.saveAttestation(attestation, attestationSignature);
        vault.doFirst(123);
        vault.doSecond(456);

        vm.stopPrank();
    }

    function test_attestationGas_storeAttestation() public {
        _computeAttestationHashes(address(vault));
        _signAttestation();

        vm.startPrank(address(evc), user);
        validator.storeAttestation(attestation, attestationSignature);

        vm.stopPrank();
    }
}
