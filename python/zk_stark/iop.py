# Interactive oracle proof
import hashlib


def fiat_shamir(s: str) -> int:
    h = hashlib.sha256(s.encode()).digest()
    return int.from_bytes(h, "big")


class Msg:
    def __init__(self, **kwargs):
        self.type = kwargs["msg_type"]
        self.data = kwargs.get("data", None)


class Prover:
    def __init__(self, fri_prover):
        self.fri_prover = fri_prover

    def reply(self, msg: Msg):
        match msg.type:
            case "prove":
                return self.fri_prover.prove(msg.data)
            case _:
                raise ValueError(f'Invalid msg type: {msg.type}')
        return None
            

class Verifier:
    def __init__(self, fri_verifier):
        self.fri_verifier = fri_verifier

    def reply(self, msg: Msg):
        match msg.type:
            case "merkle_root":
                self.fri_verifier.push("merkle_root", msg.data)
            case "get_challenge":
                c = fiat_shamir(str(self.fri_verifier.merkle_roots))
                self.fri_verifier.push("challenge", c)
                return c
            case _:
                raise ValueError(f'Invalid msg type: {msg.type}')
        return None


class Channel:
    def __init__(self, receiver):
        self.receiver = receiver

    def send(self, msg: Msg):
        return self.receiver.reply(msg)