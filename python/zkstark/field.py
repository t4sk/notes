from __future__ import annotations
from utils import find_prime_divisors


# Use extended Euclidean algo for calculating multiplicative inverse
# TODO: wat dis?
def xgcd(x: int, y: int) -> (int, int, int):
    old_r, r = (x, y)
    old_s, s = (1, 0)
    old_t, t = (0, 1)

    while r != 0:
        quotient = old_r // r
        old_r, r = (r, old_r - quotient * r)
        old_s, s = (s, old_s - quotient * s)
        old_t, t = (t, old_t - quotient * t)

    return old_s, old_t, old_r  # a, b, g


# Field elements
class F:
    def __init__(self, v: int, p: int):
        self.v = v % p
        self.p = p

    def wrap(self, v: int) -> F:
        return F(v, self.p)

    def unwrap(self) -> int:
        return self.v

    def check(self, x: int | F) -> F:
        if isinstance(x, int):
            return self.wrap(x)
        assert self.p == x.p
        return x

    def inv(self) -> F:
        # if p is prime, use Fermat's Little Theorem
        # a^(p - 1) = a * a^(p - 2) = 1 mod p
        # return self.wrap(pow(a, p - 2, p))
        a, _, _ = xgcd(self.v, self.p)
        return self.wrap(a)

    # F + (int | F)
    def __add__(self, x: int | F) -> F:
        x = self.check(x)
        return self.wrap((self.v + x.v) % self.p)

    # (int | F) + F
    def __radd__(self, x: int | F) -> F:
        # Addition is commutative
        return self.__add__(x)

    # F - (int | F)
    def __sub__(self, x: int | F) -> F:
        x = self.check(x)
        return self.wrap((self.v - x.v) % self.p)

    # (int | F) - F
    def __rsub__(self, x: int | F) -> F:
        x = self.check(x)
        return x.__sub__(self)

    # F * (int | F)
    def __mul__(self, x: int | F) -> F:
        x = self.check(x)
        return self.wrap((self.v * x.v) % self.p)

    # (int | F) * F
    def __rmul__(self, x: int | F) -> F:
        # Multiplication is commutative
        return self.__mul__(x)

    # F / (int | F)
    def __truediv__(self, x: int | F) -> F:
        x = self.check(x)
        assert x.v != 0, "div by 0"
        return self * x.inv()

    # (int | F) / F
    def __rtruediv__(self, x) -> F:
        x = self.check(x)
        return x.__truediv__(self)

    # F**int
    def __pow__(self, exp: int) -> F:
        if exp == 0:
            return self.wrap(1)

        if exp < 0:
            return self.inv() ** (-exp)

        return self.wrap(pow(self.v, exp, self.p))

    def __eq__(self, x: int | F) -> bool:
        x = self.check(x)
        return (self.v % self.p) == (x.v % self.p)

    def __neq__(self, x: int | F) -> bool:
        x = self.check(x)
        return (self.v % self.p) != (x.v % self.p)

    def __neg__(self) -> F:
        return self.wrap((self.p - self.v) % self.p)

    def __str__(self):
        return str(self.v)

    def __repr__(self):
        return str(self.v)

    # Used for set keys
    def __hash__(self):
        return hash((self.v, self.p))


def find_generator(p: int) -> int | None:
    # Generator g is an element in F[P], finite field mod P, such that
    # {g^0, g^1, ..., g^(P-1)} = {1, 2, 3, ..., P - 1}

    # Fast way to find g
    # g is a generator of F[P], P prime, iff
    # g^((P-1) / q) != 1 mod P
    # for all q, prime divisors of P - 1

    prime_divs = find_prime_divisors(p - 1)
    for x in range(1, p):
        if all(pow(x, (p - 1) // q, p) != 1 for q in prime_divs):
            return x
    return None


def generate(g: int, n: int, p: int) -> list[int]:
    """
    g = generator of F[P, *]
    n = order of subgroup G to generate
    p = prime number P
    """
    assert n <= p

    G = [0] * n
    G[0] = 1
    for i in range(1, n):
        G[i] = (G[i - 1] * g) % p
        assert G[i] != 1, f"g^{i} = 1"

    # Check g^n = 1
    assert (G[-1] * g) % p == 1, f"g^{n} = {(G[-1] * g) % p}"
    assert len(set(G)) == n

    return G


# Primitive Nth root of unity
def get_primitive_root(g: int, n: int, p: int) -> int:
    # F[P, *] = Multiplicative subgroup of F[P] = {1, 2, 3, ..., P - 1}
    # g = generator of F[P, *]
    # |F[P, *]| = P - 1
    # If k divides P - 1, then g^k generates a group of size (P - 1) / k
    # (P - 1) / k = n -> k = (P - 1) / n
    k = (p - 1) // n
    return pow(g, k, p)
