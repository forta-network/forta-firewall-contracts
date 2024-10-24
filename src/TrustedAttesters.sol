// SPDX-License-Identifier: UNLICENSED
// See Forta Network License: https://github.com/forta-network/forta-firewall-contracts/blob/master/LICENSE.md

pragma solidity ^0.8.25;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/ITrustedAttesters.sol";

/// @dev All role ids are keccak256() of their names.
bytes32 constant ATTESTER_MANAGER_ROLE = 0xa6104eeb16757cf1b916694e5bc99107eaf38064b4948290b9f96447e33d6396;
bytes32 constant TRUSTED_ATTESTER_ROLE = 0x725a15d5fb1f1294f13d7272d4441134b951367ff5aebd74853471ce1cfb9cc4;

/**
 * @notice Keeps the set of accounts which are trusted attesters.
 */
contract TrustedAttesters is AccessControl, ITrustedAttesters {
    constructor(address _defaultAdmin) {
        _grantRole(DEFAULT_ADMIN_ROLE, _defaultAdmin);
        _setRoleAdmin(ATTESTER_MANAGER_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(TRUSTED_ATTESTER_ROLE, ATTESTER_MANAGER_ROLE);
    }

    /**
     * @notice Checks if the given address is a trusted attester.
     * @param caller Caller address.
     */
    function isTrustedAttester(address caller) public view returns (bool) {
        return hasRole(TRUSTED_ATTESTER_ROLE, caller);
    }
}
