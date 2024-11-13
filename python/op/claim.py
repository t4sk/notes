from web3 import Web3

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