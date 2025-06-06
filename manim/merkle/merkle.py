from manim import *
import hashlib


def hash_leaf(leaf: str) -> str:
    # return f'h({leaf})'
    return hashlib.sha256(leaf.encode()).hexdigest()


def hash_pair(left: str, right: str) -> str:
    # return f'h({left}, {right})'
    return hashlib.sha256((left + right).encode()).hexdigest()


def cut(s: str) -> str:
    return s[:5] + "..."


def calc_root(leaves: list[str]) -> list[list[str]]:
    tree = [[hash_leaf(l) for l in leaves]]
    tree[0].sort()

    n = len(tree[0])

    while n > 1:
        tree.append([])
        for i in range(0, n, 2):
            left = tree[-2][i]
            right = tree[-2][min(i + 1, n - 1)]
            if left > right:
                left, right = right, left
            tree[-1].append(hash_pair(left, right))
        n = (n + (n % 2)) // 2

    tree.reverse()

    return tree


def get_proof(leaves: list[str], index: int) -> list[str]:
    proof = []

    hashes = [hash_leaf(l) for l in leaves]
    hashes.sort()

    n = len(hashes)
    k = index

    while n > 1:
        j = k - 1 if k & 1 else min(k + 1, n - 1)
        h = hashes[j]
        proof.append(h)
        k >>= 1

        for i in range(0, n, 2):
            left = hashes[i]
            right = hashes[min(i + 1, n - 1)]
            if left > right:
                left, right = right, left
            hashes[i >> 1] = hash_pair(left, right)
        n = (n + (n & 1)) >> 1

    return proof


def verify(proof: list[str], root: str, leaf: str) -> bool:
    h = hash_leaf(leaf)

    for p in proof:
        left = h
        right = p
        if left > right:
            left, right = right, left
        h = hash_pair(left, right)

    return h == root


def Rect(txt: str, **kwargs):
    text = Text(txt, font_size=20)
    rect = RoundedRectangle(
        width=kwargs.get("width", text.width + 0.5),
        height=kwargs.get("height", text.height + 0.5),
        corner_radius=0.1,
        fill_color=BLUE_E,
        fill_opacity=0.4,
        stroke_width=0,
    )
    rect.move_to(text.get_center())
    return VGroup(rect, text)


class MerkleTree(Scene):
    def show_border(self):
        border = Rectangle(
            width=config.frame_width, height=config.frame_height
        ).set_stroke(WHITE, width=2)
        self.add(border)

    def wait(self, t=0):
        # super().wait()
        pass

    def construct(self):
        self.show_border()

        # leaves = sorted(["A", "B", "C", "D", "E", "F", "G"], key=lambda l: hash_leaf(l))
        leaves = ["A", "B", "C", "D", "E", "F", "G"]
        hash_leaves = [hash_leaf(l) for l in leaves]
        hash_leaves.sort()

        indexes = [hash_leaves.index(hash_leaf(l)) for l in leaves]
        hashes = calc_root(leaves)
        # Append hash(G) since number of leaves are odd
        if len(leaves) % 2 == 1:
            hashes[-1].append(hashes[-1][-1])

        boxes = VGroup(*[Rect(l, width=0.8, height=0.8) for l in leaves]).arrange(
            RIGHT, buff=0.2
        )

        tree = VGroup(
            *[
                VGroup(*[Rect(cut(h)) for h in level]).arrange(RIGHT, buff=0.2)
                for level in hashes
            ],
            boxes
        ).arrange(DOWN, buff=0.5)

        # Position leaf centered below leaf hashes
        for (box, leaf_hash) in zip(boxes, tree[-2]):
            box.next_to(leaf_hash, DOWN)

        # Position hashes
        for i in reversed(range(1, len(tree) - 1)):
            for j in range(0, len(tree[i]), 2):
                top = tree[i - 1][j // 2]
                mid_x = (
                    tree[i][j].get_center()[0] + tree[i][j + 1].get_center()[0]
                ) / 2
                yz = top.get_center()[1:]
                top.move_to([mid_x, *yz])

        # Leaf to leaf hash lines
        leaf_lines = []
        for (box, leaf_hash) in zip(boxes, tree[-2]):
            line = Line(
                start=box.get_top(),
                end=leaf_hash.get_bottom(),
                color=BLUE,
                buff=0,
                stroke_width=4,
            )
            leaf_lines.append(line)

        for leaf_line in leaf_lines:
            self.add(leaf_line)

        # Lines
        lines = []
        for i in range(0, len(tree) - 2):
            for j in range(0, len(tree[i])):
                # print((i + 1, 2 * j), (i + 1, 2 * j + 1))
                left = Line(
                    start=tree[i + 1][2 * j].get_top(),
                    end=tree[i][j].get_bottom(),
                    color=BLUE,
                    buff=0,
                    stroke_width=4,
                )
                right = Line(
                    start=tree[i + 1][2 * j + 1].get_top(),
                    end=tree[i][j].get_bottom(),
                    color=BLUE,
                    buff=0,
                    stroke_width=4,
                )
                lines.append((left, right))

        for (left, right) in lines:
            self.add(left)
            self.add(right)

        self.play(FadeIn(tree))

        return

        # Show array
        # boxes.to_edge(DOWN)
        self.add(FadeIn(tree))
        self.wait(1)
        return

        # TODO: animate spread boxes

        leaf_hashes = [
            hashlib.sha256(l.encode()).hexdigest()[:6].upper() for l in leaves
        ]

        leaf_nodes = [Text(h, font_size=30) for h in leaf_hashes]
        for i, node in enumerate(leaf_nodes):
            node.move_to(LEFT * 3 + RIGHT * 2 * i + DOWN * 2)

        self.play(*[Write(node) for node in leaf_nodes])
        self.wait(1)

        # Pairwise hashes at level 1
        level1_hashes = []
        level1_nodes = []
        level1_edges = []

        for i in range(0, 4, 2):
            h = hash_pair(leaf_hashes[i], leaf_hashes[i + 1])
            level1_hashes.append(h)
            text = Text(h, font_size=30).move_to(
                (leaf_nodes[i].get_center() + leaf_nodes[i + 1].get_center()) / 2 + UP
            )
            level1_nodes.append(text)

            # Draw edges
            edge1 = Line(leaf_nodes[i].get_top(), text.get_bottom())
            edge2 = Line(leaf_nodes[i + 1].get_top(), text.get_bottom())
            level1_edges.extend([edge1, edge2])

            self.play(Write(text), Create(edge1), Create(edge2))
            self.wait(0.5)

        # Root hash
        root_hash = hash_pair(level1_hashes[0], level1_hashes[1])
        root_node = Text(root_hash, font_size=30).move_to(
            (level1_nodes[0].get_center() + level1_nodes[1].get_center()) / 2 + UP
        )

        edge3 = Line(level1_nodes[0].get_top(), root_node.get_bottom())
        edge4 = Line(level1_nodes[1].get_top(), root_node.get_bottom())

        self.play(Write(root_node), Create(edge3), Create(edge4))
        self.wait(2)

        # Optional: highlight root
        self.play(root_node.animate.set_color(RED))
        self.wait(2)
