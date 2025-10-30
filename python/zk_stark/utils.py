import hashlib
import math
import random


def fiat_shamir(s: str) -> int:
    h = hashlib.sha256(s.encode()).digest()
    return int.from_bytes(h, "big")


def rand_int(lo: int, hi: int) -> int:
    return random.randint(lo, hi)


def padd(xs, n, x):
    assert len(xs) <= n
    xs.extend([x] * (n - len(xs)))
    return xs


def is_pow2(x: int) -> bool:
    return x > 0 and (x & (x - 1)) == 0


# Position of the most significant bit from x = power of 2
def msb_pow2(x: int) -> int:
    assert is_pow2(x), f"{x} is not a power of 2"
    return x.bit_length() - 1


# Smallest power of 2 greater than x
def min_pow2_gt(x: int) -> int:
    assert x >= 0
    if x == 0:
        return 1
    k = math.floor(math.log2(x)) + 1
    return 2**k


# Largest k such that 2**k divides x
def max_log2(x: int) -> int:
    assert x >= 0
    if x == 0:
        return 0

    k = 0
    while x % 2 == 0:
        x //= 2
        k += 1
    return k


def is_prime(x: int) -> bool:
    if x < 2:
        return False
    if x == 2:
        return True
    if x % 2 == 0:
        return False
    for i in range(3, int(x**0.5), 2):
        if x % i == 0:
            return False
    return True


def find_prime_divisors(n: int) -> list[int]:
    divisors = []
    d = 2

    # Check divisibility by all numbers up to sqrt(n)
    while d * d <= n:
        if n % d == 0:
            divisors.append(d)
            # Remove all factors of d
            while n % d == 0:
                n //= d
        # After 2, check only odd numbers
        d += 1 if d == 2 else 2

    # If there's anything left of n, it's a prime
    if n > 1:
        divisors.append(n)

    return divisors
