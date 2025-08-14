# Use extended Euclidean algo for calculating multiplicative inverse
# TODO: how does this work?
def xgcd(x: int, y: int):
    old_r, r = (x, y)
    old_s, s = (1, 0)
    old_t, t = (0, 1)

    while r != 0:
        quotient = old_r // r
        old_r, r = (r, old_r - quotient * r)
        old_s, s = (s, old_s - quotient * s)
        old_t, t = (t, old_t - quotient * t)

    return old_s, old_t, old_r # a, b, g


# Must be a prime field with subgroup of power of 2 order
P = 1 + 407 * (1 << 119)

# Field
class F:
    def __init__(self, v: int, p: int = P):
        self.v = v
        self.p = p

    def wrap(self, v: int):
        return F(v, self.p)

    def inv(self):
        a, _, _ = xgcd(self.v, self.p)
        return self.wrap(a)

    def _check(self, r):
        assert self.p == r.p

    def __add__(self, r):
        self._check(r)
        return self.wrap((self.v + r.v) % self.p)

    def __sub__(self, r):
        self._check(r)
        return self.wrap((self.v - r.v) % self.p)

    def __mul__(self, r):
        self._check(r)
        return self.wrap((self.v * r.v) % self.p)

    def __truediv__(self, r):
        self._check(r)
        assert r.v != 0, "div by 0"
        return self * r.inv()

    def __eq__(self, r):
        self._check(r)
        return (self.v % self.p) == (r.v % self.p)

    def __neq__(self, r):
        self._check(r)
        return (self.v % self.p) != (r.v % self.p)

    def __neg__(self):
        return self.wrap((self.p - x) % self.p)

    def __str__(self):
        return str(self.v)

    def __repr__(self):
        return str(self.v)

ZERO = F(0)
# Generator
G = F(85408008396924667383611388730472331217)

# Primitive nth root, x such that x^n = 1 mod p
def root(n: int) -> F:
    order = 1 << 119
    assert 1 <= n <= order, "n > max"
    assert (n & (n-1)) == 0, "n not power of 2"

    r = G
    while order != n:
        r *= r
        order /= 2
    return r