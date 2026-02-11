#!/usr/bin/env python3
import sys
from calc import calc_dya, sqrt_p_to_tick
from data import get, build, map_sqrt


def abi_encode_uint(x):
    return x.to_bytes(32, byteorder="big").hex()


path_a = sys.argv[1]
path_b = sys.argv[2]
fee_a = int(sys.argv[3]) / 1e6
fee_b = int(sys.argv[4]) / 1e6

ticks_a, liqs_a, pool_a = build(get(path_a), True)
ticks_b, liqs_b, pool_b = build(get(path_b), False)

# First tick lo
tick_a = pool_a[0][0]
# First tick hi
tick_b = pool_b[0][1]

(dya, dyb, sa, sb) = calc_dya(
    map_sqrt(pool_a),
    map_sqrt(pool_b),
    fee_a,
    fee_b,
)

dya = int(dya * 1e18)
dyb = int(dyb * 1e18)
ta = sqrt_p_to_tick(sa)
tb = sqrt_p_to_tick(sb)

print(
    abi_encode_uint(dya)
    + abi_encode_uint(dyb)
    + abi_encode_uint(ta)
    + abi_encode_uint(tb)
)
