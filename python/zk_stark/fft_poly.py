from field import F
from polynomial import Polynomial
from fft import fft, ifft
from utils import padd

# Evaluates polynomial using FFT
def eval(f: Polynomial, ws: list[int], p: int, shift: int = 1) -> list[F]:
    """
    ws = Nth roots of unity
    p = prime number
    """
    # Evaluation domain = [shift * w for w in ws]
    # Define Q(x) = P(ax)
    #        Q(w^i) = P(aw^i)
    q = f.scale(shift)
    cs = [c.unwrap() for c in q.cs]
    # Evaluation domain is larger than degree of polynomial so padd with 0
    cs = padd(cs, len(ws), 0)
    ys = fft(cs, ws, p)
    return [F(y, p) for y in ys]


# Interpolates polynomial using inverse FFT
def interp(ys: list[int | F], ws: list[int], p: int, shift: int = 1) -> Polynomial:
    # Evaluation domain = [shift * w for w in ws]
    # Define Q(x) = P(ax)
    #        Q(w^i) = P(aw^i)
    #        Q(x/a) = P(x)
    ys = [y if isinstance(y, int) else y.unwrap() for y in ys]
    cs = ifft(ys, ws, p)
    q = Polynomial(cs, lambda x: F(x, p))
    s_inv = F(shift, p).inv()
    return q.scale(s_inv)


# Calculate polynomial q = c / z
def div(c: Polynomial, z: Polynomial, ws: list[int], p: int, shift: int = 1) -> Polynomial:
    """
    z(w) = 0 for all w in ws and z(x) != 0 for all x = shift * w
    """
    assert c.degree() >= z.degree()
    cx = eval_poly(c, ws, p, shift)
    zx = eval_poly(z, ws, p, shift)
    assert all(y != 0 for y in zx)
    return interp_poly([ci / zi for (ci, zi) in zip(cx, zx)], ws, p, shift)
