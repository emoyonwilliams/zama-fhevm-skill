# zama-fhevm-skill
A production-ready skill file that enables AI coding agents (Claude Code, Cursor, Windsurf) to accurately write, test, and deploy confidential smart contracts using Zama's FHEVM library.

## What This Skill Does
AI coding agents have no built-in knowledge of FHE or FHEVM. This skill bridges that gap — giving any AI agent the context, patterns, and guardrails it needs to help developers build confidential applications correctly.

## File Structure
zama-fhevm-skill/
├── SKILL.md                    ← main skill file (start here)
├── references/
│   ├── frontend.md             ← fhevmjs SDK, EIP-712 decryption, public decryption
│   └── erc7984.md              ← ERC-7984 confidential token standard
└── examples/
├── FHECounter.sol          ← minimal working FHEVM contract
└── ERC7984Token.sol        ← production-ready confidential token

## How to Use
Drop `SKILL.md` into your AI coding environment (Claude Code, Cursor, Windsurf) and prompt naturally:

> "Write me a confidential voting contract using FHEVM"
> "How do I build a confidential ERC-7984 token?"

The agent will produce correct, working FHEVM code.

## Submission
Zama Developer Program Mainnet Season 2 — Bounty Track
