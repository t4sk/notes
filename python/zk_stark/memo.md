- Polynomial
- Codeword
- Reed Solomon code
- TODO: RS code redundancy, error correcting radius, unique decoding distance etc..
- Hamming weight and distance
- Proximity gap for RS codes
- Polynomial, degree, how to check if given points recover an polynomial
- Lagrange interpolation
- Modular arithmetic, finite field, prime field of order 2^n + 1, inverse, -1
- Group, subgroup, generator
- Roots of unity (z^n = 1, n > 0), primitive roots of unity
- FFT, inverse FFT
- Low degree testing
- Merkle tree
- Why RS code? Why not regular polynomial? -> structured redundancy
- Split + fold
- Commit phase
- Query phase
- How is ZKStark zero knowledge? -> masking (shifting polynomial by a random polynomial)
- Batching

### Reed Solomon code
```
messange length = d -> P = polynomial degree = d
encoded message length = N -> evaluate N points -> field dimension = N
N > d
N points determines the unique polynomial P
```

### Commit phase

TODO: why check that polynomial is low degree? <- given RS code, it always identify a polynomial (a poly that passes through all the points provided)
TODO: why low degree polynomial is honest execution trace? Can a dishonest execution trace have a low degree poly?

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
6. Repeat 1 to 5 with f1 and domain ((w^0)^2, (w^1)^2, ...), half the original domain size,
   until the polynomial is reduced to a constant
```

```
TODO: glue - consistency between folding
```

```
TODO: example domain size small enough to do a direct check (honest and dishonest cases)
- honest prover -> evals of poly of low degree -> direct check at multiple points
- dishonest prover -> eval of poly (?), dishonest at many points (*) -> high probability of fraud detection?
- (*) RS code recovers original low degree poly for small errors / incorrect points
      so dishonest prover will need to cheat at many points
```

```
TODO: send evaluation of high degree polynomial
TODO: example 1 iteration of fold (query + direct check)
A fraudulent prover is successful when the verifier accepts a codeword that does not correspond to a low degree polynomial.
2 choices (?)
- Evaluation of higher degree polynomial -> eventually detected?
- Send different codeword -> must disagree at many points -> high probability of getting caught?
```
### Query phase

```
1. Verifier sends random challenge x to the prover
2. Start at i = 0, prover sends fi(x) and fi(-x) and Merkle proof
3. Verfifier checks Merkle proofs for fi(x) and fi(-x)
4. Verifier uses fi(x) and fi(-x) to create f(i+1)(x^2)
   fi(x)  = fi_even(x^2) + x * fi_odd(x^2)
   fi(-x) = fi_even(x^2) - x * fi_odd(x^2)
   f(i+1)(x^2) = fi_even(x^2) + Bi * fi_odd(x^2)
               = (fi(x) + fi(-x)) / 2 + Bi * (fi(x) - fi(-x)) / 2x
   Check that f(i+1)(x^2) provided in the next step matches the calculation above
5. Repeat 2 to 4, evaluate at +/-x^2, +/-x^4, +/-x^8, ...

TODO: check at step 4 fails with high probability if fraud? Also, probability of prover to guess the challenge x before commit is low
```

### TODO: problem with commiting to f(x)
- TODO: high probability of accepting a fraud
- need d + k queries for (1 - p)^k probability of accepting a fraud

### g(x,y) evaluation table
TODO: why it boosts fraud detection? + polynomial reduction
TODO: probability of fraud detection in polynomial vs bivariate polynomial
TODO: example of polynomial of high degree
TODO: example of distance decay?
small errors -> identify an unique polynomial
many errors -> not a RS codeword (or a different RS of polynomial with higher degree?)

```
g(x, y) = f0_even(y) + x * f0_odd(y)

         x | w^0 | w^1 | w^2 | ...
y (w^0)^2  |
  (w^1)^2  |
  (w^2)^2  |
    ...    |

g(x, x^2) = f(x) = diagnol

Column, deg(g) <= N / 2
Pick x = B0
g(B0, y) = f0_even(y) + B0 * f0_odd(y) 
         = f1(y)

Row, linear equation deg(g) <= 1
Pick y = y0
g(x, y0) = f0_even(y0) + x * f0_odd(y0) 
         2 points determine a line -> 2 points in a row is sufficient to recover all the points in that row

TOOD: implications if prover commits to the whole table?
```

TODO: cheat example?
TODO: low degree testing
TODO: quotienting?










