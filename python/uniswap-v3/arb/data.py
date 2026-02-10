import math
import json
from calc import tick_to_sqrt_p


class Liquidity:
    def __init__(self, **kwargs):
        self.lo: int = kwargs["lo"]
        self.hi: int = kwargs["hi"]
        self.net: int = kwargs["net"]
        self.liq: int = kwargs["liq"]

        assert self.lo <= self.hi, "lo > hi"
        assert self.liq >= 0, "liq < 0"

    def __str__(self):
        return f"Liquidity(lo={self.lo}, hi={self.hi}, liq={self.liq}, net={self.net})"


def get(file_path: str) -> list[Liquidity]:
    with open(file_path) as f:
        return [Liquidity(**entry) for entry in json.load(f)]


def build(
    data: list[Liquidity], asc: bool
) -> tuple[list[int], list[int], list[tuple[int, int, int]]]:
    assert len(data) > 0

    # Ticks are decreasing
    # Reverse the list to make it increasing
    if not asc:
        data.reverse()

    # Check ticks are increasing
    t = -math.inf
    for l in data:
        assert t <= l.lo < l.hi
        assert l.liq >= 0
        t = l.lo

    ticks = []
    liqs = []
    for l in data:
        ticks.append(l.lo)
        liqs.append(l.liq)

        ticks.append(l.hi)
        liqs.append(l.liq)

    pool = [(l.lo, l.hi, l.liq) for l in data]
    # Reverse list to make ticks decreasing
    if not asc:
        pool.reverse()

    return ticks, liqs, pool


def map_sqrt(pool: list[tuple[int, int, int]]) -> list[tuple[float, float, int]]:
    return [(tick_to_sqrt_p(lo), tick_to_sqrt_p(hi), liq) for (lo, hi, liq) in pool]
