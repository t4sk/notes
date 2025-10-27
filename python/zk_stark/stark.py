from polynomial import Polynomial, X
from field import F
import fft_poly
from utils import is_prime, is_pow2, min_pow2_gt

class Prover:
    def __init__(self, **kwargs):
        # Prime number
        p: int = kwargs["p"]
        # generator of F[P, *] = multiplicative subgroup of prime field P
        g: int = kwargs["g"]

        # Trace polynomial
        f: Polynomial = kwargs["f"]
        # Trace evaluation domain
        trace_eval_domain: list[int] = kwargs["trace_eval_domain"]
        trace_len = len(trace_eval_domain)
        assert is_pow2(trace_len)
        assert f.degree() < trace_len

        # Constraint polynomial
        c: Polynomial = kwargs["c"]
        # Constraint polynomial evaluation domain
        constraint_eval_domain: list[int] = kwargs["constraint_eval_domain"]
        assert len(constraint_eval_domain) >= trace_len
        assert is_pow2(constraint_eval_domain)

        # Nth roots of unity
        roots: list[int] = kwargs["roots"]
        N = len(roots)
        # FRI and STARK evaluation domain are shifted by g so that
        # trace_eval_domain and eval_domain are disjoint
        eval_domain = [(g * w) % p for w in roots]

        assert len(set(eval_domain)) == N, f'|eval_domain| = {len(set(eval_domain))}'
        assert (set(eval_domain) & set(trace_eval_domain)) == set(), f'eval_domain and trace_eval_domain are not disjoint {set(eval_domain) & set(trace_eval_domain)}'

        # Let G = trace_eval_domain
        #     L = Nth roots of unity
        # G and L are subgroups of F[P, *] -> |G| and |L| divides |F[P, *]| = P - 1
        assert (p - 1) % trace_len == 0
        assert (p - 1) % N == 0

        # Expansion factor, exp_factor * trace_len = N = size of eval_domain
        ext_factor: int = kwargs["ext_factor"]
        assert is_pow2(ext_factor)
        assert ext_factor * trace_len == N

        # z(x) = (x - g^0)(x - g^1)...(x - g^(T-1)) = x^T - 1, where T = trace_len
        z: Polynomial = X(trace_len, lambda x: F(x, p)) - 1

        # Quotient polynomial q(x) = c(x) / z(x)
        q = fft_poly.div(c, z, constraint_eval_domain, p, g)

        # Degree adjustment
        # Let max_degree = highest degree of all C[j] where C[j] are constraint polynomials
        # Let D = 2**k where k is smallest such that D > max_degree
        # Adjust degree of C[j] to D - 1
        # Given C[j] with degree of C[j] = D[j]
        # Degree adjusted polynomial = C[j](x) * (A[j] * x^(D - D[j] - 1) + B[j])
        # where A[j] and B[j] are random values provided by the verifier
        max_degree = q.degree()
        deg_adj = min_pow2_gt(max_degree)
        assert deg_adj > max_degree

        # TODO: get challenges from verifier
        a = 1
        b = 2
        adj = a * X(deg_adj - max_degree - 1, lambda x: F(x, P)) + b
        q = q * adj
        assert is_pow2(q.degree() + 1)
        assert q.degree() == T - 1

        self.p: int = p
        self.g: int = g
        self.ext_factor: int = ext_factor
        self.eval_domain: list[int] = eval_domain
        self.roots: list[int] = roots
        self.N: int = N

        self.f: Polynomial = f
        self.c: Polynomial = c
        self.z: Polynomial = z
        self.q: Polynomial = q

        self.f_hashes: list[str] = []
        self.q_hashes: list[str] = []
        self.f_merkle_root: str | None = None
        self.q_merkle_root: str | None = None

    def commit(self):
        # f(L)
        fx = fft_poly.eval(self.f.scale(self.g), self.roots, self.p, self.g)
        # q(L)
        qx = fft_poly.eval(self.q.scale(self.g), self.roots, self.p, self.g)
        self.f_hashes = [merkle.hash_leaf(str(y)) for y in fx]
        self.q_hashes = [merkle.hash_leaf(str(y)) for y in qx]
        self.f_merkle_root = merkle.commit(self.f_hashes)
        self.q_merkle_root = merkle.commit(self.q_hashes)

    def prove(i: int) -> (int, F, F, list[str], list[str]):
        x = self.eval_domain[i]
        fx = self.f(x)
        qx = self.q(x)
        f_proof = merkle.open(self.f_hashes, i)
        q_proof = merkle.open(self.q_hashes, i)
        return (x, fx, qx, f_proof, q_proof)


class Verifier:
    def __init__(self, **kwargs):
        # Prime number
        p: int = kwargs["p"]
        # generator of F[P, *] = multiplicative subgroup of prime field P
        g: int = kwargs["g"]

        # Trace evaluation domain
        trace_eval_domain: list[int] = kwargs["trace_eval_domain"]
        trace_len = len(trace_eval_domain)
        assert is_pow2(trace_len)

        # Constraint polynomial given a value y = f(x), c(y) must = 0
        c: Polynomial = kwargs["c"]

        # Nth roots of unity
        roots: list[int] = kwargs["roots"]
        N = len(roots)
        # FRI and STARK evaluation domain are shifted by g so that
        # trace_eval_domain and eval_domain are disjoint
        eval_domain = [(g * w) % p for w in roots]

        self.p: int = p
        self.g: int = g

    def verify(self):
        pass