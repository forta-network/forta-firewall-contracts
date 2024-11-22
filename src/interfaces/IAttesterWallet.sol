// SPDX-License-Identifier: GNU General Public License Version 3
// See license at: https://github.com/forta-network/forta-firewall-contracts/blob/master/LICENSE-GPLv3.md

pragma solidity ^0.8.25;

import "./ISecurityValidator.sol";

interface IAttesterWallet {
    function setSecurityValidator(ISecurityValidator _securityValidator) external;
    function setExtraGasOverhead(uint256 _extraGasOverhead) external;
    function deposit(address beneficiary) external payable;
    function withdraw(uint256 amount) external;
    function withdrawAll() external;
    function balanceOf(address beneficiary) external view returns (uint256);
    function storeAttestationForOrigin(
        Attestation calldata attestation,
        bytes calldata attestationSignature,
        address beneficiary
    ) external;
}
