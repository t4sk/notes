U32_MAX = 2**32 - 1
U64_MAX = 2**64 - 1
U128_MAX = 2**128 - 1

def bit_not(x, bits):
    return (1 << bits) - 1 - x