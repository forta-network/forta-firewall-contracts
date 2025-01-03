// SPDX-License-Identifier: GNU General Public License Version 3
// See license at: https://github.com/forta-network/forta-firewall-contracts/blob/master/LICENSE-GPLv3.md

pragma solidity ^0.8.25;

import "./Activation.sol";

/**
 * @notice A checkpoint is a configurable point in code that activates in different conditions and
 * does security checks before proceeding with the rest of the execution.
 */
struct Checkpoint {
    /// @notice The value to compare against an unsigned integer value from an incoming function argument.
    uint192 threshold;
    /**
     * @notice Defines the expected start position of the incoming argument in the call data.
     * This is needed in some integration cases when the reference is found directly from call data
     * bytes.
     *
     * If the selected range is 32 bytes, then the byte range is called a reference and is treated
     * as an unsigned integer value which is compared with the threshold. Please note that using
     * negative signed integer values as references can cause unexpected behavior when compared
     * with the threshold value and working with negative reference values is discouraged.
     *
     * If the range is larger than 32 bytes, then the comparison with threshold value is skipped
     * and a hash of the bytes is used in checkpoint hash computation.
     */
    uint16 refStart;
    /**
     * @notice Defines the expected end position of the incoming argument in the call data.
     * This is needed in some integration cases when the reference is found directly from call data
     * bytes.
     *
     * If the selected range is 32 bytes, then the byte range is called a reference and is treated
     * as an unsigned integer value which is compared with the threshold. Please note that using
     * negative signed integer values as references can cause unexpected behavior when compared
     * with the threshold value and working with negative reference values is discouraged.
     *
     * If the range is larger than 32 bytes, then the comparison with threshold value is skipped
     * and a hash of the bytes is used in checkpoint hash computation.
     */
    uint16 refEnd;
    /**
     * @notice Defines the type of checkpoint activation (see types below).
     */
    Activation activation;
    /**
     * @notice This is for relying on tx.origin instead of hash-based checkpoint execution.
     */
    bool trustedOrigin;
}
