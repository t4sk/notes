class Block:
    def __init__(self, **kwargs):
        self.timestamp = kwargs.get("timestamp", 0)

    def inc(self):
        self.timestamp += 1

    def skip(self, dt: int):
        self.timestamp += dt

    def warp(self, t: int):
        assert t >= self.timestamp
        self.timestamp = t