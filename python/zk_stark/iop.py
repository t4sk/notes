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


class IStarkProver(ABC):
    @abstractmethod
    def fri(self) -> IFriProver:
        pass

    @abstractmethod
    def prove(idx: int) -> (F, F, list[str], list[str]):
        pass


class IStarkVerifier(ABC):
    @abstractmethod
    def fri(self) -> IFriVerifier:
        pass

    @abstractmethod
    def set_adj(self, max_degree: int) -> (int, int):
        pass


class Msg:
    def __init__(self, **kwargs):
        self.type = kwargs["msg_type"]
        self.data = kwargs.get("data", None)


class Prover:
    def __init__(self, prover: IStarkProver):
        self.prover = prover

    def reply(self, msg: Msg):
        match msg.type:
            case "fri_prove":
                return self.prover.fri().prove(msg.data)
            case "stark_prove":
                return self.prover.prove(msg.data)
            case _:
                raise ValueError(f"Invalid msg type: {msg.type}")
        return None


class Verifier:
    def __init__(self, verifier: IStarkVerifier):
        self.verifier = verifier

    def reply(self, msg: Msg):
        match msg.type:
            case "stark_degree_adj":
                return self.verifier.set_adj(msg.data)
            case "stark_merkle_roots":
                self.verifier.set_merkle_roots(msg.data)
            case "fri_merkle_root":
                self.verifier.fri().push_merkle_root(msg.data)
            case "fri_get_challenge":
                return self.verifier.fri().get_challenge()
            case _:
                raise ValueError(f"Invalid msg type: {msg.type}")
        return None


class Channel:
    def __init__(self, receiver):
        self.receiver = receiver

    def send(self, msg: Msg):
        return self.receiver.reply(msg)
