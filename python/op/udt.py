from web3 import Web3
from lib import U64_MAX

class Clock:
    @staticmethod
    def wrap(duration, timestamp):
        assert duration <= U64_MAX
        assert timestamp <= U64_MAX
        return (duration << 64) + timestamp

    @staticmethod
    def duration(clock):
        return clock >> 64

    @staticmethod
    def timestamp(clock):
        return clock & U64_MAX

class Claim:
    @staticmethod
    def hash_claim_pos(claim: str, pos: int, challenge_index: int) -> str:
        assert claim.startswith("0x")
        assert len(claim) == 66
        assert 0 <= pos < 2**128
        assert 0 <= challenge_index < 2**256
        
        vals = [
            claim, 
            (pos << 128) | (challenge_index & 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
        ]
        types = [
            'bytes32', 
            'uint256'
        ]
    
        # keccak256(abi.encodePacked(...))
        return Web3.solidity_keccak(types, vals).hex()