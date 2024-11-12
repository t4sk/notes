from lib import bit_not

class Position:
    @staticmethod
    def wrap(depth, index_at_depth):
        assert index_at_depth < 2** depth
        return 2**depth + index_at_depth

    @staticmethod
    def depth(pos):
        i = 0
        while pos // 2 > 0:
            pos //= 2
            i  += 1
        return i

    @staticmethod
    def index_at_depth(pos):
        depth = Position.depth(pos)
        return pos - 2**depth

    @staticmethod
    def left(pos):
        return 2 * pos

    @staticmethod
    def right(pos):
        return 2 * pos + 1

    @staticmethod
    def parent(pos):
        return pos // 2

    @staticmethod
    def right_index(pos, max_depth):
        depth = Position.depth(pos)
        assert depth <= max_depth
        remaining = max_depth - depth
        return 2**remaining * pos + 2**remaining - 1

    @staticmethod
    def trace_index(pos, max_depth):
        depth = Position.depth(pos)
        assert depth <= max_depth
        remaining = max_depth - depth
        return (2**remaining * pos + 2**remaining - 1) - 2**max_depth

    @staticmethod
    def trace_ancestor(pos):
        """
        # keep diving by 2 while odd
        a = pos
        while a % 2 == 1:
            a //= 2
        return max(a, 1)
        """
        # lowest unset bit
        lsb = bit_not(pos, 128) & (pos + 1)
        # index of most significant bit of lsb
        msb = Position.depth(lsb)
        a = pos >> msb
        return max(a, 1)

    @staticmethod
    def trace_ancestor_bounded(pos, upper_bound):
        assert Position.depth(pos) > upper_bound
        ancestor = Position.trace_ancestor(pos)
        if Position.depth(ancestor) <= upper_bound:
            ancestor = Position.right_index(ancestor, upper_bound + 1)
        return ancestor

    @staticmethod
    def move(pos, is_attack):
        if is_attack:
            return 2 * pos
        else:
            return 2 * (pos + 1)
