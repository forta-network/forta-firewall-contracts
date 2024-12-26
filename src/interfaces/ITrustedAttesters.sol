// SPDX-License-Identifier: GNU General Public License Version 3
// See Forta Network License: https://github.com/forta-network/forta-firewall-contracts/blob/master/LICENSE.md

pragma solidity ^0.8.25;

interface ITrustedAttesters {
    function isTrustedAttester(address caller) external view returns (bool);
}
