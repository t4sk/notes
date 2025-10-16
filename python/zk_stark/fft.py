# Number Theoretic Transform (NTT) - FFT on modular arithmetic


# Recursive fft
def fft_rec(f: list[int], ws: list[int], p: int) -> list[int]:
    """
    f = polynomial of degree < N
    ws[i] = w^i, where w is a N-th primitive root of unity
    p = x mod p
    Returns [f(ws[0]), f(ws[1]), ..., f(ws[N-1])]
    """
    n = len(f)
    assert n & (n - 1) == 0, f"{n} is not a power of 2"
    assert len(ws) == n, f'{len(ws)} != {n}'

    if n == 1:
        return f

    # Optional - check x is a Nth primitive root of unity
    w = ws[1]
    assert pow(w, n, p) == 1, f"{w}^{n} mod {p} != 1"
    assert pow(w, n // 2, p) == p - 1, f"{w}^({n} / 2) mod {p} != -1"

    f_even = fft_rec(f[::2], ws[::2], p)
    f_odd = fft_rec(f[1::2], ws[::2], p)
    ys = [0] * n

    h = n // 2
    for i in range(h):
        # -1 = w^(n/2)
        # -w^i = -1 * w^i = w^(n/2 + i)
        # f(x)  = f_even(x^2) + x * f_odd(x^2)
        # f(-x) = f_even(x^2) - x * f_odd(x^2)
        ys[i] = (f_even[i] + ws[i] * f_odd[i]) % p
        ys[h + i] = (f_even[i] - ws[i] * f_odd[i]) % p

    return ys


# FFT without recursion
# Evaluates polynomial f at N points (ws)
def fft(f: list[int], ws: list[int], p: int) -> list[int]:
    n = len(f)
    assert n & (n - 1) == 0, f"{n} is not a power of 2"
    assert len(ws) == n, f'{len(ws)} != {n}'

    ys = [0] * n

    # Map final positions of evens and odds to ys
    # Bit reversal
    # Starting index = reverse of final index
    rev = 0
    for i in range(N):
        ys[i] = f[rev]
        # Carry from left to right
        mask = N >> 1
        while rev & mask:
            # Set 0 where mask has a 1
            rev &= ~mask
            # Shift 1 to the right
            mask >>= 1
        # Put 1 at the correct bit position after carry
        rev |= mask

    # Merge
    k = n
    s = 2
    while k > 1:
        for i in range(0, n, s):
            h = s // 2
            for j in range(i, i + h):
                f_even = ys[j]
                f_odd = ys[j + h]
                # wi = (w^j)^k = w^(j * k % n) at loop k,
                #      so the wi at next loop = w^(j * (k // 2) % n)
                wi = ws[(j * (k // 2)) % n]

                ys[j] = (f_even + wi * f_odd) % p
                ys[j + h] = (f_even - wi * f_odd) % p

        s *= 2
        k //= 2

    return ys


# Inverse FFT
# Interpolates a polynomial of degree < N from N evaluations (ys)
# inverse fft = N^(-1) * fft(ys, [1, w^(-1), w^(-2), ..., w^(-(N-1))], p)
def ifft(ys: list[int], ws: list[int], p: int) -> list[int]:
    n = len(ys)
    # x = a^(-1) mod P
    # x * a^(-1) = 1 mod P
    # Fermat's Little Theorem
    # a^(P - 1) = 1 mod P so a^(P - 2) = a^(-1)
    n_inv = pow(n, p - 2, p)
    # w^(-i) = w^((N - i) % N)
    ws_inv = [0] * n
    ws_inv[0] = ws[0]
    for i in range(1, n):
        ws_inv[i] = ws[n - i]

    return [(n_inv * c) % p for c in fft(ys, ws_inv, p)]


# Evaluate polynomial as xs, used to check outputs of FFT
def eval_poly(f: list[int], xs: list[int], p: int) -> list[int]:
    ys = [0] * len(xs)
    for i, xi in enumerate(xs):
        x = 1
        y = 0
        for c in f:
            y += c * x
            x *= xi
        y %= p
        ys[i] = y

    return ys
