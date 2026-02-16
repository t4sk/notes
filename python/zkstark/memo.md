# ZKSTARK

- zk-stark-overview (TODO: update)
- comp-to-poly
- trace-poly
- trace-domain
- lagrange polynomial
- quotienting
- vanishing polynomial
- composition polynomial
- checks
- mask
- eval domain
- why few checks on pcomp?
- hamming dist
- rs code
- rs code + zkstark
- hamming dist of rational func
- dist of q to `RS[F, L, K]` and `RS[F, L, D]`
- apply avg dist amp
- delta example
- why check delta close
- batch FRI
- polynomial decomposition

- poly decomposition

- Big picture
```
Code execution (trace + constraints) -> polynomial -> prover commits to poly, verifier queries properties about the poly
                                     |------------------------------------ ZKSTARK ----------------------------------|
                                     |  Polynomail, finite field, group, roots of unity, FFT, Merkle tree, Reed Solomon code, codeword, FRI
                                    AIR
```
- Prerequisites
  - Polynomial over prime fields
  - Roots of unity
- Trace + constraint -> polynomial
  - Composition polynomial
- Polynomial
  - Properties
      - M points uniquely determines a poly of degree < M
      - 2 different poly of degree < M can agree at most M points?
      - r is a root of a polynomial P -> (x - r) divides P
      - degree(P) < K -> P(x) = 0 for at most K points
- Evaluation domain
  - Trace evaluation domain
  - ZKSTARK evaluation domain (coset)
- Polynomail constraint checks
  - Quotient
  - DEEP?
  - Commitment
  - Query
- FRI
  - Intro / Steps
  - Reed Solomon code
  - Code distance
  - Linear code
  - Commitment
  - Query
- Zero knowledge

- Modular arithmetic, negative, multiplicative inverse, division, finite field, prime field
- Field, multiplicative group, how to find generator for multiplicative group?
- Starkware primitive Nth root of unity N = 2^192, P = 2^251 + 17*2^192 + 1
- Polynomial, lagrange interpolation, division
- polynomial roots and division p(x) = f(x) / (x - a0)(x - a1)...(x-an)
- f and g poly degree = d -> intersect at most d points
- Constraint, composition polynomial
- Lagrange interpolation
- Fermat's conjecture 2^(2^k) + 1 is prime
- Group, subgroup, generator, Fermat's little theorem, coset
- Roots of unity (z^n = 1, n > 0), primitive roots of unity
- FFT, inverse FFT

- Merkle tree

- How is ZKStark zero knowledge? -> masking (shifting polynomial by a random polynomial)
- Batching
- Mixing
- Why prime field?
- Composition, constraint and validity polynomial
- Degree adjustment
- Schwartz-Zippel lemma
TODO: cheat example?
TODO: low degree testing
TODO: quotienting?

- [Graph - finite field, group, subgroup, coset](https://www.desmos.com/calculator/fadywrc9h5)






































