---
name: fhevm-zama
description: >
  Use this skill whenever writing, testing, or deploying confidential smart
  contracts using Zama's FHEVM library on Ethereum or Sepolia. Triggers on any
  mention of FHEVM, FHE smart contracts, encrypted Solidity types (euint, ebool,
  eaddress), confidential dApps, Zama Protocol, ERC-7984, OpenZeppelin
  confidential contracts, or any request to build privacy-preserving onchain
  logic. Always consult this skill before writing any FHEVM Solidity or
  TypeScript integration code — it contains critical patterns, anti-patterns,
  and the full development workflow AI agents must follow.
---

# FHEVM Smart Contract Skill

## Supporting Files
Read these when needed — they are part of this skill:
- `references/frontend.md` — fhevmjs SDK, user decryption (EIP-712), public decryption
- `references/erc7984.md` — ERC-7984 standard, OpenZeppelin confidential contracts
- `examples/FHECounter.sol` — minimal working contract
- `examples/ERC7984Token.sol` — production-ready confidential token

---

## 1. What is FHEVM?

FHEVM is a Solidity library by Zama enabling confidential smart contracts on
Ethereum. Contracts store and compute on encrypted data without ever decrypting
it on-chain. Encrypted values are stored as `bytes32` ciphertext handles
pointing to values held by off-chain coprocessors.

**Architecture:**
- **FHEVM Solidity library** — encrypted types + operations in Solidity
- **Coprocessors** — off-chain nodes executing actual FHE computation
- **Gateway** — orchestrates ACL, bridges ciphertexts, coordinates decryption
- **KMS** — threshold MPC network managing FHE keys and decryption
- **Relayer** — handles encrypted input registration and user decryption via EIP-712

**Key guarantee:** No one — not validators, not the contract owner — can read
encrypted state unless explicitly granted access via the ACL.

---

## 2. Project Setup

### Prerequisites
- Node.js LTS even-numbered version only (v20, v22). Odd versions (v21, v23) break Hardhat.

### Use the official template

```sh
# Go to https://github.com/zama-ai/fhevm-hardhat-template
# Click "Use this template" → create your repo, then:
git clone <your-repo-url> && cd <your-repo-name>
npm install
npm install @openzeppelin/confidential-contracts @openzeppelin/contracts
```

### Required imports

```solidity
import { FHE, euint64, externalEuint64, ebool } from "@fhevm/solidity/lib/FHE.sol";
import { ZamaEthereumConfig } from "@fhevm/solidity/config/ZamaConfig.sol";
```

### Required inheritance — no exceptions

```solidity
contract MyContract is ZamaEthereumConfig { }
// Without this, ZERO FHE operations work on Sepolia or Hardhat
```

### Sepolia vars

```sh
npx hardhat vars set MNEMONIC        # 12-word seed phrase
npx hardhat vars set INFURA_API_KEY  # from infura.io
```

---

## 3. Encrypted Types

| Solidity | FHEVM | External Input |
|---|---|---|
| `bool` | `ebool` | `externalEbool` |
| `uint8` | `euint8` | `externalEuint8` |
| `uint16` | `euint16` | `externalEuint16` |
| `uint32` | `euint32` | `externalEuint32` |
| `uint64` | `euint64` | `externalEuint64` |
| `uint128` | `euint128` | `externalEuint128` |
| `uint256` | `euint256` | `externalEuint256` |
| `address` | `eaddress` | `externalEaddress` |

External types are used for user-supplied encrypted inputs. They MUST be
converted via `FHE.fromExternal()` before any use.

### Casting

```solidity
euint32  e = FHE.asEuint32(42);           // plaintext → encrypted
euint64  e = FHE.asEuint64(someEuint32);  // upcast
ebool    e = FHE.asEbool(someEuint32);    // int → bool
eaddress e = FHE.asEaddress(msg.sender);  // address → encrypted
bool init  = FHE.isInitialized(val);      // check if handle is non-zero
```

---

## 4. FHE Operations

Never use `+`, `-`, `>`, `==` etc. on encrypted types. Use the `FHE` library.

```solidity
// Arithmetic
FHE.add(a, b); FHE.sub(a, b); FHE.mul(a, b);
FHE.min(a, b); FHE.max(a, b); FHE.neg(a);
FHE.div(a, 5); FHE.rem(a, 5); // divisor MUST be plaintext

// Comparison → returns ebool
FHE.eq(a,b); FHE.ne(a,b); FHE.lt(a,b); FHE.le(a,b); FHE.gt(a,b); FHE.ge(a,b);

// Bitwise
FHE.and(a,b); FHE.or(a,b); FHE.xor(a,b); FHE.not(a);
FHE.shl(a, 2); FHE.shr(a, 2);

// Conditional — ALWAYS use this, NEVER use `if` on encrypted bool
euint64 result = FHE.select(condition, trueValue, falseValue);

// Randomness
euint32 rand = FHE.randEuint32();
```

---

## 5. Input Proofs

User-supplied encrypted values require two parameters: the ciphertext + a ZK proof.

### Contract side

```solidity
function deposit(externalEuint64 inputAmount, bytes calldata inputProof) external {
    euint64 amount = FHE.fromExternal(inputAmount, inputProof); // verify + convert
    _balances[msg.sender] = FHE.add(_balances[msg.sender], amount);
    FHE.allowThis(_balances[msg.sender]);
    FHE.allow(_balances[msg.sender], msg.sender);
}
```

### Frontend / test side

```ts
const enc = await fhevm
  .createEncryptedInput(contractAddress, user.address)
  .add64(1000n)   // add8/add16/add32/add64/add128 — match your Solidity type
  .encrypt();

await contract.connect(user).deposit(enc.handles[0], enc.inputProof);
```

The input is bound to both the contract address and the user's address.
It cannot be reused in another contract or by another user.

---

## 6. Access Control (ACL)

Encrypted values are private by default. Grant access explicitly after every mutation.

```solidity
FHE.allowThis(value);                 // contract retains compute access — ALWAYS required
FHE.allow(value, addr);              // addr can decrypt off-chain
FHE.allowTransient(value, addr);     // temporary access, this transaction only
FHE.makePubliclyDecryptable(value);  // anyone can decrypt (e.g. voting result)
bool ok = FHE.isSenderAllowed(value); // guard: verify caller has access
```

### Rule: after EVERY state write, call BOTH

```solidity
_balance = FHE.add(_balance, amount);
FHE.allowThis(_balance);         // ← contract loses compute access without this
FHE.allow(_balance, msg.sender); // ← user cannot decrypt without this
```

---

## 7. Decryption

See `references/frontend.md` for complete frontend decryption code.

### In Hardhat tests (user decryption)

```ts
import { FhevmType } from "@fhevm/hardhat-plugin";

const handle = await contract.balanceOf(alice.address); // bytes32 handle
const plain = await fhevm.userDecryptEuint(
  FhevmType.euint64,  // must match the Solidity encrypted type
  handle,
  contractAddress,
  alice               // must have FHE.allow() permission
);
// plain is a bigint
```

### Public decryption (on-chain contract side)

```solidity
// Mark value as publicly decryptable, then emit an event
FHE.makePubliclyDecryptable(_encryptedResult);
emit ResultReady(_encryptedResult);

// Receive decrypted result via callback after off-chain processing
function finalizeResult(uint64 clearValue, bytes calldata proof) external {
    // use clearValue in contract logic
}
```

---

## 8. Testing

```sh
npx hardhat test                                        # mock (fast, dev)
npx hardhat node                                        # terminal 1
npx hardhat test --network localhost                    # terminal 2
npx hardhat test --network sepolia                      # real FHE (slow)
```

### Test boilerplate

```ts
import { FhevmType } from "@fhevm/hardhat-plugin";
import { expect } from "chai";
import { ethers, fhevm } from "hardhat";

describe("MyContract", function () {
  let contract: MyContract;
  let contractAddress: string;
  let alice: HardhatEthersSigner;

  beforeEach(async () => {
    [, alice] = await ethers.getSigners();
    const factory = await ethers.getContractFactory("MyContract");
    contract = await factory.deploy();
    contractAddress = await contract.getAddress();
  });

  it("encrypts, transacts, and decrypts correctly", async function () {
    const enc = await fhevm
      .createEncryptedInput(contractAddress, alice.address)
      .add64(500n).encrypt();

    await contract.connect(alice).deposit(enc.handles[0], enc.inputProof);

    const handle = await contract.balanceOf(alice.address);
    const value = await fhevm.userDecryptEuint(
      FhevmType.euint64, handle, contractAddress, alice
    );
    expect(value).to.eq(500n);
  });
});
```

---

## 9. Deployment

```sh
npx hardhat compile
npx hardhat deploy --network sepolia
npx hardhat fhevm check-fhevm-compatibility --network sepolia --address <addr>
```

Get Sepolia ETH: `sepoliafaucet.com`

---

## 10. ⚠️ Anti-Patterns

| # | Wrong | Correct |
|---|---|---|
| 1 | `if (FHE.gt(a,b)) { ... }` | `FHE.select(FHE.gt(a,b), x, y)` |
| 2 | Only `FHE.allow(v, addr)` after write | Always also call `FHE.allowThis(v)` |
| 3 | `FHE.add(_c, inputEuint32)` | Convert first: `FHE.fromExternal(input, proof)` |
| 4 | `function f(externalEuint64 x)` | Always include `bytes calldata inputProof` |
| 5 | `contract C { }` | `contract C is ZamaEthereumConfig { }` |
| 6 | `FHE.eq(eBalance, 100)` | `FHE.eq(eBalance, FHE.asEuint64(100))` |
| 7 | `FHE.div(a, encryptedB)` | `FHE.div(a, 4)` — divisor must be plaintext |
| 8 | `console.log(await token.balanceOf(addr))` | Decrypt with `fhevm.userDecryptEuint(...)` |
| 9 | `emit Transfer(from, to, amount)` | `emit Transfer(from, to)` — omit encrypted amounts |
| 10 | `FHE.div(a, 0)` | Always guard against zero divisor |

---

## 11. Resources

- Docs: https://docs.zama.org/protocol/solidity-guides/getting-started/overview
- Hardhat template: https://github.com/zama-ai/fhevm-hardhat-template
- OZ confidential contracts: https://github.com/OpenZeppelin/openzeppelin-confidential-contracts
- ERC-7984 examples: https://docs.zama.org/protocol/examples/openzeppelin-confidential-contracts/erc7984
