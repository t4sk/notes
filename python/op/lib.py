U32_MAX = 2**32 - 1
U64_MAX = 2**64 - 1
U128_MAX = 2**128 - 1

def bit_not(x, bits):
    return (1 << bits) - 1 - x

def hex_to_bytes32(hex_str: str) -> bytes:
    if hex_str.startswith("0x"):
        hex_str = hex_str[2:]
    
    padded = hex_str.zfill(64)
    return f'0x{padded}'