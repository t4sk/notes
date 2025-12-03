from __future__ import annotations
from polynomial import Polynomial, X
from field import F
import field
import fft_poly
import fri
import merkle
from iop import Channel, Msg, IStarkProver, IStarkVerifier
from utils import is_prime, is_pow2, min_pow2_gt, rand_int


class Prover(IStarkProver):
    def __init__(self, **kwargs):
        # Prime number
        P: int = kwargs["P"]
        # generator of F[P, *] = multiplicative subgroup of prime field P
        g: int = kwargs["g"]

        # Trace polynomial
        f: Polynomial = kwargs["trace_poly"]
        # Trace evaluation domain
        trace_eval_domain: list[int] = kwargs["trace_eval_domain"]
        trace_len = len(trace_eval_domain)
        assert is_pow2(trace_len)
        assert f.degree() < trace_len

        # Expansion factor, exp_factor * trace_len = N = size of eval_domain
        exp_factor: int = kwargs["exp_factor"]
        assert is_pow2(exp_factor)
        N = exp_factor * trace_len
        assert N < P

        # Primitive Nth root of unity
        w: int = field.get_primitive_root(g, N, P)
        assert pow(w, N, P) == 1
        assert pow(w, N // 2, P) == (-1 % P)
        # Nth roots of unitys
        roots: list[int] = field.generate(w, N, P)
        assert len(roots) == N

        # FRI and STARK evaluation domain are shifted by g so that
        # trace_eval_domain and eval_domain are disjoint
        eval_domain = [(g * wi) % P for wi in roots]
        assert (
            intersec := set(eval_domain) & set(trace_eval_domain)
        ) == set(), f"eval domains not disjoint {intersec}"

        # Let G = trace_eval_domain
        #     L = Nth roots of unity
        # G and L are subgroups of F[P, *] -> |G| and |L| divides |F[P, *]| = P - 1
        assert (P - 1) % trace_len == 0
        assert (P - 1) % N == 0

        # Constraint polynomial
        c: Polynomial = kwargs["constraint_poly"]
        # Constraint polynomial evaluation domain size
        c_size = min_pow2_gt(c.degree())
        assert trace_len <= c_size <= N
        assert (P - 1) % c_size == 0
        # Constraint polynomial evaluation domain
        c_eval_domain = field.generate(
            field.get_primitive_root(g, c_size, P), c_size, P
        )

        # z(x) = (x - g^0)(x - g^1)...(x - g^(T-1)) = x^T - 1, where T = trace_len
        z: Polynomial = X(trace_len, lambda x: F(x, P)) - 1

        # Quotient polynomial q(x) = c(x) / z(x)
        q = fft_poly.div(c, z, c_eval_domain, P, g)
        max_degree = q.degree()
        assert max_degree < trace_len

        self.P: int = P
        self.g: int = g
        self.eval_domain: list[int] = eval_domain
        # Needed to use FFT on eval_domain
        self.roots: list[int] = roots
        self.trace_len: int = trace_len

        self.f: Polynomial = f
        self.c: Polynomial = c
        self.z: Polynomial = z
        self.q: Polynomial = q
        # Max degree of quotient polynomial q(x)
        self.max_degree: int = max_degree
        self.q_adj: Polynomial | None = None

        self.f_hashes: list[str] = []
        self.q_hashes: list[str] = []
        self.f_merkle_root: str | None = None
        self.q_merkle_root: str | None = None

        self.fri_prover: fri.Prover = fri.Prover(
            P=P,
            exp_factor=exp_factor,
            eval_domain=eval_domain,
        )

    def fri(self) -> fri.Prover:
        return self.fri_prover

    def commit(self, chan: Channel):
        assert self.f_merkle_root is None
        assert self.q_merkle_root is None
        assert self.q_adj is None

        # Degree adjustment
        # Let max_degree = highest degree of all C[j] where C[j] are constraint polynomials
        # Let D = 2**k where k is smallest such that D > max_degree
        # Adjust degree of C[j] to D - 1
        # Given C[j] with degree of C[j] = D[j]
        # Degree adjusted polynomial = C[j](x) * (A[j] * x^(D - D[j] - 1) + B[j])
        # where A[j] and B[j] are random values provided by the verifier
        deg_adj = min_pow2_gt(self.max_degree)
        assert deg_adj > self.max_degree

        (a, b) = chan.send(
            dst="verifier", msg=Msg(msg_type="stark_degree_adj", data=self.max_degree)
        )
        adj = a * X(deg_adj - self.max_degree - 1, lambda x: F(x, self.P)) + b
        q_adj = self.q * adj
        assert is_pow2(q_adj.degree() + 1)
        assert q_adj.degree() == self.trace_len - 1

        self.q_adj = q_adj

        # f(L)
        fx = fft_poly.eval(self.f, self.roots, self.P, self.g)
        # q_adj(L)
        qx = fft_poly.eval(self.q_adj, self.roots, self.P, self.g)
        self.f_hashes = [merkle.hash_leaf(str(y)) for y in fx]
        self.q_hashes = [merkle.hash_leaf(str(y)) for y in qx]
        self.f_merkle_root = merkle.commit(self.f_hashes)
        self.q_merkle_root = merkle.commit(self.q_hashes)

        chan.send(
            dst="verifier",
            msg=Msg(
                msg_type="stark_merkle_roots",
                data=(self.f_merkle_root, self.q_merkle_root),
            ),
        )

        self.fri_prover.commit(qx, chan)

        assert self.q_merkle_root == self.fri_prover.merkle_roots[0]

    def prove(self, idx: int, chan: Channel):
        x = self.eval_domain[idx]
        fx = self.f(x)
        qx = self.q_adj(x)
        f_proof = merkle.open(self.f_hashes, idx)
        q_proof = merkle.open(self.q_hashes, idx)

        chan.send(
            dst="verifier",
            msg=Msg(msg_type="stark_proofs", data=(fx, qx, f_proof, q_proof)),
        )


class Verifier(IStarkVerifier):
    def __init__(self, **kwargs):
        # Prime number
        P: int = kwargs["P"]
        # generator of F[P, *] = multiplicative subgroup of prime field P
        g: int = kwargs["g"]

        # Trace evaluation domain
        trace_len: int = kwargs["trace_len"]
        assert is_pow2(trace_len)

        # Expansion factor, exp_factor * trace_len = N = size of eval_domain
        exp_factor: int = kwargs["exp_factor"]
        assert is_pow2(exp_factor)
        N = exp_factor * trace_len
        assert N < P

        # Primitive Nth root of unity
        w: int = field.get_primitive_root(g, N, P)
        assert pow(w, N, P) == 1
        assert pow(w, N // 2, P) == (-1 % P)
        # Nth roots of unitys
        roots: list[int] = field.generate(w, N, P)
        assert len(roots) == N

        # FRI and STARK evaluation domain are shifted by g so that
        # trace_eval_domain and eval_domain are disjoint
        eval_domain = [(g * wi) % P for wi in roots]

        # Let G = trace_eval_domain
        #     L = Nth roots of unity
        # G and L are subgroups of F[P, *] -> |G| and |L| divides |F[P, *]| = P - 1
        assert (P - 1) % trace_len == 0
        assert (P - 1) % N == 0

        # Constraint polynomial given a value y = f(x), c(y) must = 0
        c: Polynomial = kwargs["constraint_poly"]

        # z(x) = (x - g^0)(x - g^1)...(x - g^(T-1)) = x^T - 1, where T = trace_len
        z: Polynomial = X(trace_len, lambda x: F(x, P)) - 1

        self.P: int = P
        self.eval_domain: list[int] = eval_domain
        self.trace_len: int = trace_len

        self.c: Polynomial = c
        self.z: Polynomial = z
        # Max degree of the quotient polynomial q(x) = c(x) / z(x)
        self.max_degree: int = 0
        self.adj: Polynomial | None = None
        # Random challenges sent to prover for adjusting degree on quotient polynomial q(x)
        self.challenges: (int, int) | None = None

        self.f_merkle_root: str | None = None
        self.q_merkle_root: str | None = None

        self.fri_verifier: fri.Verifier = fri.Verifier(
            P=P,
            w=w,
            shift=g,
            exp_factor=exp_factor,
            eval_domain=eval_domain,
        )

    def fri(self) -> fri.Verifier:
        return self.fri_verifier

    def set_adj(self, max_degree: int, chan: Channel):
        assert self.challenges is None
        assert self.adj is None

        assert max_degree < self.trace_len
        self.max_degree = max_degree

        a = rand_int(1, self.P - 1)
        b = rand_int(1, self.P - 1)
        self.challenges = (a, b)

        # Max degree of q(x)
        deg_adj = min_pow2_gt(max_degree)
        assert deg_adj > max_degree

        (a, b) = self.challenges
        self.adj = a * X(deg_adj - max_degree - 1, lambda x: F(x, self.P)) + b

        chan.send(dst="prover", msg=Msg(msg_type="stark_degree_adj", data=(a, b)))

    def set_merkle_roots(self, merkle_roots: (str, str)):
        (f_merkle_root, q_merkle_root) = merkle_roots
        assert self.f_merkle_root is None
        assert self.q_merkle_root is None
        self.f_merkle_root = f_merkle_root
        self.q_merkle_root = q_merkle_root

    # Preliminary checks before queries
    def check(self):
        assert self.q_merkle_root == self.fri_verifier.merkle_roots[0]

    def query(self, idx: int, chan: Channel):
        (fx, qx, f_proof, q_proof) = chan.send(
            dst="prover", msg=Msg(msg_type="stark_prove", data=idx)
        )
        self.verify(idx, fx, qx, f_proof, q_proof)

    def verify(self, idx: int, fx: F, qx: F, f_proof: list[str], q_proof: list[str]):
        x = self.eval_domain[idx]
        cx = self.c(fx)
        zx = self.z(x)
        adjx = self.adj(x)
        assert qx * zx == cx * adjx

        assert merkle.verify(
            f_proof, self.f_merkle_root, merkle.hash_leaf(str(fx)), idx
        )
        assert merkle.verify(
            q_proof, self.q_merkle_root, merkle.hash_leaf(str(qx)), idx
        )
