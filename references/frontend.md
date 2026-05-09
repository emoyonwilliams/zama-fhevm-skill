# Frontend Integration Reference

## fhevmjs SDK Setup

```ts
import { createInstance, initFhevm } from "fhevmjs/web"; // browser
// OR
import { createInstance } from "fhevmjs"; // Node.js
```

### Initialize once per app session

```ts
await initFhevm(); // loads WASM — do this once at app startup

const instance = await createInstance({
  chainId: 11155111, // Sepolia
  networkUrl: "https://sepolia.infura.io/v3/<YOUR_KEY>",
  gatewayUrl: "https://gateway.zama.ai", // Zama Gateway
});
```

---

## Encrypting Input Values (Frontend → Contract)

```ts
// Encrypt a value bound to a specific contract + user wallet
const encrypted = await instance
  .createEncryptedInput(contractAddress, userWalletAddress)
  .add64(transferAmount) // use add8/add16/add32/add64 to match your type
  .encrypt();

// encrypted.handles[0] → pass as externalEuint64 param
// encrypted.inputProof  → pass as bytes calldata inputProof param

await contract.transfer(
  recipientAddress,
  encrypted.handles[0],
  encrypted.inputProof
);
```

**Important:** The encrypted input is cryptographically bound to both:
- The contract address
- The user's wallet address

It cannot be reused by another user or replayed in a different contract.

---

## User Decryption (EIP-712 Flow)

User decryption lets an authorized address read their own private data
off-chain. The Relayer handles the request using EIP-712 signing.

### How it works:
1. The user's wallet signs an EIP-712 message authorizing decryption
2. The Relayer forwards the request to the Gateway
3. The KMS re-encrypts the value under the user's public key
4. The user decrypts locally in the browser

### In a React / frontend app

```ts
import { createInstance } from "fhevmjs/web";

// instance must be initialized with the user's provider (e.g. MetaMask)
const instance = await createInstance({
  chainId: 11155111,
  networkUrl: provider, // ethers provider from MetaMask
  gatewayUrl: "https://gateway.zama.ai",
});

// Get the encrypted handle from the contract
const handle = await contract.balanceOf(userAddress); // bytes32

// Request decryption — triggers EIP-712 signature in MetaMask
const { publicKey, privateKey } = instance.generateKeypair();
const eip712 = instance.createEIP712(publicKey, contractAddress);

// Ask user to sign
const signature = await signer.signTypedData(
  eip712.domain,
  { Reencrypt: eip712.types.Reencrypt },
  eip712.message
);

// Decrypt
const decrypted = await instance.reencrypt(
  handle,
  privateKey,
  publicKey,
  signature,
  contractAddress,
  userAddress
);

console.log("Balance:", decrypted); // bigint
```

### In Hardhat tests (simplified — no MetaMask needed)

```ts
import { FhevmType } from "@fhevm/hardhat-plugin";
import { fhevm } from "hardhat";

const handle = await contract.balanceOf(alice.address);
const value = await fhevm.userDecryptEuint(
  FhevmType.euint64,
  handle,
  contractAddress,
  alice // signer with FHE.allow() permission
);
console.log(value); // bigint — e.g. 1000000n
```

---

## Public Decryption

Public decryption reveals an encrypted value to everyone — used for things like
publishing a vote result or a lottery winner.

### Contract side

```solidity
// Step 1: Mark the value as publicly decryptable
FHE.makePubliclyDecryptable(_encryptedResult);
emit ResultReady(_encryptedResult); // emit handle for off-chain listeners

// Step 2: Receive the decrypted result via callback
function publishResult(
  uint64 clearResult,
  bytes calldata decryptionProof
) external {
  // Optionally verify the proof on-chain
  // Store or act on clearResult
  _publicResult = clearResult;
}
```

### Frontend / off-chain side

```ts
import { createInstance, PublicDecryptResults } from "fhevmjs/web";

const instance = await createInstance({ ... });

// Pass the handle(s) from the contract event
const results: PublicDecryptResults = await instance.publicDecrypt([handle]);

const clearValue = results.clearValues[handle]; // bigint | boolean
const proof = results.decryptionProof;           // submit this back on-chain

await contract.publishResult(clearValue, proof);
```

> ⚠️ The decryption proof is computed for the EXACT array of handles you pass.
> Order matters: `publicDecrypt([efoo, ebar])` generates a proof for
> `[efoo, ebar]`. Passing `[ebar, efoo]` to the contract will fail verification.

---

## Complete React Component Example

```tsx
import { useState } from "react";
import { createInstance, initFhevm } from "fhevmjs/web";
import { ethers } from "ethers";

export function ConfidentialBalance({ contractAddress, abi }) {
  const [balance, setBalance] = useState<bigint | null>(null);

  async function fetchBalance() {
    // Connect to MetaMask
    const provider = new ethers.BrowserProvider(window.ethereum);
    const signer = await provider.getSigner();
    const userAddress = await signer.getAddress();

    // Initialize fhevmjs
    await initFhevm();
    const instance = await createInstance({
      chainId: 11155111,
      networkUrl: provider,
      gatewayUrl: "https://gateway.zama.ai",
    });

    // Get encrypted handle from contract
    const contract = new ethers.Contract(contractAddress, abi, signer);
    const handle = await contract.balanceOf(userAddress);

    // EIP-712 re-encryption flow
    const { publicKey, privateKey } = instance.generateKeypair();
    const eip712 = instance.createEIP712(publicKey, contractAddress);
    const signature = await signer.signTypedData(
      eip712.domain,
      { Reencrypt: eip712.types.Reencrypt },
      eip712.message
    );

    // Decrypt and display
    const decrypted = await instance.reencrypt(
      handle, privateKey, publicKey, signature, contractAddress, userAddress
    );
    setBalance(decrypted);
  }

  return (
    <div>
      <button onClick={fetchBalance}>Reveal My Balance</button>
      {balance !== null && <p>Balance: {balance.toString()}</p>}
    </div>
  );
}
```
