def is_pow2(x: int) -> bool:
    return x > 0 and (x & (x - 1)) == 0

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