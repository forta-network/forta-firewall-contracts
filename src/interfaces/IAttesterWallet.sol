// SPDX-License-Identifier: GNU General Public License Version 3
// See license at: https://github.com/forta-network/forta-firewall-contracts/blob/master/LICENSE-GPLv3.md

pragma solidity ^0.8.25;

import "./ISecurityValidator.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IAttesterWallet is IERC20 {
    function setSecurityValidator(ISecurityValidator _securityValidator) external;
    function deposit(address beneficiary) external payable;
    function withdraw(uint256 amount, address beneficiary) external;
    function withdrawAll(address beneficiary) external;
    function storeAttestationForOrigin(
        Attestation calldata attestation,
        bytes calldata attestationSignature,
        address beneficiary,
        address chargeAccount,
        uint256 chargeAmount
    ) external;
}
