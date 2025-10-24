from __future__ import annotations
from typing import Callable
from field import F


# Generic getter
def get(xs, i, default_val):
    return xs[i] if i < len(xs) else default_val


# Wraps x with f(x)
def wrap(x, f):
    if isinstance(x, type(f(0))):
        return x
    else:
        return f(x)


def div(p: Polynomial, d: Polynomial) -> (Polynomial, Polynomial):
    assert p.z == d.z
    assert d != 0, "div by 0"

    f = p.f
    z = p.z
    m = p.degree()
    n = d.degree()
    if m < n:
        return Polynomial([], f), Polynomial(p.cs, f)

    q = [z] * (m - n + 1)
    r = Polynomial(p.cs[:], f)

    for i in range(m - n + 1):
        if r.degree() < n:
            break
        c = r.cs[-1] / d.cs[-1]
        s = r.degree() - n
        r -= Polynomial([z] * s + [c], f) * d
        q[s] = c

    return Polynomial(q, f), r


class Polynomial:
    def __init__(self, cs: list[int] | list[F], f=lambda x: x):
        z = f(0)
        # Remove trailing 0s
        cs = cs[:]
        while len(cs) > 0 and wrap(cs[-1], f) == z:
            cs.pop()

        if len(cs) == 0:
            cs = [z]

        self.cs = [wrap(c, f) for c in cs]
        self.f = f
        self.z = z

    def degree(self):
        l = len(self.cs)
        assert l > 0
        return l - 1
    
    def wrap(self, cs: list[int] | list[F]) -> Polynomial:
        return Polynomial(cs, self.f)

    def unwrap(self) -> list[int] | list[F]:
        return self.cs

    def check(self, p: int | F | list[int] | list[F] | Polynomial) -> Polynomial:
        if isinstance(p, Polynomial):
            assert self.z == p.z
            return p
        if isinstance(p, list):
            return self.wrap(p)
        # int or F
        return self.wrap([p])

    def __neg__(self) -> Polynomial:
        return self.wrap([-c for c in self.cs])

    def __add__(self, q: int | F | list[int] | list[F] | Polynomial) -> Polynomial:
        q = self.check(q)
        # p + q
        ps = self.cs
        qs = q.cs
        cs = [self.z] * max(len(ps), len(qs))
        for i in range(len(cs)):
            a = get(ps, i, self.z)
            b = get(qs, i, self.z)
            cs[i] = a + b
        return self.wrap(cs)

    def __radd__(self, q: int | F | list[int] | list[F] | Polynomial) -> Polynomial:
        return self.__add__(q)
        
    def __sub__(self, q: int | F | list[int] | list[F] | Polynomial) -> Polynomial:
        q = self.check(q)
        return self.__add__(-q)

    def __rsub__(self, q: int | F | list[int] | list[F] | Polynomial) -> Polynomial:
        q = self.check(q)
        return q.__sub__(self)
    
    def __mul__(self, q: int | F | list[int] | list[F] | Polynomial) -> Polynomial:
        q = self.check(q)
        # p * q
        m = len(self.cs)
        n = len(q.cs)
        ps = self.cs
        qs = q.cs

        # degree = len(cs) - 1
        # degree(self) + degree(q) = len(cs) - 1
        # len(cs) = degree(self) + degree(q) + 1
        #         = len(self.cs) - 1 + len(q.cs) - 1 + 1
        cs = [self.z] * (m + n - 1)
        for i in range(m):
            for j in range(n):
                cs[i + j] += ps[i] * qs[j]

        return self.wrap(cs)

    def __rmul__(self, q: int | F | list[int] | list[F] | Polynomial) -> Polynomial:
        return self.__mul__(q)

    def __truediv__(self, d: int | F | list[int] | list[F] | Polynomial) -> Polynomial:
        d = self.check(d)
        q, r = div(self, d)
        assert r == 0, "remainder != 0"
        return q

    def __rtruediv__(self, q: int | F | list[int] | list[F] | Polynomial) -> Polynomial:
        q = self.check(q)
        return q.__truediv__(self)

    def __eq__(self, q: int | F | list[int] | list[F] | Polynomial) -> bool:
        q = self.check(q)
        return self.cs == q.cs

    def __neq__(self, q: int | F | list[int] | list[F] | Polynomial) -> bool:
        q = self.check(q)
        return self.cs != q.cs

    def __str__(self):
        return str(self.cs)

    def __repr__(self):
        return str(self.cs)

    # Evaluate polynomial P(x)
    def __call__(self, x: int | F | list[int] | list[F]):
        # x is a list
        if isinstance(x, list):
            return [self(wrap(xi, self.f)) for xi in x]

        # x is int
        f = self.f
        x = wrap(x, f)
        y = f(0)
        xi = f(1)
        for c in self.cs:
            y += c * xi
            xi *= x
        return y


# Polynomial x^n
def X(n: int, f = lambda x: x) -> Polynomial:
    cs = [0] * (n + 1)
    cs[-1] = 1
    return Polynomial(cs, f)


# Lagrange interpolatin
# Polynomial with L(xi) = yi for (x0, y0), (x1, y1), ... , (xn, yn)
def interp(xs: list[int | F], ys: list[int | F], f=lambda x: x) -> Polynomial:
    assert len(xs) == len(ys)

    xs = [wrap(x, f) for x in xs]
    ys = [wrap(y, f) for y in ys]

    z = f(0)
    p = Polynomial([], f)
    x = Polynomial([0, 1], f)
    for i in range(len(xs)):
        l = Polynomial([ys[i]], f)
        for j in range(len(xs)):
            if j != i:
                xj = Polynomial([xs[j]], f)
                d = Polynomial([xs[i] - xs[j]], f)
                l *= (x - xj) / d
        p += l

    return p
