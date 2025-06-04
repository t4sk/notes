from manim import *
import hashlib


def hash_pair(left: str, right: str) -> str:
    return hashlib.sha256((left + right).encode()).hexdigest()


def hash_leaf(leaf: str) -> str:
    return hashlib.sha256(leaf.encode()).hexdigest()


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

def calc_root(leaves: str[]) -> str[][]:
    pass

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

        leaves = ["A", "B", "C", "D", "E", "F", "G"]
        boxes = VGroup(*[Rect(l, width=0.8, height=0.8) for l in leaves]).arrange(
            RIGHT, buff=0.2
        )

        hashes = [[]]
        hashes[0] = [hash_leaf(l) for l in leaves]
        hashes[0].append(hashes[0][-1])
        hash_leaves_group = VGroup(*[Rect(h) for h in hashes[0]]).arrange(
            RIGHT, buff=0.2
        )

        tree = VGroup(hash_leaves_group, boxes).arrange(DOWN, buff=1)
        tree.to_edge(DOWN)

        # Show array
        # boxes.to_edge(DOWN)
        self.add(boxes)
        self.wait(1)

        # TODO: animate spread boxes

        self.play(FadeIn(hash_leaves_group))
        self.wait(1)

        return

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
