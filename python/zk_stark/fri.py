# Initial evaluation domain of FRI
def domain(w: int, n: int, p: int):
    """
    w is primitive nth root mod p
    p is prime
    """
    # Set to check no duplicate
    s = {1}
    d = [1]
    # Check w is a primitive nth root
    for i in range(1, n):
        x = pow(w, i, p)
        assert x != 1, f'{w}^{i} = 1'
        assert x not in s
        s.add(x)
        d.append(x)
    assert pow(w, n, p) == 1
    return d

def commit():
    pass

class Fri:
    def __init__(self, **kwargs):
        self.num_queries = kwargs["num_queries"]

    def commit(self):
        pass

    def query(self):
        pass

    def prove(self):
        pass

    def verify(self):
        pass