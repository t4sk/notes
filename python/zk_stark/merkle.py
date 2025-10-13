import hashlib


def hash_leaf(leaf: str) -> str:
    # return f'h({leaf})'
    return hashlib.sha256(leaf.encode()).hexdigest()


def hash_pair(left: str, right: str) -> str:
    # return f'h({left}, {right})'
    return hashlib.sha256((left + right).encode()).hexdigest()


def commit(hs: list[str]) -> str:
    tree = [hs[:]]
    n = len(hs)
    while n > 1:
        tree.append([])
        for i in range(0, n, 2):
            left = tree[-2][i]
            right = tree[-2][min(i + 1, n - 1)]
            tree[-1].append(hash_pair(left, right))
        n = (n + 1) >> 1
    return tree[-1][0]


def open(hs: list[str], index: int) -> list[str]:
    hs = hs[:]
    proof = []
    n = len(hs)
    k = index
    while n > 1:
        h = hs[k - 1 if k & 1 else min(k + 1, n - 1)]
        proof.append(h)
        k >>= 1

        for i in range(0, n, 2):
            left = hs[i]
            right = hs[min(i + 1, n - 1)]
            hs[i >> 1] = hash_pair(left, right)
        n = (n + 1) >> 1
    return proof


def verify(proof: list[str], root: str, leaf_hash: str, index: int) -> bool:
    h = leaf_hash
    i = index
    for p in proof:
        (left, right) = (h, p) if i & 1 == 0 else (p, h)
        h = hash_pair(left, right)
        i >>= 1
    return h == root

