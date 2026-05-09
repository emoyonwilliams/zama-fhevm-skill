// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.24;

import { Ownable2Step, Ownable } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { FHE, externalEuint64, euint64 } from "@fhevm/solidity/lib/FHE.sol";
import { ZamaEthereumConfig } from "@fhevm/solidity/config/ZamaConfig.sol";
import { ERC7984 } from "@openzeppelin/confidential-contracts/token/ERC7984/ERC7984.sol";

/// @title ERC7984Token
/// @notice Production-ready confidential token using the ERC-7984 standard.
///         Extends OpenZeppelin's audited ERC7984 base contract.
///
/// Key differences from a hand-rolled confidential ERC-20:
/// - ACL (allowThis + allow) is handled automatically by ERC7984._update()
/// - 8 transfer variants (with/without inputProof, transfer/transferFrom)
/// - Operator pattern instead of per-amount approvals
/// - confidentialTotalSupply() is encrypted
contract ERC7984Token is ZamaEthereumConfig, ERC7984, Ownable2Step {

    /// @param initialOwner  Receives minting rights
    /// @param name          Token name (e.g. "Confidential USD")
    /// @param symbol        Token symbol (e.g. "cUSD")
    /// @param contractURI_  Metadata URI (can be empty string "")
    constructor(
        address initialOwner,
        string memory name,
        string memory symbol,
        string memory contractURI_
    ) ERC7984(name, symbol, contractURI_) Ownable(initialOwner) {}

    // ─────────────────────────────────────────────────────────────────────────
    // Mint / Burn (owner only)
    // ─────────────────────────────────────────────────────────────────────────

    /// @notice Mint an encrypted amount to `to`.
    ///         The amount is encrypted off-chain and provided with a ZK proof.
    function mint(
        address to,
        externalEuint64 encryptedAmount,
        bytes memory inputProof
    ) external onlyOwner {
        // FHE.fromExternal verifies the proof, then we pass the euint64 to _mint
        _mint(to, FHE.fromExternal(encryptedAmount, inputProof));
        // Note: ERC7984._mint calls _update, which handles FHE.allowThis + FHE.allow
    }

    /// @notice Burn an encrypted amount from `from`.
    function burn(
        address from,
        externalEuint64 encryptedAmount,
        bytes memory inputProof
    ) external onlyOwner {
        _burn(from, FHE.fromExternal(encryptedAmount, inputProof));
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Reading balances
    // ─────────────────────────────────────────────────────────────────────────

    // Use inherited: confidentialBalanceOf(address) → euint64
    // Use inherited: confidentialTotalSupply() → euint64
    //
    // Both return bytes32 handles — not plaintext values.
    // Off-chain decryption requires FHE.allow() permission (set by _update).

    // ─────────────────────────────────────────────────────────────────────────
    // Transfers — all inherited from ERC7984
    // ─────────────────────────────────────────────────────────────────────────

    // confidentialTransfer(address to, externalEuint64 amount, bytes inputProof)
    // confidentialTransfer(address to, euint64 amount)  ← internal handle, no proof
    // confidentialTransferFrom(address from, address to, externalEuint64 amount, bytes inputProof)
    // confidentialTransferFrom(address from, address to, euint64 amount)
    //
    // For transferFrom: use setOperator(spender, untilTimestamp) instead of per-amount approve

    // ─────────────────────────────────────────────────────────────────────────
    // Operator pattern (replaces ERC-20 allowance)
    // ─────────────────────────────────────────────────────────────────────────

    // setOperator(address spender, uint256 untilTimestamp) — approve unlimited spend until timestamp
    // isOperator(address holder, address spender) → bool
}
