from manim import *

from manim import *

class Count(Animation):
    def __init__(self, num: DecimalNumber, start: float, end: float, **kwargs) -> None:
        # Pass num as the mobject of the animation
        super().__init__(num,  **kwargs)
        # Set start and end
        self.start = start
        self.end = end
        self.num = num

    def interpolate_mobject(self, alpha: float) -> None:
        # Set value of DecimalNumber according to alpha
        value = self.start + (alpha * (self.end - self.start))
        self.mobject.set_value(value)


def lin(y0, y1, x0, x1, x):
    return (y1 - y0) / (x1 - x0) * (x - x0) + y0


class Bar(Scene):
    def construct(self):
        bals0=[0, 0, 0]
        bals1=[100, 90, 110]
        bals2=[130, 90, 110]
        MAX_BAL = bals2[0]

        d0 = 299.8991189141142
        d1 = 329.6255506994503

        count_anims = []
        for (b0, b1) in zip(bals0, bals1):
            num = DecimalNumber().set_color(WHITE)
            count = Count(num, b0, b1)
            count_anims.append(count)

        chart = BarChart(
            bals0,
            bar_names = ["DAI", "USDC", "USDT"],
            bar_colors = ["orange", "blue", "green"],
            bar_fill_opacity = 0.2,
            x_length = 10, 
            y_range=[0, MAX_BAL, 20],
            y_axis_config={"font_size": 24},
            x_axis_config={"font_size": 48},
        )

        def updater(chart):
            chart.change_bar_values([c.num.get_value() for c in count_anims])
            for i in range(len(count_anims)):
                count_anims[i].num.next_to(chart.bars[i], UP, buff = 0.2)

        chart.add_updater(updater)

        # Create bar chart and show bals0
        self.play(Create(chart))
        self.wait()

        # Show bals1
        self.play(*count_anims, run_time=1, rate_func=linear)
        self.wait()

        # Show d0
        y_value = 1
        # Manim coordinates
        y_max = chart.y_axis.get_top()[1]
        y_min = chart.y_axis.get_bottom()[1]
        x_min = chart.x_axis.get_left()[0]
        x_max = chart.x_axis.get_right()[0]
        # y = Manim coordinates, x = liquidity D
        y = lin(y_min, y_max, 0, MAX_BAL, d0 / 3)
        d0_line = Line(start=[x_min, y, 0], end=[x_max, y, 0], color=WHITE)
        d0_line.set_opacity(0.5)

        d0_tex = MathTex("\\frac{D_{0}}{3}", font_size = 36)
        d0_tex.next_to(d0_line.get_end(), RIGHT, buff = 0.2)

        # self.play(Create(d0_line))
        self.add(d0_line)
        self.add(d0_tex)
        self.wait()

        return

        for i in range(len(count_anims)):
            count_anim = count_anims[i]
            count_anim.start = bals1[i]
            count_anim.end = bals2[i]

        self.play(*count_anims, run_time=1, rate_func=linear)
        self.wait()

