from enum import Enum

class GameStatus(Enum):
    IN_PROGRESS = 0
    CHALLENGER_WINS = 1
    DEFENDER_WINS = 2

class VMStatus(Enum):
    VALID = 0
    INVALID = 1
    PANIC = 2
    UNFINISHED = 3

class OutputRoot:
    def __init__(self, **kwargs):
        self.root = kwargs["root"]
        self.l2_block_num = kwargs["l2_block_num"]

    def __repr__(self):
        return str(vars(self))