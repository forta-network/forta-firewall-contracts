// SPDX-License-Identifier: UNLICENSED
// See Forta Network License: https://github.com/forta-network/forta-firewall-contracts/blob/master/LICENSE.md

pragma solidity ^0.8.25;

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
