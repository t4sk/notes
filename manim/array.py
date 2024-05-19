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
        for (square, text) in zip(squares, texts):
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
        for (square, text) in zip(squares, texts):
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
        x_space = np.linspace(*ax.x_range[:2],10)

        self.play(FadeIn(ax, labels, graph, dot))

        for (x, box) in zip(x_space, text_boxes):
            self.play(
                highlight_square.animate.move_to(box.get_center()),
                t.animate.set_value(x)
            )
            self.wait(0.1)

        self.wait(1)

        # Fade out graph and brace
        self.play(
            FadeOut(highlight_square, brace, brace_tex, ax, labels, graph, dot),
        )

class Array2Scene(Scene):  
    def construct(self):
        vals = ["00", "00", "00", "00", "00", "00", "00", "..."]
        squares = [Square(color=BLUE) for i in range(len(vals))]
        texts = [Text(v, color=WHITE) for v in vals]
        
        v_group_squares = VGroup(*squares).arrange()
        v_group_texts = VGroup(*texts).arrange()

        # NOTE - this code must be after vgroup.arrange
        for (square, text) in zip(squares, texts):
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
        b32 = ["00"] * 32

        squares = [Square(color=BLUE) for i in range(len(b32))]
        texts = [Text(v, color=WHITE) for v in b32]
        
        v_group_squares = VGroup(*squares).arrange()
        v_group_texts = VGroup(*texts).arrange()

        # NOTE - this code must be after vgroup.arrange
        for (square, text) in zip(squares, texts):
            text.move_to(square.get_center())
        
        text_boxes = [VGroup(s, t) for (s, t) in zip(squares, texts)]
        v_group_text_boxes = VGroup(*text_boxes).arrange()
        v_group_text_boxes.scale(0.15)

        highlight_square = Square(color=YELLOW).scale(0.5 * 0.7)

        highlight_square.animate.move_to(prev[0].get_center())
        self.wait(1)

        for i in range(len(text_boxes)):
            box = text_boxes[i]
            p = prev[i] if i < len(prev) else prev[-1]
            self.play(
                highlight_square.animate.move_to(p.get_center())
            )
            self.play(GrowFromPoint(box, p), run_time=1)
        
        v_b32_0 = v_group_text_boxes
        self.play(v_b32_0.animate.shift(3 * UP))

        # 32 - 64
        squares = [Square(color=BLUE) for i in range(len(b32))]
        texts = [Text(v, color=WHITE) for v in b32]
        
        v_group_squares = VGroup(*squares).arrange()
        v_group_texts = VGroup(*texts).arrange()

        # NOTE - this code must be after vgroup.arrange
        for (square, text) in zip(squares, texts):
            text.move_to(square.get_center())
        
        text_boxes = [VGroup(s, t) for (s, t) in zip(squares, texts)]
        v_group_text_boxes = VGroup(*text_boxes).arrange()
        v_group_text_boxes.scale(0.15)

        for i in range(len(text_boxes)):
            box = text_boxes[i]
            p = prev[i] if i < len(prev) else prev[-1]
            self.play(GrowFromPoint(box, p), run_time=1)

        v_b32_1 = v_group_text_boxes
        self.play(v_b32_1.animate.shift(2 * UP))

        # 64 - 96 = free memory pointer
        squares = [Square(color=BLUE) for i in range(len(b32))]
        texts = [Text(v, color=WHITE) for v in b32]
        
        v_group_squares = VGroup(*squares).arrange()
        v_group_texts = VGroup(*texts).arrange()

        # NOTE - this code must be after vgroup.arrange
        for (square, text) in zip(squares, texts):
            text.move_to(square.get_center())
        
        text_boxes = [VGroup(s, t) for (s, t) in zip(squares, texts)]
        v_group_text_boxes = VGroup(*text_boxes).arrange()
        v_group_text_boxes.scale(0.15)

        for i in range(len(text_boxes)):
            box = text_boxes[i]
            p = prev[i] if i < len(prev) else prev[-1]
            self.play(GrowFromPoint(box, p), run_time=1)

        v_b32_2 = v_group_text_boxes
        self.play(v_b32_2.animate.shift(1 * UP))

        # 96 - 128 = zero slot
        squares = [Square(color=BLUE) for i in range(len(b32))]
        texts = [Text(v, color=WHITE) for v in b32]
        
        v_group_squares = VGroup(*squares).arrange()
        v_group_texts = VGroup(*texts).arrange()

        # NOTE - this code must be after vgroup.arrange
        for (square, text) in zip(squares, texts):
            text.move_to(square.get_center())
        
        text_boxes = [VGroup(s, t) for (s, t) in zip(squares, texts)]
        v_group_text_boxes = VGroup(*text_boxes).arrange()
        v_group_text_boxes.scale(0.15)

        for i in range(len(text_boxes)):
            box = text_boxes[i]
            p = prev[i] if i < len(prev) else prev[-1]
            self.play(GrowFromPoint(box, p), run_time=1)

        v_b32_3 = v_group_text_boxes

        # 128 = free memory pointer
        squares = [Square(color=BLUE) for i in range(len(b32))]
        texts = [Text(v, color=WHITE) for v in b32]
        
        v_group_squares = VGroup(*squares).arrange()
        v_group_texts = VGroup(*texts).arrange()

        # NOTE - this code must be after vgroup.arrange
        for (square, text) in zip(squares, texts):
            text.move_to(square.get_center())
        
        text_boxes = [VGroup(s, t) for (s, t) in zip(squares, texts)]
        v_group_text_boxes = VGroup(*text_boxes).arrange()
        v_group_text_boxes.scale(0.15)
        v_group_text_boxes.move_to(DOWN)

        for i in range(len(text_boxes)):
            box = text_boxes[i]
            p = prev[i] if i < len(prev) else prev[-1]
            self.play(GrowFromPoint(box, p), run_time=1)

        v_b32_4 = v_group_text_boxes

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
        v_b32_0_text.move_to([x - w/2 + text_w / 2 + 0.1, y + h/2 + text_h / 2 + 0.1, 0])

        pos = v_b32_1.get_center()
        h = v_b32_1.height
        w = v_b32_1.width
        x = pos[0]
        y = pos[1]
        slot_1 = Text("0x20").scale(0.5).next_to(v_b32_1, LEFT)
        v_b32_1_text = Text("Scratch space").scale(0.5)
        text_h = v_b32_1_text.height
        text_w = v_b32_1_text.width
        v_b32_1_text.move_to([x - w/2 + text_w / 2 + 0.1, y + h/2 + text_h / 2 + 0.1, 0])

        pos = v_b32_2.get_center()
        h = v_b32_2.height
        w = v_b32_2.width
        x = pos[0]
        y = pos[1]
        slot_2 = Text("0x40").scale(0.5).next_to(v_b32_2, LEFT)
        v_b32_2_text = Text("Free memory pointer").scale(0.5)
        text_h = v_b32_2_text.height
        text_w = v_b32_2_text.width
        v_b32_2_text.move_to([x - w/2 + text_w / 2 + 0.1, y + h/2 + text_h / 2 + 0.1, 0])

        pos = v_b32_3.get_center()
        h = v_b32_3.height
        w = v_b32_3.width
        x = pos[0]
        y = pos[1]
        slot_3 = Text("0x60").scale(0.5).next_to(v_b32_3, LEFT)
        v_b32_3_text = Text("Zero slot").scale(0.5)
        text_h = v_b32_3_text.height
        text_w = v_b32_3_text.width
        v_b32_3_text.move_to([x - w/2 + text_w / 2 + 0.1, y + h/2 + text_h / 2 + 0.1, 0])

        pos = v_b32_4.get_center()
        h = v_b32_4.height
        w = v_b32_4.width
        x = pos[0]
        y = pos[1]
        slot_4 = Text("0x80").scale(0.5).next_to(v_b32_4, LEFT)
        v_b32_4_text = Text("Initial free memory").scale(0.5)
        text_h = v_b32_4_text.height
        text_w = v_b32_4_text.width
        v_b32_4_text.move_to([x - w/2 + text_w / 2 + 0.1, y + h/2 + text_h / 2 + 0.1, 0])

        self.play(FadeOut(v_prev, highlight_square))
        self.wait(1)

        self.play(Write(slot_0), Write(slot_1), Write(slot_2), Write(slot_3), Write(slot_4))
        self.play(Write(v_b32_0_text))
        self.wait(1)
        self.play(Write(v_b32_2_text))
        self.wait(1)
        self.play(Write(v_b32_3_text))
        self.wait(1)
        self.play(Write(v_b32_4_text))
        self.wait(1)


class FuncScene(Scene):
    def construct(self):
        ax = Axes(
            x_range=[0, 10], y_range=[0, 100, 10], axis_config={"include_tip": False}
        )
        labels = ax.get_axis_labels(x_label="memory", y_label="gas")

        t = ValueTracker(0)

        def func(x):
            return 100 * x**2

        graph = ax.plot(func, color=MAROON)

        initial_point = [ax.coords_to_point(t.get_value(), func(t.get_value()))]
        dot = Dot(point=initial_point)

        dot.add_updater(lambda x: x.move_to(ax.c2p(t.get_value(), func(t.get_value()))))
        x_space = np.linspace(*ax.x_range[:2],10)
        # max_index = func(x_space).argmax()

        # self.add(ax, labels, graph, dot)
        # self.play(t.animate.set_value(x_space[max_index]))
        # self.wait()

        self.add(ax, labels, graph, dot)
        for x in x_space:
            self.play(t.animate.set_value(x))
            self.wait(0.1)