import merkle
from field import F
from polynomial import Polynomial
import polynomial
from fft import fft, ifft
from utils import is_pow2, is_prime, log2


def domain(w: int, n: int, p: int) -> list[int]:
    """
    w = primitive n th root mod p
    p = prime
    """
    d = [pow(w, i, p) for i in range(0, n)]
    s = set(d)
    assert len(s) == n, f"|d| = {len(s)} != {n}"
    return d


def padd(xs, n, x):
    assert len(xs) <= n
    xs.extend([x] * (n - len(xs)))
    return xs    


# Evaluates polynomial using FFT
def eval_poly(f: Polynomial, ws: list[int], p: int) -> list[F]:
    cs = [c.unwrap() for c in f.cs]
    # Evaluation domain is larger than degree of polynomial so padd with 0
    cs = padd(cs, len(ws), 0) 
    ys = fft(cs, ws, p)
    return [F(y, p) for y in ys]

    
# Interpolates polynomial using inverse FFT
def interp_poly(ys: list[int | F], ws: list[int], p: int) -> Polynomial:
    ys = [y if isinstance(y, int) else y.unwrap() for y in ys]
    cs = ifft(ys, ws, p)
    return Polynomial(cs, lambda x: F(x, p))


class Prover:
    def __init__(self, **kwargs):
        # Prime
        P = kwargs["P"]
        # Initial domain size
        N = kwargs["N"]
        # Primitive Nth root
        w = kwargs["w"]
        # Interactive oracle proof
        iop = kwargs["iop"]
        # TODO: remove exp factor?
        # Expansion factor from message length M to RS code length N
        # exp_factor * M = N
        exp_factor = kwargs["exp_factor"]

        assert N < P
        assert is_prime(P), f"P = {P} is not prime"
        assert is_pow2(N), f"N = {N} is not a power of 2"
        assert 2 <= exp_factor, f"exp factor = {exp_factor} < 2"
        # Since N = exp_factor * M is a power of 2, exp_factor must also be a power of 2
        assert is_pow2(exp_factor), f"exp_factor = {exp_factor} is a power of 2"

        self.P: int = P
        self.N: int = N
        self.w: int = w
        self.iop = iop
        self.merkle_roots: list[str] = []
        self.challenges: list[F] = []
        self.codewords: list[list[F]] = []

    def commit(self, codeword: list[F]):
        """
        1. Evaluate polynomial f0(x) at w^0, w^1, ..., w^(N-1)
           where w is a Nth primitive root of unity (use FFT for fast evaluation)
           [f0(w^i) for 0 <= i < N] is a RS codeword
        2. Create Merkle tree from the RS codeword
        3. Prover sends Merkle root to the verifier
        4. Verifier sends a challenge C0
        5. Prover calculates the folded polynomial
           5.1 Split f0(x) = f0_even(x^2) + x * f0_odd(x^2)
           5.2 Fold f1(x) = f0_even(x) + C0 * f0_odd(x)
        6. Repeat 1 to 5 with f1 and domain ((w^0)^2, (w^1)^2, ...), half the original domain size,
           until the polynomial is reduced to a constant
        """
        assert len(codeword) == self.N

        # Domain size
        n = self.N
        # primitive Nth root
        w = F(self.w, self.P)
        # Evaluation domain
        Li = domain(w.v, n, self.P)
        # At n = 2 -> codeword length = 2 -> message length = n / exp_factor <= 1 -> function is a constant function (polynomial of degree 0)
        while n > 1:
            # Reed Solomon code
            self.codewords.append(codeword)

            # Commit Merkle root
            merkle_root = merkle.commit([merkle.hash_leaf(str(c)) for c in codeword])
            self.merkle_roots.append(merkle_root)
            self.iop.send(merkle_root)

            # Next loop
            n //= 2
            if n > 1:
                # Get random challenge
                c = F(self.iop.get_challenge(), self.P)
                self.challenges.append(c)
                # Fold
                # f_even(x^2) = (f(x) + f(-x)) / 2
                # f_odd(x^2) = (f(x) - f(-x)) / 2x
                # f_fold(x^2) = f_even(x^2) + c * f_odd(x^2)
                # Evaluations of f_fold(w^(2i))
                f_folds = []
                for i in range(n):
                    x = Li[i]
                    f_plus = codeword[i]
                    f_minus = codeword[n + i]
                    f_even = (f_plus + f_minus) / 2
                    f_odd = (f_plus - f_minus) / (2 * x)
                    f_fold = f_even + c * f_odd
                    f_folds.append(f_fold)
                codeword = f_folds

                # w^i -> w^(2i) 
                Li = Li[0::2]

    def prove(self, idx: int) -> (list[(F, F)], list[(list[str], list[str])], list[F]):
        """
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
        6. When fi is a codeword with small length, do a direct check (interpolate a polynomial from the codeword and check the degree)

        TODO: comment about correlated method of query / proving

        for primitive Nth root of unity w and N is even
        w^(N/2) = -1 mod P so
        -w^k = -1 * w^k = w^(N/2 + k)
        """
        i = 0
        n = self.N
        vals: list[(F, F)] = []
        proofs: list[(list[str], list[str])] = []

        while n > 1:
            assert idx < n, f"index {idx} > {n}"
            # fi(x) and fi(-x)
            codeword = self.codewords[i]
            idx_plus = idx
            idx_minus = (n // 2 + idx) % n
            f_plus = codeword[idx_plus]
            f_minus = codeword[idx_minus]
            vals.append((f_plus, f_minus))

            # Merkle proof
            hs = [merkle.hash_leaf(str(c)) for c in codeword]
            proof_plus = merkle.open(hs, idx_plus)
            proof_minus = merkle.open(hs, idx_minus)
            proofs.append((proof_plus, proof_minus))

            # Next loop
            n //= 2
            if n > 1:
                i += 1
                # w^i -> w^(2i % N)
                # n = 8, [w0, w1, w2, w3, w4, w5, w6, w7]
                # n = 4, [w0, w2, w4, w6]
                # n = 2, [w0, w4]
                # Next iteration maps upper half to lower half -> index i to i % (n / 2)
                idx %= n

        return (vals, proofs, self.codewords[-1])


class Verifier:
    def __init__(self, **kwargs):
        # Prime
        P = kwargs["P"]
        # Initial domain size
        N = kwargs["N"]
        # Primitive Nth root
        w = kwargs["w"]
        merkle_roots = kwargs["merkle_roots"]
        challenges = kwargs["challenges"]
        # Expansion factor from message length M to RS code length N
        # exp_factor * M = N
        exp_factor = kwargs["exp_factor"]

        assert N < P, f"{N} >= {P}"
        assert is_prime(P), f"{P} is not prime"
        assert is_pow2(N), f"{N} is not a power of 2"
        assert 2 <= exp_factor, f"exp factor = {exp_factor} < 2"
        # Since N = exp_factor * M is a power of 2, exp_factor must also be a power of 2
        assert is_pow2(exp_factor), f"exp_factor = {exp_factor} is a power of 2"

        # Merkle root of the first codeword (f[0](L[0])) has no challenge
        assert len(merkle_roots) == len(challenges) + 1

        self.P: int = P
        self.N: int = N
        self.w: int = w
        self.merkle_roots: list[str] = merkle_roots
        self.challenges: list[F] = challenges
        self.exp_factor = exp_factor

    def verify(
        self,
        idx: int,
        vals: list[(F, F)],
        proofs: list[(list[str], list[str])],
        codeword: list[F],
    ):
        """
        TODO: verify with x not in L?
        3. Verfifier checks Merkle proofs for fi(x) and fi(-x)
        4. Verifier uses fi(x) and fi(-x) to create f(i+1)(x^2)
           fi(x)  = fi_even(x^2) + x * fi_odd(x^2)
           fi(-x) = fi_even(x^2) - x * fi_odd(x^2)
           f(i+1)(x^2) = fi_even(x^2) + Bi * fi_odd(x^2)
                       = (fi(x) + fi(-x)) / 2 + Bi * (fi(x) - fi(-x)) / 2x
           Check that f(i+1)(x^2) provided in the next step matches the calculation above
        6. When fi is a codeword with small length, do a direct check (interpolate a polynomial from the codeword and check the degree)
        TODO: fix comments
        """
        assert len(vals) == len(proofs) == len(self.merkle_roots)

        i = 0
        n = self.N
        x = F(pow(self.w, idx, self.P), self.P)
        # Used in last check of the codeword
        w = F(self.w, self.P)
        fold = None

        while n > 1:
            merkle_root = self.merkle_roots[i]
            # fi(x) and fi(-x)
            (f_plus, f_minus) = vals[i]
            # Proofs of fi(x) and fi(-x)
            (proof_plus, proof_minus) = proofs[i]
            (idx_plus, idx_minus) = (idx, (n // 2 + idx) % n)

            # Check Merkle proofs of fi(x) and fi(-x)
            # TODO: last check is redundant?
            for f, p, j in zip(
                [f_plus, f_minus], [proof_plus, proof_minus], [idx_plus, idx_minus]
            ):
                assert merkle.verify(p, merkle_root, merkle.hash_leaf(str(f)), j)

            # Check fold
            if i > 0:
                assert fold == f_plus, "fold != f[i+1](x^2)"

            # Next loop
            n //= 2
            if n > 1:
                # Calculate fold
                c = self.challenges[i]
                fold = (f_plus + f_minus) / 2 + c * (f_plus - f_minus) / (2 * x)
                x *= x
                w *= w
                i += 1
                idx %= n

        # Check codeword length
        # Message length M -> poly degree <= M - 1 -> RS code length N
        # N = M * exp_factor (here poly degree = 0 so M = 1)
        # TODO: fix
        assert len(codeword) == self.exp_factor
        # Check Merkle root
        assert (
            merkle.commit([merkle.hash_leaf(str(c)) for c in codeword])
            == self.merkle_roots[-1]
        )
        # Interpolate a polynomial and check the degree
        p = interp_poly(codeword, domain(w.unwrap(), len(codeword), self.P), self.P)
        assert (
            p.degree() == 0
        ), f"interpolated polynomial degree = {p.degree()} > max = 0"
        assert (
            p(codeword) == codeword
        ), f"polynomial evaluation {p(codeword)} != {codeword}"
