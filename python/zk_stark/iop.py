# Interactive oracle proof
from __future__ import annotations
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
        self.inbox: list[Msg] = []

    def recv(self, msg: Msg, chan: Channel):
        match msg.type:
            case "stark_degree_adj":
                self.inbox.append(msg)
            case "stark_prove":
                self.prover.prove(msg.data, chan)
            case "fri_challenge":
                self.inbox.append(msg)
            case "fri_prove":
                self.prover.fri().prove(msg.data, chan)
            case _:
                raise ValueError(f"Invalid msg type: {msg.type}")


class Verifier:
    def __init__(self, verifier: IStarkVerifier):
        self.verifier = verifier
        self.inbox: list[Msg] = []

    def recv(self, msg: Msg, chan: Channel):
        match msg.type:
            case "stark_degree_adj":
                self.verifier.set_adj(msg.data, chan)
            case "stark_merkle_roots":
                self.verifier.set_merkle_roots(msg.data)
            case "stark_proofs":
                self.inbox.append(msg)
            case "fri_merkle_root":
                self.verifier.fri().push_merkle_root(msg.data)
            case "fri_challenge":
                self.verifier.fri().get_challenge(chan)
            case "fri_proofs":
                self.inbox.append(msg)
            case _:
                raise ValueError(f"Invalid msg type: {msg.type}")


class Channel:
    def __init__(self, prover: Prover, verifier: Verifier):
        self.prover = prover
        self.verifier = verifier

    def send(self, **kwargs):
        dst: str = kwargs["dst"]
        msg: Msg = kwargs["msg"]

        assert dst in ["prover", "verifier"]

        match dst:
            case "prover":
                self.prover.recv(msg, self)
                if len(self.verifier.inbox) > 0:
                    return self.verifier.inbox.pop().data
            case "verifier":
                self.verifier.recv(msg, self)
                if len(self.prover.inbox) > 0:
                    return self.prover.inbox.pop().data
