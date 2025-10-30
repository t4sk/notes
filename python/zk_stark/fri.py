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
        # Primitive Nth root of unity
        w: int = kwargs["w"]
        # Shift evaluation domain (typically a generator of F[P])
        shift: int = kwargs["shift"]
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
        self.codewords: list[list[F]] = []
        # Function to wrap x into F
        self.wrap = lambda x: F(x, P)

    def commit(self, codeword: list[F], chan: Channel):
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
        assert len(self.merkle_roots) == 0
        assert len(self.codewords) == 0
        assert len(codeword) == self.N

        # Domain size
        n = self.N
        s = self.shift
        # Evaluation domain
        Li = self.eval_domain
        # T = trace length -> polynomial degree < T
        # n = T * exp_factor
        # T = 1 -> polynomial degree < 1
        # At n = exp_factor -> polynomial degree = 0
        while n >= self.exp_factor:
            # Reed Solomon code
            self.codewords.append(codeword)

            # Commit Merkle root
            merkle_root = merkle.commit([merkle.hash_leaf(str(c)) for c in codeword])
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

                # shift * w^i -> (shift * w^i)^2 = shift^2 * w^(2i)
                Li = [s * li for li in Li[0::2]]
                s *= s

    def prove(self, idx: int, chan: Channel):
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

        while n > self.exp_factor:
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
            if n > self.exp_factor:
                i += 1
                # w^i -> w^(2i % N)
                # n = 8, [w0, w1, w2, w3, w4, w5, w6, w7]
                # n = 4, [w0, w2, w4, w6]
                # n = 2, [w0, w4]
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
        idx: int,
        vals: list[(F, F)],
        proofs: list[(list[str], list[str])],
        codeword: list[F],
    ):
        """
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
        # Merkle root of the first codeword (f[0](L[0])) has no challenge
        assert len(self.merkle_roots) == len(self.challenges) + 1

        # Last Merkle root is directly calculated from the provided codeword
        assert len(vals) == len(proofs) == len(self.merkle_roots) - 1
        # Check codeword length
        # trace length T -> poly degree < T -> RS code length N
        # N = T * exp_factor (here poly degree = 0 so T = 1)
        assert len(codeword) == self.exp_factor
        assert idx < self.N

        i = 0
        n = self.N
        x = self.eval_domain[idx]
        fold = None

        while n > self.exp_factor:
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
            if n > self.exp_factor:
                # Calculate fold
                c = self.challenges[i]
                fold = (f_plus + f_minus) / 2 + c * (f_plus - f_minus) / (2 * x)
                x *= x
                i += 1
                idx %= n

        # Check Merkle root
        assert (
            merkle.commit([merkle.hash_leaf(str(c)) for c in codeword])
            == self.merkle_roots[-1]
        )
        # Interpolate a polynomial and check the degree
        # shift * w^j -> (shift * w^j) ^ k = shift^k * w^(j*k)
        p = fft_poly.interp(
            codeword,
            # TODO: check domain
            field.generate(
                pow(self.w, 2 ** (i + 1), self.P),
                len(codeword),
                self.P,
            ),
            self.P,
            pow(self.shift, 2 ** (i + 1), self.P),
        )
        assert (
            p.degree() == 0
        ), f"interpolated polynomial degree = {p.degree()} > max = 0"
        assert (
            p(codeword) == codeword
        ), f"polynomial evaluation {p(codeword)} != {codeword}"
