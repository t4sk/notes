#!/usr/bin/env python3
import sys

# chmod +x dev.py
a = int(sys.argv[1])
b = int(sys.argv[2])


def abi_encode_uint(x):
    return x.to_bytes(32, byteorder="big").hex()


print(abi_encode_uint(a + b) + abi_encode_uint(a * b))
