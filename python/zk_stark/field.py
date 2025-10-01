from __future__ import annotations

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

    return old_s, old_t, old_r # a, b, g


# Must be a prime field with subgroup of power of 2 order
# P = 1 + 407 * (1 << 119)
P = (1 << 4) + 1

# Field
class F:
    def __init__(self, v: int, p: int = P):
        self.v = v % p
        self.p = p

    def wrap(self, v: int) -> F:
        return F(v, self.p)

    def inv(self) -> F:
        a, _, _ = xgcd(self.v, self.p)
        return self.wrap(a)

    def _check(self, x: F):
        assert self.p == x.p

    def __add__(self, x: F):
        self._check(x)
        return self.wrap((self.v + x.v) % self.p)

    def __sub__(self, x: F):
        self._check(x)
        return self.wrap((self.v - x.v) % self.p)

    def __mul__(self, x: F):
        self._check(x)
        return self.wrap((self.v * x.v) % self.p)

    def __truediv__(self, x: F):
        self._check(x)
        assert x.v != 0, "div by 0"
        return self * x.inv()

    def __pow__(self, exp: int):
        if exp == 0:
            return self.wrap(1)
        
        if exp < 0:
            return self.inv() ** (-exp)

        return self.wrap(pow(self.v, exp, self.p))
        
        # Fast exponentiation (square and multiply)
        # y = self.wrap(1)
        # base = self.wrap(self.v)
        
        # while exp > 0:
        #     if exp % 2 == 1:
        #         y *= base
        #     base *= base
        #     exp //= 2
        
        # return y

    def __eq__(self, x):
        self._check(x)
        return (self.v % self.p) == (x.v % self.p)

    def __neq__(self, x):
        self._check(x)
        return (self.v % self.p) != (x.v % self.p)

    def __neg__(self):
        return self.wrap((self.p - self.v) % self.p)

    def __str__(self):
        return str(self.v)

    def __repr__(self):
        return str(self.v)

Z = F(0)

# TODO: remove?
# Primitive Nth root
# g such that g^N = 1 mod p
# and g^k != 1 mod P for all 0 < k < N
# g generates a cyclic group of order N under multiplication
def primitive_root(w: int, k: int) -> F:
    order = 1 << 119
    assert 1 <= k <= order, "n > max"
    assert (k & (k-1)) == 0, "n not power of 2"

    x = g
    while order != n:
        x *= x
        order //= 2
    return x