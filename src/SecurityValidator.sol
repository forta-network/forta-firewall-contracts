// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import {StorageSlot} from "@openzeppelin/contracts/utils/StorageSlot.sol";

address constant BYPASS_FLAG = 0x0000000000000000000000000000000000f01274; // "forta" in leetspeak

/// @notice Set of values that enable execution of call(s)
struct Attestation {
    /// @notice Deadline UNIX timestamp
    uint256 deadline;
    /**
     * @notice Ordered hashes which should be produced at every checkpoint execution
     * in this contract. An attester uses these hashes to enable a specific execution
     * path.
     */
    bytes32[] executionHashes;
}

/// @notice Attestation data wrapped for storing.
struct StoredAttestation {
    /// @notice Wrapped attestation.
    Attestation attestation;
    /// @notice The attester which signed above attestation.
    address attester;
}

interface ISecurityValidator {
    function hashAttestation(Attestation calldata attestation) external view returns (bytes32);
    function getCurrentAttester() external view returns (address);

    function storeAttestation(Attestation calldata attestation, bytes calldata attestationSignature) external;
    function saveAttestation(Attestation calldata attestation, bytes calldata attestationSignature) external;

    function executeCheckpoint(bytes32 checkpointHash) external;
}

/**
 * @title Validator contract used for attestations
 * @notice A singleton to be used by attesters to enable execution and contracts to ensure
 * that execution was enabled by an attester.
 */
contract SecurityValidator is EIP712 {
    using StorageSlot for bytes32;

    error AttestationOverwrite();
    error AttestationDeadlineExceeded();
    error AttestationRequired();
    error HashCountExceeded(uint256 atIndex);
    error InvalidExecutionHash(address validator, bytes32 expectedHash, bytes32 computedHash);
    error InvalidAttestation();
    error AttestationNotFound();
    error EmptyAttestation();

    event CheckpointExecuted(address validator, bytes32 executionHash);

    /**
     * @notice Transient storage slots used for storing the attestation values
     * and executing checkpoints
     */
    bytes32 constant ATTESTER_SLOT = bytes32(uint256(0));
    bytes32 constant HASH_SLOT = bytes32(uint256(1));
    bytes32 constant HASH_COUNT_SLOT = bytes32(uint256(2));
    bytes32 constant HASH_CACHE_INDEX_SLOT = bytes32(uint256(3));
    uint256 constant HASH_CACHE_START_SLOT = 4;

    /// @notice Used for EIP-712 message hash calculation
    bytes32 private constant _ATTESTATION_TYPEHASH =
        keccak256("Attestation(uint256 deadline,bytes32[] executionHashes)");

    /**
     * @notice A mapping from first execution hashes to attestations.
     * This is useful for storing an attestation in a previous transaction.
     */
    mapping(bytes32 => StoredAttestation) attestations;

    constructor() EIP712("SecurityValidator", "1") {}

    /**
     * @notice An alternative that uses persistent storage instead of transient.
     * This function defers unpacking of an attestation to the transient storage.
     * @param attestation The set of fields that correspond to and enable the execution of call(s)
     * @param attestationSignature Signature of EIP-712 message
     */
    function storeAttestation(Attestation calldata attestation, bytes calldata attestationSignature) public {
        if (attestation.executionHashes.length == 0) revert EmptyAttestation();
        bytes32 firstExecHash = attestation.executionHashes[0];
        StoredAttestation storage storedAttestation = attestations[firstExecHash];
        if (storedAttestation.attestation.deadline > block.timestamp) {
            revert AttestationOverwrite();
        }
        storedAttestation.attestation = attestation;
        bytes32 structHash = hashAttestation(attestation);
        address attester = ECDSA.recover(structHash, attestationSignature);
        storedAttestation.attester = attester;
        attestations[firstExecHash] = storedAttestation;
    }

    /**
     * @notice Accepts and stores an attestation to the transient storage introduced
     * with EIP-1153. Multiple contracts that operate in the same transaction can call
     * a singleton of this contract. The stored values are later used during checkpoint
     * execution.
     * @param attestation The set of fields that correspond to and enable the execution of call(s)
     * @param attestationSignature Signature of EIP-712 message
     */
    function saveAttestation(Attestation calldata attestation, bytes calldata attestationSignature) public {
        bytes32 structHash = hashAttestation(attestation);
        address attester = ECDSA.recover(structHash, attestationSignature);

        // Avoid reentrancy: Make sure that we are starting from a zero state or after
        // a previous attestation has been used.
        _requireIdleOrDone();

        _initAttestation(attestation, attester);
    }

    /// @notice Returns the attester address which attested to the current execution
    function getCurrentAttester() public view returns (address) {
        return StorageSlot.tload(ATTESTER_SLOT.asAddress());
    }

    /**
     * @notice Produces the EIP-712 hash of the attestation message.
     * @param attestation The set of fields that correspond to and enable the execution of call(s)
     */
    function hashAttestation(Attestation calldata attestation) public view returns (bytes32) {
        return _hashTypedDataV4(
            keccak256(
                abi.encode(
                    _ATTESTATION_TYPEHASH,
                    attestation.deadline,
                    keccak256(abi.encodePacked(attestation.executionHashes))
                )
            )
        );
    }

    /**
     * @notice Computes an execution hash by using given arbitrary checkpoint hash, msg.sender
     * and the previous execution hash. Requires the computed execution hash to be equal to
     * the currently pointed execution hash from the attestation.
     *
     * @param checkpointHash An arbitrary hash which can be computed by using variety of values
     * that occur during a call
     */
    function executeCheckpoint(bytes32 checkpointHash) public {
        bytes32 executionHash = StorageSlot.tload(HASH_SLOT.asBytes32());
        executionHash = executionHashFrom(checkpointHash, msg.sender, executionHash);
        emit CheckpointExecuted(address(this), executionHash);

        /// If there is no attestation and the bypass flag is not used,
        /// then the transaction should revert.
        bool bypassed;
        if (uint160(getCurrentAttester()) == 0) {
            if (BYPASS_FLAG.code.length == 0) {
                /// In case the attestation was delivered in a previous transaction, it should
                /// be loaded from here.
                bool ok = _tryInitAttestationFromStorage(executionHash);
                /// No attestations from current tx or previous: revert
                if (!ok) revert AttestationRequired();
            } else {
                bypassed = true;
            }
        }

        uint256 cacheIndex = StorageSlot.tload(HASH_CACHE_INDEX_SLOT.asUint256());
        uint256 hashCount = StorageSlot.tload(HASH_COUNT_SLOT.asUint256());
        /// Current execution should not try to execute more checkpoints than attested to.
        if (!bypassed && cacheIndex >= hashCount) {
            revert HashCountExceeded(cacheIndex);
        }

        bytes32 cachedHashSlot = bytes32(cacheIndex + HASH_CACHE_START_SLOT);
        bytes32 cachedHash = StorageSlot.tload(cachedHashSlot.asBytes32());
        /// Computed hash should match with the hash that was attested to.
        if (!bypassed && executionHash != cachedHash) {
            revert InvalidExecutionHash(address(this), cachedHash, executionHash);
        }

        /// Point to the next hash from the attestation and store the latest computed
        /// hash along with the new index.
        cacheIndex++;
        StorageSlot.tstore(HASH_SLOT.asBytes32(), executionHash);
        StorageSlot.tstore(HASH_CACHE_INDEX_SLOT.asUint256(), cacheIndex);
    }

    /**
     * @notice Makes sure that the attestation matches with current transaction
     * and all checkpoints were used correctly.
     */
    function validateFinalState() public view {
        _requireIdleOrDone();
    }

    function _initAttestation(Attestation memory attestation, address attester) internal {
        if (block.timestamp > attestation.deadline) {
            revert AttestationDeadlineExceeded();
        }

        /// Initialize and empty transient storage.
        uint256 hashCount = attestation.executionHashes.length;
        StorageSlot.tstore(ATTESTER_SLOT.asAddress(), attester);
        StorageSlot.tstore(HASH_SLOT.asBytes32(), 0);
        StorageSlot.tstore(HASH_COUNT_SLOT.asUint256(), hashCount);
        StorageSlot.tstore(HASH_CACHE_INDEX_SLOT.asUint256(), 0);

        /// Store all execution hashes.
        for (uint256 i = 0; i < attestation.executionHashes.length; i++) {
            bytes32 execHash = attestation.executionHashes[i];
            bytes32 currIndex = bytes32(HASH_CACHE_START_SLOT + i);
            StorageSlot.tstore(currIndex.asBytes32(), execHash);
        }
    }

    function _tryInitAttestationFromStorage(bytes32 executionHash) internal returns (bool) {
        // Avoid reentrancy or double init: Make sure that we are starting from a
        // zero state or after a previous attestation has been used.
        if (!_idleOrDone()) return false;

        StoredAttestation storage storedAttestation = attestations[executionHash];
        if (storedAttestation.attestation.deadline == 0) revert AttestationNotFound();
        _initAttestation(storedAttestation.attestation, storedAttestation.attester);
        delete(attestations[executionHash]);
        return true;
    }

    function _idleOrDone() internal view returns (bool) {
        uint256 cacheIndex = StorageSlot.tload(HASH_CACHE_INDEX_SLOT.asUint256());
        uint256 hashCount = StorageSlot.tload(HASH_COUNT_SLOT.asUint256());
        return cacheIndex >= hashCount;
    }

    function _requireIdleOrDone() internal view {
        if (!_idleOrDone()) revert InvalidAttestation();
    }

    /**
     * @notice Computes the execution hash from given inputs.
     * @param checkpointHash An arbitrary hash which can be computed by using variety of values
     * that occur during a call
     * @param caller msg.sender of executeCheckpoint() call
     * @param executionHash Previous execution hash
     */
    function executionHashFrom(bytes32 checkpointHash, address caller, bytes32 executionHash)
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(checkpointHash, caller, executionHash));
    }
}
