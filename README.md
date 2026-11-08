# notes

# Math

- [`mulDiv`](./foundry/src/MulDiv.sol)
- [Extended euclidean algo](./python/math/euclid.ipynb)

# Cryptography

- [Elliptic curve addition](https://www.desmos.com/calculator/efumvebyyn)
- [ECDSA](./excalidraw/math/ecdsa.png)
- [ECDSA nonce reuse](./excalidraw/math/ecdsa-nonce-reuse.png)
  - [code](./python/math/ecdsa.ipynb)
- [Schnorr](./excalidraw/math/schnorr.png)
- [Schnorr multisig](./excalidraw/math/schnorr-multisig.png)
- [ECDH](./md/ecdh.md)
- [EVM EC operations](./foundry/test/ECOps.t.sol)

# DeFi

- [DCA vault](./foundry/src/dca/DCA.sol)
- [Yield optimization between 2 Aave V3 pools](./python/yield-opt.ipynb)
- [Vault inflation](./foundry/test/Vault.t.sol)
  - [Graph](https://www.desmos.com/calculator/orugjruk99)
  - [Notes](./excalidraw/vault-inflation.png)
- [63 / 64 gas rule](./foundry/test/Gas.t.sol)
- [Lending interest rate PID controller](./python/pid.ipynb)
- [Vault and rebase math equivalence](./excalidraw/vault-rebase.png)
  - [Code](./foundry/test/VaultAndRebase.t.sol)

# EVM

- [False array length](./foundry/test/FalseArrLen.t.sol)

# Algo

- [Sorted doubly linked list](./foundry/src/LinkedList.sol)
- Merkle Tree
  - [Algorithm](./excalidraw/algo/merkle-algo.png)
  - [Python](./python/algo/merkle.ipynb)
- Incremental Merkle Tree
  - [Algorithm](./excalidraw/algo/merkle-inc.png)
  - [Python](./python/algo/merkle_inc.ipynb)
  - [Solidity](./foundry/src/MerkleInc.sol)
- Incremental Merkle Tree with batch insert
  - [Python](./python/algo/merkle_inc_batch.ipynb)
  - [Solidity](./foundry/src/MerkleIncBatch.sol)
- Fast Fourier Transform
  - [Intro](./excalidraw/algo/fft/fft-intro.png)
  - [Definitions](./excalidraw/algo/fft/fft-definitions.png)
  - [Algorithm](./excalidraw/algo/fft/fft-algo.png)
  - [Bit reversal](./excalidraw/algo/fft/fft-bit-reversal.png)
  - [Python](./python/algo/fft.ipynb)
- [Most and least significant bits using clz](./foundry/test/Bit.t.sol)

# Groth16

- [R1CS](./excalidraw/groth16/r1cs.png)
- [QAP](./excalidraw/groth16/qap.png)
- [Schwartz-Zippel Lemma](./excalidraw/groth16/schwartz-zippel.png)
- [Polynomial evaluation at EC point](./excalidraw/groth16/ec-poly-eval.png)
- [EC pairing](./excalidraw/groth16/ec-pairing.png)
- [Groth16 - part 0 - overview](./excalidraw/groth16/groth16.png)
- [Groth16 - part 1 - first attempt](./excalidraw/groth16/groth16-1.png)
- [Groth16 - part 2 - separating factor](./excalidraw/groth16/groth16-2.png)
- [Groth16 - part 3 - witness consistency check](./excalidraw/groth16/groth16-3.png)
- [Groth16 - part 4 - additional explanation of witness consistency check](./excalidraw/groth16/groth16-4.png)
- [Groth16 - part 5 - merging constraints](./excalidraw/groth16/groth16-5.png)
- [Groth16 - part 6 - public inputs](./excalidraw/groth16/groth16-6.png)
- [Groth16 - part 7 - zero knowledge](./excalidraw/groth16/groth16-7.png)

# ZKStark

- [Overview](./excalidraw/zkstark/zkstark-overview.png)
- [Computation to polynomial](./excalidraw/zkstark/comp-to-poly.png)
- [Trace polynomial](./excalidraw/zkstark/trace-poly.png)
- [Trace domain](./excalidraw/zkstark/trace-domain.png)
- [Lagrange polynomial](./excalidraw/zkstark/lagrange.png)
- [Constraint polynomial](./excalidraw/zkstark/constraint-poly.png)
- [Vanishing polynomial](./excalidraw/zkstark/vanishing-poly.png)
- [Quotienting](./excalidraw/zkstark/quotienting.png)
- [Composition polynomial](./excalidraw/zkstark/comp-poly.png)
- [Mask](./excalidraw/zkstark/mask.png)
- [Checks on composition polynomials](./excalidraw/zkstark/comp-poly-checks.png)
- [Evaluation domain](./excalidraw/zkstark/eval-domain.png)
- [Why few checks on the composition polynomial is sufficient?](./excalidraw/zkstark/comp-poly-eq-checks.png)
- [Hamming distance](./excalidraw/zkstark/hamming-dist.png)
- [Reed Solomon code](./excalidraw/zkstark/rs-code-def.png)
- [Reed Solomon code and ZKSTARK](./excalidraw/zkstark/rs-code-and-zkstark.png)
- [Average distance amplication lemma](./excalidraw/zkstark/avg-dist-amp.png)
- [Hamming distance of rational functions](./excalidraw/zkstark/hamming-dist-rational-func.png)
- [Hamming distance of different RS code](./excalidraw/zkstark/hamming-dist-q-f.png)
- [Applying the average distance amplication lemma](./excalidraw/zkstark/apply-avg-dist-amp.png)
- [How to pick delta](./excalidraw/zkstark/delta-ex.png)
- [Why check functions are close to a low degree polynomials?](./excalidraw/zkstark/why-check-delta-close.png)
- [FRI](./excalidraw/zkstark/batch-fri.png)
- [Polynomial decomposition](./excalidraw/zkstark/poly-decomp.png)
- [Recap up to FRI](./excalidraw/zkstark/recap-up-to-fri.png)
- [DEEP ALI](./excalidraw/zkstark/deep-ali.png)
- [Why DEEP ALI increases security](./excalidraw/zkstark/deep-ali-sec.png)
- [FRI](./excalidraw/zkstark/fri.png)
- [Proximity gap theorem](./excalidraw/zkstark/proximity-gap.png)
- [Proximity gap distance](./excalidraw/zkstark/proximity-gap-dist.png)
- [FRI - honest and dishonest prover](./excalidraw/zkstark/fri-honest-dishonest.png)
- [Python code](./python/zkstark/zkstark.ipynb)
- [Links](./zkstark.md)
