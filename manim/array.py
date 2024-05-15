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
        # s = "00"
        # box = Square(color=BLUE)
        # text = Text(s).move_to(box.get_center())
        # v_group = VGroup(box, text)

        # move text box around
        # self.play(v_group.animate.shift(2*RIGHT), run_time=3)
        # self.play(v_group.animate.shift(2*UP), run_time=3)

        # self.play(Create(box))
        # self.play(Write(text))
        # self.wait()

        vals = ["00", "00", "00", "00", "..."]
        squares = [Square(color=BLUE) for i in range(len(vals))]
        texts = [Text(v, color=WHITE) for v in vals]

        v_group_squares = VGroup(*squares).arrange()
        v_group_texts = VGroup(*texts).arrange()

        # NOTE - this code must be after vgroup.arrange
        for (square, text) in zip(squares, texts):
            text.move_to(square.get_center())

        self.play(Create(v_group_squares))
        self.play(Write(v_group_texts))
        self.wait(2)