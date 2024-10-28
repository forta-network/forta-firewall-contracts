// SPDX-License-Identifier: GNU General Public License Version 3
// See license at: https://github.com/forta-network/forta-firewall-contracts/blob/master/LICENSE-GPLv3.md

pragma solidity ^0.8.25;

import "./Attestation.sol";

interface IExternalFirewall {
    function saveAttestation(Attestation calldata attestation, bytes calldata attestationSignature) external;
    function executeCheckpoint(address caller, bytes4 selector, uint256 ref) external;
    function executeCheckpoint(address caller, bytes4 selector, bytes32 input) external;
}
