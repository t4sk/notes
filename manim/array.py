from manim import *


class ArrayScene(Scene):
    def construct(self):
        # Initial array
        vals = ["00", "00", "00", "00", "..."]
        squares = [Square(color=BLUE) for i in range(len(vals))]
        texts = [Text(v, color=WHITE) for v in vals]

        v_group_squares = VGroup(*squares).arrange()
        v_group_texts = VGroup(*texts).arrange()

        # NOTE - this code must be after vgroup.arrange
        for square, text in zip(squares, texts):
            text.move_to(square.get_center())

        text_boxes = [VGroup(s, t) for (s, t) in zip(squares, texts)]
        v_group_text_boxes = VGroup(*text_boxes).arrange()

        self.play(Create(v_group_squares))
        self.play(Write(v_group_texts))
        self.wait(1)

        # Grow array
        vals = ["00", "00", "00", "00", "00", "00", "00", "..."]
        squares = [Square(color=BLUE) for i in range(len(vals))]
        texts = [Text(v, color=WHITE) for v in vals]

        v_group_squares_1 = VGroup(*squares).arrange()
        v_group_texts_1 = VGroup(*texts).arrange()

        # NOTE - this code must be after vgroup.arrange
        for square, text in zip(squares, texts):
            text.move_to(square.get_center())

        text_boxes = [VGroup(s, t) for (s, t) in zip(squares, texts)]
        v_group_text_boxes_1 = VGroup(*text_boxes).arrange()

        self.play(ReplacementTransform(v_group_text_boxes, v_group_text_boxes_1))
        self.play(ScaleInPlace(v_group_text_boxes_1, 0.5))
        self.wait(1)

        # Show length
        brace = Brace(mobject=v_group_text_boxes_1, direction=DOWN, buff=0.2)
        brace_tex = brace.get_tex("2^{256} elements")
        self.play(GrowFromCenter(brace), FadeIn(brace_tex), run_time=1)
        # self.play(FadeOut(brase), FadeOut(brace_tex), run_time=1)
        self.wait(1)

        self.play(
            ScaleInPlace(v_group_text_boxes_1, 0.7),
            ScaleInPlace(brace, 0.7),
            ScaleInPlace(brace_tex, 0.7),
        )
        self.wait(1)

        # Show quadratic gas cost
        highlight_square = Square(color=YELLOW).scale(0.5 * 0.7)
        highlight_square.align_to(v_group_text_boxes_1, LEFT)

        # Quadratic graph
        ax = Axes(
            x_range=[0, 10], y_range=[0, 100, 10], axis_config={"include_tip": False}
        )
        labels = ax.get_axis_labels(x_label="memory", y_label="gas")

        t = ValueTracker(0)

        def func(x):
            return x**2

        graph = ax.plot(func, color=MAROON)

        initial_point = [ax.coords_to_point(t.get_value(), func(t.get_value()))]
        dot = Dot(point=initial_point, color=YELLOW)

        dot.add_updater(lambda x: x.move_to(ax.c2p(t.get_value(), func(t.get_value()))))
        x_space = np.linspace(*ax.x_range[:2], 10)

        self.play(FadeIn(ax, labels, graph, dot))

        for x, box in zip(x_space, text_boxes):
            self.play(
                highlight_square.animate.move_to(box.get_center()),
                t.animate.set_value(x),
            )
            self.wait(0.1)

        self.wait(1)

        # Fade out graph and brace
        self.play(
            FadeOut(highlight_square, brace, brace_tex, ax, labels, graph, dot),
        )


class ArrayScene2(Scene):
    def construct(self):
        vals = ["00", "00", "00", "00", "00", "00", "00", "..."]
        squares = [Square(color=BLUE) for i in range(len(vals))]
        texts = [Text(v, color=WHITE) for v in vals]

        v_group_squares = VGroup(*squares).arrange()
        v_group_texts = VGroup(*texts).arrange()

        # NOTE - this code must be after vgroup.arrange
        for square, text in zip(squares, texts):
            text.move_to(square.get_center())

        text_boxes = [VGroup(s, t) for (s, t) in zip(squares, texts)]
        v_group_text_boxes = VGroup(*text_boxes).arrange()
        v_group_text_boxes.scale(0.35)

        self.add(v_group_text_boxes)
        self.wait(1)

        # Move array
        self.play(v_group_text_boxes.animate.shift(3 * RIGHT))
        self.play(v_group_text_boxes.animate.shift(3 * DOWN))

        prev = text_boxes
        v_prev = v_group_text_boxes

        # Show first 32 bytes = scratch space
        b32 = ["00", "00", "00", "...", "00", "00", "00"]

        squares = [Square(color=BLUE) for i in range(len(b32))]
        texts = [Text(v, color=WHITE) for v in b32]

        v_group_squares = VGroup(*squares).arrange()
        v_group_texts = VGroup(*texts).arrange()

        # NOTE - this code must be after vgroup.arrange
        for square, text in zip(squares, texts):
            text.move_to(square.get_center())

        text_boxes = [VGroup(s, t) for (s, t) in zip(squares, texts)]
        v_group_text_boxes = VGroup(*text_boxes).arrange()
        v_group_text_boxes.scale(0.35)

        self.play(GrowFromPoint(v_group_text_boxes, prev[-1]))

        v_b32_0 = v_group_text_boxes
        self.play(v_b32_0.animate.shift(3 * UP))
        self.wait(1)

        # Show 32 - 64
        squares = [Square(color=BLUE) for i in range(len(b32))]
        texts = [Text(v, color=WHITE) for v in b32]

        v_group_squares = VGroup(*squares).arrange()
        v_group_texts = VGroup(*texts).arrange()

        # NOTE - this code must be after vgroup.arrange
        for square, text in zip(squares, texts):
            text.move_to(square.get_center())

        text_boxes = [VGroup(s, t) for (s, t) in zip(squares, texts)]
        v_group_text_boxes = VGroup(*text_boxes).arrange()
        v_group_text_boxes.scale(0.35)

        self.play(GrowFromPoint(v_group_text_boxes, prev[-1]))

        v_b32_1 = v_group_text_boxes
        self.play(v_b32_1.animate.shift(2 * UP))
        self.wait(1)

        # Show 64 - 96 = free memory pointer
        squares = [Square(color=BLUE) for i in range(len(b32))]
        texts = [Text(v, color=WHITE) for v in b32]

        v_group_squares = VGroup(*squares).arrange()
        v_group_texts = VGroup(*texts).arrange()

        # NOTE - this code must be after vgroup.arrange
        for square, text in zip(squares, texts):
            text.move_to(square.get_center())

        text_boxes = [VGroup(s, t) for (s, t) in zip(squares, texts)]
        v_group_text_boxes = VGroup(*text_boxes).arrange()
        v_group_text_boxes.scale(0.35)

        self.play(GrowFromPoint(v_group_text_boxes, prev[-1]))

        v_b32_2 = v_group_text_boxes
        self.play(v_b32_2.animate.shift(1 * UP))
        self.wait(1)

        # 96 - 128 = zero slot
        squares = [Square(color=BLUE) for i in range(len(b32))]
        texts = [Text(v, color=WHITE) for v in b32]

        v_group_squares = VGroup(*squares).arrange()
        v_group_texts = VGroup(*texts).arrange()

        # NOTE - this code must be after vgroup.arrange
        for square, text in zip(squares, texts):
            text.move_to(square.get_center())

        text_boxes = [VGroup(s, t) for (s, t) in zip(squares, texts)]
        v_group_text_boxes = VGroup(*text_boxes).arrange()
        v_group_text_boxes.scale(0.35)

        v_b32_3 = v_group_text_boxes
        self.play(GrowFromPoint(v_group_text_boxes, prev[-1]))
        self.wait(1)

        # 128 = free memory pointer
        squares = [Square(color=BLUE) for i in range(len(b32))]
        texts = [Text(v, color=WHITE) for v in b32]

        v_group_squares = VGroup(*squares).arrange()
        v_group_texts = VGroup(*texts).arrange()

        # NOTE - this code must be after vgroup.arrange
        for square, text in zip(squares, texts):
            text.move_to(square.get_center())

        text_boxes = [VGroup(s, t) for (s, t) in zip(squares, texts)]
        v_group_text_boxes = VGroup(*text_boxes).arrange()
        v_group_text_boxes.scale(0.35)
        v_group_text_boxes.move_to(DOWN)

        v_b32_4 = v_group_text_boxes
        self.play(GrowFromPoint(v_group_text_boxes, prev[-1]))
        self.wait(1)

        # write texts
        pos = v_b32_0.get_center()
        h = v_b32_0.height
        w = v_b32_0.width
        x = pos[0]
        y = pos[1]
        slot_0 = Text("0x00").scale(0.5).next_to(v_b32_0, LEFT)
        v_b32_0_text = Text("Scratch space").scale(0.5)
        text_h = v_b32_0_text.height
        text_w = v_b32_0_text.width
        v_b32_0_text.move_to([x + w / 2 + text_w / 2 + 0.3, y, 0])

        pos = v_b32_1.get_center()
        h = v_b32_1.height
        w = v_b32_1.width
        x = pos[0]
        y = pos[1]
        slot_1 = Text("0x20").scale(0.5).next_to(v_b32_1, LEFT)
        v_b32_1_text = Text("Scratch space").scale(0.5)
        text_h = v_b32_1_text.height
        text_w = v_b32_1_text.width
        v_b32_1_text.move_to([x + w / 2 + text_w / 2 + 0.3, y, 0])

        pos = v_b32_2.get_center()
        h = v_b32_2.height
        w = v_b32_2.width
        x = pos[0]
        y = pos[1]
        slot_2 = Text("0x40").scale(0.5).next_to(v_b32_2, LEFT)
        v_b32_2_text = Text("Free memory pointer").scale(0.5)
        text_h = v_b32_2_text.height
        text_w = v_b32_2_text.width
        v_b32_2_text.move_to([x + w / 2 + text_w / 2 + 0.3, y, 0])

        pos = v_b32_3.get_center()
        h = v_b32_3.height
        w = v_b32_3.width
        x = pos[0]
        y = pos[1]
        slot_3 = Text("0x60").scale(0.5).next_to(v_b32_3, LEFT)
        v_b32_3_text = Text("Zero slot").scale(0.5)
        text_h = v_b32_3_text.height
        text_w = v_b32_3_text.width
        v_b32_3_text.move_to([x + w / 2 + text_w / 2 + 0.3, y, 0])

        pos = v_b32_4.get_center()
        h = v_b32_4.height
        w = v_b32_4.width
        x = pos[0]
        y = pos[1]
        slot_4 = Text("0x80").scale(0.5).next_to(v_b32_4, LEFT)
        v_b32_4_text = Text("Initial free memory").scale(0.5)
        text_h = v_b32_4_text.height
        text_w = v_b32_4_text.width
        v_b32_4_text.move_to([x + w / 2 + text_w / 2 + 0.3, y, 0])

        self.wait(1)

        self.play(
            Write(slot_0), Write(slot_1), Write(slot_2), Write(slot_3), Write(slot_4)
        )
        self.play(Write(v_b32_0_text))
        self.wait(1)
        self.play(Write(v_b32_2_text))
        self.wait(1)
        self.play(Write(v_b32_3_text))
        self.wait(1)
        self.play(Write(v_b32_4_text))
        self.wait(1)

        # Fade out
        self.play(
            FadeOut(v_b32_0_text),
            # FadeOut(v_b32_1_text),
            FadeOut(v_b32_2_text),
            FadeOut(v_b32_3_text),
            FadeOut(v_b32_4_text),
            FadeOut(slot_2),
            FadeOut(slot_3),
            FadeOut(slot_4),
            FadeOut(v_b32_3),
            FadeOut(v_b32_2),
            FadeOut(v_b32_4),
            FadeOut(v_prev),
        )
        self.wait(1)

        self.play(
            slot_0.animate.shift(1 * DOWN),
            slot_1.animate.shift(2 * DOWN),
            v_b32_0.animate.shift(1 * DOWN),
            v_b32_1.animate.shift(2 * DOWN),
        )
        v_slot_0 = VGroup(slot_0, v_b32_0)
        v_slot_1 = VGroup(slot_1, v_b32_1)
        self.play(
            v_slot_0.animate.scale(0.5 / 0.35), v_slot_1.animate.scale(0.5 / 0.35)
        )


def create_boxes(vals):
    squares = [Square(color=BLUE) for i in range(len(vals))]
    texts = [Text(v, color=WHITE) for v in vals]

    v_group_squares = VGroup(*squares).arrange()
    v_group_texts = VGroup(*texts).arrange()

    # NOTE - this code must be after vgroup.arrange
    for square, text in zip(squares, texts):
        text.move_to(square.get_center())

    return ([VGroup(s, t) for (s, t) in zip(squares, texts)], texts)


class ArrayScene3(Scene):
    def construct(self):
        b32 = ["00", "00", "00", "...", "00", "00", "00"]

        rows = []
        text_rows = []

        for i in range(2):
            (boxes, texts) = create_boxes(b32)

            v_boxes = VGroup(*boxes).arrange()
            v_boxes.scale(0.5)
            v_boxes.move_to(2 * (1 - i) * UP)

            pos = v_boxes.get_center()
            h = v_boxes.height
            w = v_boxes.width
            x = pos[0]
            y = pos[1]
            slot = Text(f"0x{2 * i}0").scale(0.5 * 0.5 / 0.35).next_to(v_boxes, LEFT)

            rows.append(boxes)
            text_rows.append(texts)

            self.add(v_boxes)
            self.add(slot)

        self.wait(1)

        code_0 = Text("mstore(p, v)").move_to(2 * DOWN)
        self.play(Write(code_0))
        self.wait(1)

        # mstore(0, 0xff)
        code_1 = Text("mstore(0, 0xff)").move_to(2 * DOWN)
        self.play(ReplacementTransform(code_0, code_1))
        self.wait(1)

        h_square = Square(color=YELLOW).scale(0.5)
        h_square.move_to(rows[0][0].get_center())

        self.play(Circumscribe(h_square, color=YELLOW))

        h_boxes = [Square(color=YELLOW).scale(0.5) for i in range(len(b32))]
        for i in range(len(b32)):
            h_boxes[i].move_to(rows[0][i].get_center())

        v_h_boxes = VGroup(*h_boxes)
        self.play(Write(v_h_boxes))
        self.wait(1)

        text = Text("ff").scale(0.5).move_to(text_rows[0][-1])
        ff = text
        self.play(Circumscribe(rows[0][-1]))
        self.play(ReplacementTransform(text_rows[0][-1], text))
        self.wait(1)

        self.play(FadeOut(h_square), FadeOut(v_h_boxes))
        self.wait(1)

        # mstore(0x20, 0xaa)
        code_2 = Text("mstore(0x20, 0xaa)").move_to(2 * DOWN)
        self.play(ReplacementTransform(code_1, code_2))
        self.wait(1)

        h_square = Square(color=YELLOW).scale(0.5)
        h_square.move_to(rows[1][0].get_center())

        self.play(Circumscribe(h_square))

        h_boxes = [Square(color=YELLOW).scale(0.5) for i in range(len(b32))]
        for i in range(len(b32)):
            h_boxes[i].move_to(rows[1][i].get_center())

        v_h_boxes = VGroup(*h_boxes)
        self.play(Write(v_h_boxes))
        self.wait(1)

        text = Text("aa").scale(0.5).move_to(text_rows[1][-1])
        self.play(Circumscribe(rows[1][-1]))
        self.play(ReplacementTransform(text_rows[1][-1], text))
        self.wait(1)

        self.play(FadeOut(h_square), FadeOut(v_h_boxes))
        self.wait(1)

        # Write mstore(1, 0xbb)
        code_3 = Text("mstore(1, 0xbb)").move_to(2 * DOWN)
        self.play(ReplacementTransform(code_2, code_3))
        self.wait(1)

        h_square = Square(color=YELLOW).scale(0.5)
        h_square.move_to(rows[0][1].get_center())

        self.play(Circumscribe(h_square))

        h_boxes = [Square(color=YELLOW).scale(0.5) for i in range(len(b32))]
        for i in range(1, len(b32)):
            h_boxes[i - 1].move_to(rows[0][i].get_center())
        h_boxes[-1].move_to(rows[1][0].get_center())

        v_h_boxes = VGroup(*h_boxes)
        self.play(Write(v_h_boxes))
        self.wait(1)

        text = Text("00").scale(0.5).move_to(text_rows[0][-1])
        self.play(Circumscribe(rows[0][-1]))
        self.play(ReplacementTransform(ff, text))
        self.wait(1)

        text = Text("bb").scale(0.5).move_to(text_rows[1][0])
        bb = text
        self.play(Circumscribe(rows[1][0]))
        self.play(ReplacementTransform(text_rows[1][0], text))
        self.wait(1)

        self.play(FadeOut(h_square), FadeOut(v_h_boxes))
        self.wait(1)

        # Write mstore(2, 0xcc)
        code_4 = Text("mstore(2, 0xcc)").move_to(2 * DOWN)
        self.play(ReplacementTransform(code_3, code_4))
        self.wait(1)

        h_square = Square(color=YELLOW).scale(0.5)
        h_square.move_to(rows[0][2].get_center())

        self.play(Circumscribe(h_square))

        h_boxes = [Square(color=YELLOW).scale(0.5) for i in range(len(b32))]
        for i in range(2, len(b32)):
            h_boxes[i - 2].move_to(rows[0][i].get_center())
        h_boxes[-2].move_to(rows[1][0].get_center())
        h_boxes[-1].move_to(rows[1][1].get_center())

        v_h_boxes = VGroup(*h_boxes)
        self.play(Write(v_h_boxes))
        self.wait(1)

        text = Text("00").scale(0.5).move_to(text_rows[1][0])
        self.play(Circumscribe(rows[1][0]))
        self.play(ReplacementTransform(bb, text))
        self.wait(1)

        text = Text("cc").scale(0.5).move_to(text_rows[1][1])
        self.play(Circumscribe(rows[1][1]))
        self.play(ReplacementTransform(text_rows[1][1], text))
        self.wait(1)

        self.play(FadeOut(h_square), FadeOut(v_h_boxes))
        self.wait(1)


# class FuncScene(Scene):
#     def construct(self):
#         ax = Axes(
#             x_range=[0, 10], y_range=[0, 100, 10], axis_config={"include_tip": False}
#         )
#         labels = ax.get_axis_labels(x_label="memory", y_label="gas")

#         t = ValueTracker(0)

#         def func(x):
#             return 100 * x**2

#         graph = ax.plot(func, color=MAROON)

#         initial_point = [ax.coords_to_point(t.get_value(), func(t.get_value()))]
#         dot = Dot(point=initial_point)

#         dot.add_updater(lambda x: x.move_to(ax.c2p(t.get_value(), func(t.get_value()))))
#         x_space = np.linspace(*ax.x_range[:2], 10)
#         # max_index = func(x_space).argmax()

#         # self.add(ax, labels, graph, dot)
#         # self.play(t.animate.set_value(x_space[max_index]))
#         # self.wait()

#         self.add(ax, labels, graph, dot)
#         for x in x_space:
#             self.play(t.animate.set_value(x))
#             self.wait(0.1)
