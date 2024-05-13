from Crypto.Hash import keccak


def keccak_hash(bin_data):
    hash = keccak.new(digest_bits=256)
    hash.update(bin_data)
    return hash.digest()
