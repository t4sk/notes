- Codeword
- Reed Solomon code
- Hamming distance
- Polynomial
- Modular arithmetic, finite field
- Group, generator
- Roots of unity (z^n = 1, n > 0)
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
        f0_even(x) = (f(x) + f(-x)) / 2
        f0_odd(x)  = (f(x) - f(-x))
   5.2 Fold f1(x) = f0_even(x) + B0 * f0_odd(x)
6. Repeat 1 to 5 with f1 and domain ((w^0)^2, (w^1)^2, ...) = (w^0, w^2, ..)
   until the polynomial is reduced to a constant
```

### Query phase

```
1. Verifier sends random challenge x to the prover
2. Start at i = 0, prover sends fi(x) and fi(-x) and Merkle proof
3. Verfifier checks Merkle proof
4. Verifier uses fi(x) and fi(-x) to create f(i+1)(x^2)
   fi(x)  = fi_even(x^2) + x * fi_odd(x^2)
   fi(-x) = fi_even(x^2) - x * fi_odd(x^2)
   f(i+1)(x^2) = fi_even(x^2) + Bi * fi_odd(x^2)
5. Repeat 2 to 4, evaluate at +/-x^2, +/-x^4, +/-x^8, ...
```

### TODO: problem with commiting to f(x)
- TODO: high probability of accepting a fraud

### g(x,y) evaluation table
TODO: why it boosts fraud detection? + polynomial reduction
```
g(x, y) = f0_even(y) + x * f0_odd(y)

         x | w^0 | w^1 | w^2 | ...
y (w^0)^2  |
  (w^1)^2  |
  (w^2)^2  |
    ...    |

g(x, x^2) = f(x) = diagnol

Pick x = B0
g(B0, y) = f0_even(y) + B0 * f0_odd(y) 
         = column, deg(g) <= N / 2
         = f1(y)

Pick y = y0
g(x, y0) = f0_even(y0) + x * f0_odd(y0) 
         = row, linear equation deg(g) <= 1
         2 point determine a line -> 2 point in a row is sufficient to recover all the points in that row

TOOD: implications if prover commits to the whole table?
```

TODO: cheat example?

TODO: quotienting?










