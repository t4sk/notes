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