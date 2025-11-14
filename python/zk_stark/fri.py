from __future__ import annotations
import merkle
from field import F
import field
from polynomial import Polynomial
import polynomial
import fft_poly
from iop import Channel, Msg, IFriProver, IFriVerifier
from utils import is_pow2, fiat_shamir


class Prover(IFriProver):
    def __init__(self, **kwargs):
        # Prime number
        P: int = kwargs["P"]
        # Expansion factor from trace length T to RS code length N
        # exp_factor * T = N
        exp_factor: int = kwargs["exp_factor"]
        # FRI evaluation domain, usually denoted as L
        eval_domain: list[int] = kwargs["eval_domain"]

        # Initial domain size
        N = len(eval_domain)

        assert N < P, f"{N} >= {P}"
        assert is_pow2(N), f"N = {N} is not a power of 2"
        assert 2 <= exp_factor, f"exp factor = {exp_factor} < 2"
        # Since N = exp_factor * T is a power of 2, exp_factor must also be a power of 2
        assert is_pow2(exp_factor), f"exp_factor = {exp_factor} is a power of 2"

        self.P: int = P
        self.N: int = N
        self.exp_factor = exp_factor
        self.eval_domain: list[int] = eval_domain
        self.hashes: list[list[str]] = []
        self.merkle_roots: list[str] = []
        self.challenges: list[F] = []
        self.codewords: list[list[F]] = []
        # Function to wrap x into F
        self.wrap = lambda x: F(x, P)

    def commit(self, codeword: list[F], chan: Channel):
        """
        0. f[0] = f
           L^(2^0) = L
           L^(2^(i+1)) = [x^2 for x in L^(2^i)]
        1. Evaluate polynomial f[i] at L^(2^i)
        2. Create Merkle tree from f[i](L^(2^i))
        3. Prover sends Merkle root to the verifier
        4. Verifier sends a challenge B[i]
        5. Prover calculates the folded polynomial
           5.1 Split f[i](x) = f[i, even](x^2) + x * f[i, odd](x^2)
           5.2 Fold f[i + 1](x) = f[i, even](x) + B[i] * f[i, odd](x)
        6. Repeat 1 to 5 until the polynomial f[i] is reduced to a polynomial with degree 0
        """
        assert len(self.merkle_roots) == 0
        assert len(self.codewords) == 0
        assert len(codeword) == self.N

        # Domain size
        n = self.N
        # Evaluation domain
        Li = self.eval_domain
        # t = trace length -> polynomial degree < t
        # n = t * exp_factor
        # At t = 1 -> n = exp_factor -> polynomial degree = 0
        while n >= self.exp_factor:
            # Reed Solomon code
            self.codewords.append(codeword)

            # Commit Merkle root
            hs = [merkle.hash_leaf(str(c)) for c in codeword]
            merkle_root = merkle.commit(hs)
            self.hashes.append(hs)
            self.merkle_roots.append(merkle_root)
            chan.send(
                dst="verifier",
                msg=Msg(msg_type="fri_merkle_root", data=merkle_root),
            )

            # Next loop
            n //= 2
            if n >= self.exp_factor:
                # Get random challenge
                c = chan.send(dst="verifier", msg=Msg(msg_type="fri_challenge"))
                self.challenges.append(self.wrap(c))
                # Fold
                # f_even(x^2) = (f(x) + f(-x)) / 2
                # f_odd(x^2) = (f(x) - f(-x)) / 2x
                # f_fold(x^2) = f_even(x^2) + c * f_odd(x^2)
                # Evaluations of f_fold(x^2)
                folds = []
                assert len(Li) == 2 * n
                for i in range(n):
                    x = Li[i]
                    f_plus = codeword[i]
                    f_minus = codeword[n + i]
                    f_even = (f_plus + f_minus) / 2
                    f_odd = (f_plus - f_minus) / (2 * x)
                    f_fold = f_even + c * f_odd
                    folds.append(f_fold)
                codeword = folds

                # L^(2^(i+1)) = [x^2 for x in L^(2^i)]
                Li = [x * x for x in Li[:n]]

    def prove(self, idx: int, chan: Channel):
        """
        0. f[0] = f
        1. Verifier sends random challenge x to the prover
        2. Prover sends f[i](x) and f[i](-x) and Merkle proofs
        3. Verifier checks Merkle proofs for f[i](x) and f[i](-x)
        4. Verifier uses f[i](x) and f[i](-x) to calculate f[i+1](x^2)
           f[i](x)  = f[i, even](x^2) + x * f[i, odd](x^2)
           f[i](-x) = f[i, even](x^2) - x * f[i, odd](x^2)
           f[i+1](x^2) = f[i, even](x^2) + Bi * f[i, odd](x^2)
                       = (f[i](x) + f[i](-x)) / 2 + B[i] * (f[i](x) - f[i](-x)) / 2x
           Verifier checks that f[i+1](x^2) provided in the next step matches the calculation above
        5. Update x
           x = x*x
        6. Repeat 2 to 5 while the degree of polynomial f[i] > 0
        7. When degree of f[i] = 0,
           -  Verifier directly checks the codeword f[i](Li)
           -  Calculates Merkle root from the codeword and checks with the committed Merkle root
        """
        i = 0
        n = self.N
        # List of (f[i](x^(2^i)), f[i](-x^(2^i)))
        vals: list[(F, F)] = []
        # Merkle proofs of (f[i](x^(2^i)), f[i](-x^(2^i)))
        proofs: list[(list[str], list[str])] = []

        while n > self.exp_factor:
            assert idx < n, f"index {idx} > {n}"
            # f[i](x) and f[i](-x)
            codeword = self.codewords[i]
            idx_plus = idx
            idx_minus = (n // 2 + idx) % n
            f_plus = codeword[idx_plus]
            f_minus = codeword[idx_minus]
            vals.append((f_plus, f_minus))

            # Merkle proof
            hs = self.hashes[i]
            proof_plus = merkle.open(hs, idx_plus)
            proof_minus = merkle.open(hs, idx_minus)
            proofs.append((proof_plus, proof_minus))

            # Next loop
            n //= 2
            i += 1
            if n > self.exp_factor:
                # x^i -> x^(2i % N)
                # n = 8, [x^0, x^1, x^2, x^3, x^4, x^5, x^6, x^7]
                # n = 4, [x^0, x^2, x^4, x^6]
                # n = 2, [x^0, x^4]
                # Next iteration maps upper half to lower half -> index i to i % (n / 2)
                idx %= n

        chan.send(
            dst="verifier",
            msg=Msg(msg_type="fri_proofs", data=(vals, proofs, self.codewords[-1])),
        )


class Verifier(IFriVerifier):
    def __init__(self, **kwargs):
        # Prime number
        P = kwargs["P"]
        # Primitive Nth root of unity
        w = kwargs["w"]
        # Shift evaluation domain (typically a generator of F[P])
        shift = kwargs["shift"]
        # Expansion factor from trace length T to RS code length N
        # exp_factor * T = N
        exp_factor = kwargs["exp_factor"]
        # FRI evaluation domain, usually denoted as L
        eval_domain: list[int] = kwargs["eval_domain"]

        # Initial domain size
        N = len(eval_domain)

        assert N < P, f"{N} >= {P}"
        assert is_pow2(N), f"{N} is not a power of 2"
        assert 2 <= exp_factor, f"exp factor = {exp_factor} < 2"
        # Since N = exp_factor * T is a power of 2, exp_factor must also be a power of 2
        assert is_pow2(exp_factor), f"exp_factor = {exp_factor} is a power of 2"
        assert 1 <= w <= P - 1
        assert 1 <= shift <= P - 1

        self.P: int = P
        self.N: int = N
        self.w: int = w
        self.shift: int = shift
        self.exp_factor = exp_factor
        self.eval_domain: list[int] = eval_domain
        self.merkle_roots: list[str] = []
        self.challenges: list[F] = []
        # Function to wrap x into F
        self.wrap = lambda x: F(x, P)

    def push_merkle_root(self, val: str):
        self.merkle_roots.append(val)

    def get_challenge(self, chan: Channel):
        c = fiat_shamir(str(self.merkle_roots))
        self.challenges.append(self.wrap(c))
        chan.send(dst="prover", msg=Msg(msg_type="fri_challenge", data=c))

    def query(self, idx: int, chan: Channel):
        (vals, proofs, codeword) = chan.send(
            dst="prover", msg=Msg(msg_type="fri_prove", data=idx)
        )
        self.verify(idx, vals, proofs, codeword)

    def verify(
        self,
        # Index to x in L
        idx: int,
        # List of (f[i](x), f[i](-x))
        vals: list[(F, F)],
        # Merkle proofs of (f[i](x), f[i](-x))
        proofs: list[(list[str], list[str])],
        # Last codeword
        codeword: list[F],
    ):
        """
        See Prover.prove
        """
        # Merkle root of the first codeword f[0](L) has no challenge
        assert len(self.merkle_roots) == len(self.challenges) + 1

        # Last Merkle root is directly calculated from the provided codeword
        assert len(vals) == len(proofs) == len(self.merkle_roots) - 1
        # Check last codeword length
        # trace length t -> poly degree < t
        # RS code length = n = t * exp_factor (here poly degree = 0 so t = 1)
        assert len(codeword) == self.exp_factor
        assert idx < self.N

        i = 0
        n = self.N
        x = self.eval_domain[idx]
        fold = None

        while n > self.exp_factor:
            merkle_root = self.merkle_roots[i]
            # f[i](x) and f[i](-x)
            (f_plus, f_minus) = vals[i]
            # Proofs of f[i](x) and f[i](-x)
            (proof_plus, proof_minus) = proofs[i]
            (idx_plus, idx_minus) = (idx, (n // 2 + idx) % n)

            # Check Merkle proofs of f[i](x) and f[i](-x)
            for f, p, j in zip(
                [f_plus, f_minus], [proof_plus, proof_minus], [idx_plus, idx_minus]
            ):
                assert merkle.verify(p, merkle_root, merkle.hash_leaf(str(f)), j)

            # Check fold
            if i > 0:
                assert fold == f_plus, "fold != f[i+1](x^2)"

            # Calculate fold for the next loop or last check after while loop
            c = self.challenges[i]
            fold = (f_plus + f_minus) / 2 + c * (f_plus - f_minus) / (2 * x)

            # Next loop
            n //= 2
            i += 1
            if n > self.exp_factor:
                x *= x
                idx %= n

        # Check last fold - last codeword must be an evaluation of a polynomial with
        # degree = 0 so all elements in the codeword must be the same values
        assert fold == codeword[0]

        # Check Merkle root
        assert (
            merkle.commit([merkle.hash_leaf(str(c)) for c in codeword])
            == self.merkle_roots[-1]
        )

        # Interpolate a polynomial and check that the degree = 0
        # (shift * w^i)^k = shift^k * w^(i*k)
        p = fft_poly.interp(
            codeword,
            field.generate(
                pow(self.w, 2 ** i, self.P),
                len(codeword),
                self.P,
            ),
            self.P,
            pow(self.shift, 2 ** i, self.P),
        )
        assert (
            p.degree() == 0
        ), f"interpolated polynomial degree = {p.degree()} > max = 0"
        assert (
            p(codeword) == codeword
        ), f"polynomial evaluation {p(codeword)} != {codeword}"
