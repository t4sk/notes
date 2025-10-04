import merkle
from field import F
from polynomial import Polynomial
from utils import is_pow2, is_prime

def domain(w: int, n: int, p: int):
    """
    w is primitive nth root mod p
    p is prime
    """
    d = [pow(w, i, p) for i in range(0, n)]
    assert len(set(d)) == n, f'|d| != {n}'
    return d

class Prover:
    def __init__(self, **kwargs):
        # Prime
        P = kwargs["P"]
        # Initial domain size
        N = kwargs["N"]
        # Primitive Nth root
        w = kwargs["w"]
        # Polynomial
        poly = kwargs["poly"]
        # Interactive oracle proof
        iop = kwargs["iop"]

        assert is_prime(P), f'{P} is not prime'
        assert is_pow2(N), f'{N} is not a power of 2'
        assert poly.degree() + 1 < N < P

        assert poly.z == F(0, P), f'Incorrect polynomial field'

        self.P: int = P
        self.N: int = N
        self.w: int = w
        self.poly: Polynomial = poly
        self.iop = iop
        # Function to wrap x: int into F(x, P)
        self.wrap = lambda x: F(x, P)
        
        self.challenges: list[F] = []
        self.codewords: list[list[F]] = []

    def commit(self):
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
        # Domain size
        n = self.N
        # fi
        fi = self.poly
        # wi = w**(2**i)
        wi = self.w
        while n > 0:
            # Evaluation domain
            Li = domain(wi, n, self.P)
            # RS code
            codeword = fi(Li)
            self.codewords.append(codeword)

            # Commit Merkle root
            merkle_root = merkle.commit([merkle.hash_leaf(str(c)) for c in codeword])
            self.iop.send(merkle_root)
            # Get random challenge
            c = F(self.iop.get_challenge(), self.P)
            self.challenges.append(c)
            # Fold
            f_even = Polynomial(fi.cs[0::2], self.wrap)
            f_odd = Polynomial(fi.cs[1::2], self.wrap)
            c = Polynomial([c], self.wrap) 
            f_fold = f_even + c * f_odd
            
            # Next loop
            n //= 2
            wi *= wi
            fi = f_fold        

    def prove(self, idx: int):
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

        TODO: comment about correlated method of query / proving

        for primitive Nth root of unity w and N is even
        w^(N/2) = -1 mod P so
        -w^k = -1 * w^k = w^(N/2 + k)
        """
        i = 0
        n = self.N
        wi = self.w

        while n > 0:
            assert idx < n, f'index {idx} > {n}"
            # fi(x) and fi(-x)
            idx_plus = idx
            idx_minus = (n // 2 + idx) % n
            f_plus = self.codewords[i][idx_plus]
            f_minus = self.codewords[i][idx_minus]
            # Merkle proof
            hs = merkle.hash_leaf(str(c)) for c in codeword]
            proof_plus = merkle.open(hs, idx_plus)
            proof_minus = merkle.open(hs, idx_minus)

            # Next loop
            i += 1
            n //= 2
            # TODO where are the next indexes?y
            # 0 1 2 3 4 5 6 7 (8)
            # 0 2 4 6 (4)
            

class Verifier:
    def query(self, idx: int):
        pass

    def verify(self):
        pass









