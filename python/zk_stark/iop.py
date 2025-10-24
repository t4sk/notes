# Interactive oracle proof
from abc import ABC, abstractmethod
from field import F


# Interfaces
class IFriProver(ABC):
    @abstractmethod
    def prove(self, idx: int) -> (list[(F, F)], list[(list[str], list[str])], list[F]):
        pass


class IFriVerifier(ABC):
    @abstractmethod
    def push_merkle_root(self, val: str):
        pass

    @abstractmethod
    def get_challenge(self) -> int:
        pass


class Msg:
    def __init__(self, **kwargs):
        self.type = kwargs["msg_type"]
        self.data = kwargs.get("data", None)


class Prover:
    def __init__(self, fri_prover: IFriProver):
        self.fri_prover = fri_prover

    def reply(self, msg: Msg):
        match msg.type:
            case "prove":
                return self.fri_prover.prove(msg.data)
            case _:
                raise ValueError(f"Invalid msg type: {msg.type}")
        return None


class Verifier:
    def __init__(self, fri_verifier: IFriVerifier):
        self.fri_verifier = fri_verifier

    def reply(self, msg: Msg):
        match msg.type:
            case "merkle_root":
                self.fri_verifier.push_merkle_root(msg.data)
            case "get_challenge":
                return self.fri_verifier.get_challenge()
            case _:
                raise ValueError(f"Invalid msg type: {msg.type}")
        return None


class Channel:
    def __init__(self, receiver):
        self.receiver = receiver

    def send(self, msg: Msg):
        return self.receiver.reply(msg)

