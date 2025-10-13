# Interactive oracle proof
import hashlib


def fiat_shamir(s: str) -> int:
    h = hashlib.sha256(s.encode()).digest()
    return int.from_bytes(h, "big")


class Writer:
    def __init__(self):
        self.merkle_roots: list[str] = []
        self.challenges: list[int] = []

    def send(self, merkle_root: str):
        self.merkle_roots.append(merkle_root)

    def get_challenge(self) -> int:
        c = fiat_shamir(str(self.merkle_roots))
        self.challenges.append(c)
        return c


class Reader:
    pass

