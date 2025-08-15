from field import F, P

def get(xs, i, default_val):
    return xs[i] if i < len(xs) else default_val

def wrap(x, f: lambda x: F(x, P)):
    if isinstance(x, type(f(0))):
        return x
    else:
        return f(x)

def div(p, d):
    assert p.z == d.z
    assert d != Polynomial([], d.f), "div by 0"

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
    def __init__(self, cs, f = lambda x: F(x, P)):
        z = f(0)
        # Remove trailing 0s
        cs = cs[:]
        while len(cs) > 0 and wrap(cs[-1], f) == z:
            cs.pop()

        if len(cs) == 0:
            cs.append(z)

        self.cs = [wrap(c, f) for c in cs]
        self.f = f
        self.z = z

    def degree(self):
        l = len(self.cs)
        assert l > 0
        return l - 1

    def __neg__( self ):
        return Polynomial([-c for c in self.cs], self.f)
    
    def __add__(self, r):
        ls = self.cs
        rs = r.cs
        cs = [self.z] * max(len(ls), len(rs))
        for i in range(len(cs)):
            a = get(ls, i, self.z)
            b = get(rs, i, self.z)
            cs[i] = a + b
        return Polynomial(cs, self.f)

    def __sub__(self, r):
        return self.__add__(-r)

    def __mul__(self, r):
        m = len(self.cs)
        n = len(r.cs)
        ls = self.cs
        rs = r.cs

        # degree = len(cs) - 1
        # degree(self) + degree(r) = len(cs) - 1
        # len(cs) = degree(self) + degree(r) + 1
        #         = len(self.cs) - 1 + len(r.cs) - 1 + 1
        cs = [self.z] * (m + n - 1)
        for i in range(m):
            for j in range(n):
                cs[i + j] += ls[i] * rs[j]

        return Polynomial(cs, self.f)

    def __truediv__(self, d):
        q, r = div(self, d)
        assert r == Polynomial([], self.f), "remainder != 0"
        return q

    def __eq__(self, r):
        return self.cs == r.cs

    def __neq__(self, r):
        return self.cs != r.cs

    def __str__(self):
        return str(self.cs)

    def __repr__(self):
        return str(self.cs)

def poly_eval(p: Polynomial, x, f = lambda x: F(x, P)):
    x = wrap(x, f)
    y = f(0)
    xi = f(1)
    for c in p.cs:
        y += c * xi
        xi *= x
    return y
