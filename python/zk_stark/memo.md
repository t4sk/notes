- Codeword
- Reed Solomon code
- Hamming distance
- Polynomial
- Modular arithmetic, finite field
- Group, generator
- Roots of unity
- FFT, inverse FFT
- Merkle tree
- Why RS code? Why not regular polynomial? -> structured redundancy
- Split + fold
- Commit phase
- Query phase
- How is ZKStark zero knowledge? -> masking (shifting polynomial by a random polynomial)

### Reed Solomon code
```
messange length = d -> P = polynomial degree = d
encoded message length = N -> evaluate N points -> field dimension = N
N > d
N points determines the unique polynomial P
```

### Commit phase
- TODO: https://encrypt.a41.io/zk/stark/fri
- TODO: https://dev.risczero.com/proof-system/stark-by-hand

```
1. Evaluate polynomial f0(x) at w^0, w^1, ..., w^(N-1)
   where w is a root of unity and N is the domain size (use FFT for fast evaluation)
   [f0(w^i) for 0 <= i < N] is a RS codeword
   TODO: N is a power of 2?
2. Create Merkle tree from the RS codeword
3. Prover sends Merkle root to the verifier
4. Verifier sends a challenge B0
5. Prover calculates the folded polynomial
   5.1 Split f0(x) = f0_even(x^2) + x * f0_odd(x^2)
   5.2 Fold f1(x) = f0_even(x) + B0 * f0_odd(x)
6. Repeat 1 to 5 with f1 and domain ((w^0)^2, (w^1)^2, ...) = (w^0, w^2, ..)
   until the polynomial is reduced to a constant
```

### Query phase
