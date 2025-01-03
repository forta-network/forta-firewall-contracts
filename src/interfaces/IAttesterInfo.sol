// SPDX-License-Identifier: GNU General Public License Version 3
// See license at: https://github.com/forta-network/forta-firewall-contracts/blob/master/LICENSE-GPLv3.md

pragma solidity ^0.8.25;

interface IAttesterInfo {
    event AttesterControllerUpdated(bytes32 indexed attesterControllerId);

    function getAttesterControllerId() external view returns (bytes32);
}
