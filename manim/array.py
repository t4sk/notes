from manim import *

class ArrayIndex(VGroup):
    """
    Visualization of an array index.
    Includes a highlighting rectangle for the array element, and option pointer and label
    with index value.
    """

    CONFIG = {
        'wdith': 1,
        'height': 1,
        'name': 'i',
        'color': BLUE,
        'opacity': 0.75,
        'position': DOWN,
        'show_arrow': True,
        'show_label': True,
    }

    def __init__(self, parent, value, **kwargs):
        self.parent = parent
        self.index_tracker = ValueTracker(value)
        self.indicator_box = self.add_indicator_box()
        if self.show_label:
            self.label = always_redraw(lambda: self.get_label())
        else:
            self.label = None
            self.show_arrow = False  # No arrow without label
        if self.show_arrow:
            self.arrow = always_redraw(lambda: self.get_arrow())
        else:
            self.arrow = None
        self.add(*remove_nones([self.label, self.arrow, self.indicator_box]))

    def add_indicator_box(self):
        box = Rectangle(width=self.width - 0.1, height=self.height - 0.1)
        box.set_stroke(color=self.color,
                       opacity=self.get_box_opacity(self.get_value()))
        box.move_to(self.get_box_target(self.get_value()))
        return box

    def get_label(self):
        i = int(round(self.index_tracker.get_value(), 0))
        ni = TextMobject(self.name + '=' + str(i))
        ni.next_to(self.indicator_box, self.position, LARGE_BUFF)
        return ni

    def get_arrow(self):
        if self.label.get_y() < self.indicator_box.get_y():
            a = Arrow(self.label.get_top(),
                      self.indicator_box.get_bottom(),
                      buff=MED_SMALL_BUFF)
        else:
            a = Arrow(self.label.get_bottom(),
                      self.indicator_box.get_top(),
                      buff=MED_SMALL_BUFF)
        return a

    def set_index(self, value):
        self.indicator_box.set_stroke(opacity=self.get_box_opacity(value))
        self.indicator_box.move_to(self.get_box_target(value))
        self.index_tracker.set_value(value)
        return self

    def get_box_target(self, value):
        if value < 0:
            fpe_o = self.parent.elements[0].get_critical_point(ORIGIN)
            return fpe_o + LEFT * self.width
        elif value < len(self.parent.elements):
            return self.parent.elements[value].get_critical_point(ORIGIN)
        else:
            lpe_o = self.parent.elements[-1].get_critical_point(ORIGIN)
            return lpe_o + RIGHT * self.width

    def get_box_opacity(self, value):
        if 0 <= value < len(self.parent.elements):
            return self.opacity
        else:
            return 0.5

    def animate_set_index(self, value):
        return [
            self.indicator_box.set_stroke,
            {
                'opacity': self.get_box_opacity(value),
                'family': False
            },
            self.indicator_box.move_to,
            self.get_box_target(value),
            self.index_tracker.set_value,
            value,
        ]

    def get_value(self):
        return int(self.index_tracker.get_value())

class Array(VGroup):
    def __init__(self, values, **kwargs):
        super().__init__(**kwargs)
        self.values = values
        self.indicies = {}
        self.element_width = 1
        self.element_height= 1
        self.element_color= WHITE
        self.total_width = self.element_width * len(self.values)
        self.hw = self.element_width / 2
        self.hh = self.element_height / 2
        self.left_element_offset = (self.total_width / 2) - self.hw
        self.left_edge_offset = self.left_element_offset + self.hw 
        self.rects = [Rectangle(height=1, width=1) for _ in range(len(values))]

        rects = self.rects
        for rect in rects:
            rect.set_color(BLUE)

        for i in range(1, len(rects)):
            rects[i].next_to(rects[i - 1], RIGHT, buff=0)

        self.add(*rects)

        self.elements = VGroup()
        self.backgrounds = VGroup()
        for i, v in enumerate(values):
            if v is not None:
                t = Tex(str(v))
            else:
                t = Tex('.', width=0, height=0, color=BLACK)

            t.move_to(i * RIGHT * self.element_width)
            self.elements.add(t)

            b = Rectangle(width=self.element_width - 0.1,
                          height=self.element_height - 0.1)
            b.set_stroke(color=BLACK, opacity=0)
            b.move_to(t.get_center())
            self.backgrounds.add(b)

        self.add(self.backgrounds)
        self.elements.set_color(self.element_color)

        self.add(self.elements)
        self.move_to(ORIGIN-self.get_center())
    
    def append(self, val):
        self.values.append(val)
        rect = Rectangle(height=1, width=1)
        rect.set_color(BLUE)
        self.rects.append(rect)
        n = len(self.rects)
        self.rects[n - 1].next_to(self.rects[n - 2], RIGHT, buff=0)
        self.add(rect)

# def create_array(num_rectangles, color, start_pos, height, width):
#     initial_array = [Rectangle(height=height, width=width) for _ in range(num_rectangles)]
#     for rect in initial_array:
#         rect.set_color(color)
#     initial_array[0].move_to(start_pos)
#     for i in range(1, len(initial_array)):
#         initial_array[i].next_to(initial_array[i - 1], RIGHT, buff=0)
#     return initial_array

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

        # self.play(Create(v_group_squares))
        # self.play(Write(v_group_texts))
        # self.wait(1)

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



class FuncScene(Scene):
    def construct(self):
        ax = Axes(
            x_range=[0, 10], y_range=[0, 100, 10], axis_config={"include_tip": False}
        )
        labels = ax.get_axis_labels(x_label="memory", y_label="gas")

        t = ValueTracker(0)

        def func(x):
            return 10 * x**2

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