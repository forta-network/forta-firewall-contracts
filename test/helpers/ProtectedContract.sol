// SPDX-License-Identifier: GNU General Public License Version 3
// See license at: https://github.com/forta-network/forta-firewall-contracts/blob/master/LICENSE-GPLv3.md
pragma solidity ^0.8.25;

import {ISecurityValidator} from "../../src/SecurityValidator.sol";

contract ProtectedContract {
    ISecurityValidator public validator;

    constructor(ISecurityValidator _validator) {
        validator = _validator;
    }

    function execute(uint256 n) public {
        validator.executeCheckpoint(bytes32(uint256(1)));
    }
}
