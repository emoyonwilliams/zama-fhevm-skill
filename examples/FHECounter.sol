// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.24;

import { FHE, euint32, externalEuint32 } from "@fhevm/solidity/lib/FHE.sol";
import { ZamaEthereumConfig } from "@fhevm/solidity/config/ZamaConfig.sol";

/// @title FHECounter
/// @notice Minimal confidential counter using Zama FHEVM.
///         The count is stored encrypted — nobody can read it without ACL access.
contract FHECounter is ZamaEthereumConfig {
    euint32 private _count;

    /// @notice Returns the encrypted handle (NOT the plaintext value).
    ///         Off-chain decryption requires FHE.allow() permission.
    function getCount() external view returns (euint32) {
        return _count;
    }

    /// @notice Increments counter by an encrypted amount.
    /// @param inputEuint32  Encrypted value encrypted off-chain by the caller
    /// @param inputProof    ZK proof binding the value to msg.sender + address(this)
    function increment(externalEuint32 inputEuint32, bytes calldata inputProof) external {
        // 1. Verify ZK proof and convert external type to usable encrypted type
        euint32 evalue = FHE.fromExternal(inputEuint32, inputProof);

        // 2. FHE addition — never use += on encrypted types
        _count = FHE.add(_count, evalue);

        // 3. Grant ACL permissions — ALWAYS both calls after every mutation
        FHE.allowThis(_count);          // contract retains compute access
        FHE.allow(_count, msg.sender);  // caller can decrypt off-chain
    }

    /// @notice Decrements counter by an encrypted amount.
    /// @dev No underflow protection in this example — add in production.
    function decrement(externalEuint32 inputEuint32, bytes calldata inputProof) external {
        euint32 evalue = FHE.fromExternal(inputEuint32, inputProof);
        _count = FHE.sub(_count, evalue);
        FHE.allowThis(_count);
        FHE.allow(_count, msg.sender);
    }
}
