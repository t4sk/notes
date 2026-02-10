from calc import calc_dya
from data import get, build, map_sqrt

# TODO: fees from arg
fee_a = 0.0005
fee_b = 0.003

# TODO: file path
ticks_a, liqs_a, pool_a = build(get("tmp/pool_a.json"), True)
ticks_b, liqs_b, pool_b = build(get("tmp/pool_b.json"), False)

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

# TODO: multiply + cast to int
print(dya)