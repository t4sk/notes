from manim import *
import math

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

def d_line(chart, max_bal, b, tex):
    # Show d0
    # Manim coordinates
    y_max = chart.y_axis.get_top()[1]
    y_min = chart.y_axis.get_bottom()[1]
    x_min = chart.x_axis.get_left()[0]
    x_max = chart.x_axis.get_right()[0]
    # y = Manim coordinates, x = liquidity 
    y = lin(y_min, y_max, 0, max_bal, b)
    d_line = Line(start=[x_min, y, 0], end=[x_max, y, 0], color=WHITE)
    d_line.set_opacity(0.5)

    d_tex = MathTex(*tex, font_size = 36) 
    d_tex.next_to(d_line.get_end(), RIGHT, buff = 0.2)

    return (d_line, d_tex)


class Bar(Scene):
    def wait(self): 
        super().wait()

    def construct(self):
        bals0=[0, 0, 0]
        bals1=[100, 90, 110]
        bals2=[400, 90, 110]
        MAX_BAL = bals2[0]

        d0 = 299.8991189141142
        d1 = 581.8477119377197

        # ideal balances
        i_bals = [d1 / d0 * b for b in bals1]
        diff = [b - bi for (b, bi) in zip(bals2, i_bals)]

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
            y_range=[0, MAX_BAL, 50],
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
        (d0_line, d0_tex) = d_line(chart, MAX_BAL, d0 /3, ["\\frac{D_{0}}{3}", "\\approx", f'{round(d0 / 3)}'])

        self.play(Create(d0_line))
        self.play(Write(d0_tex))
        self.wait()

        # SHow bals2
        for i in range(len(count_anims)):
            count_anim = count_anims[i]
            count_anim.start = bals1[i]
            count_anim.end = bals2[i]

        self.play(*count_anims, run_time=1, rate_func=linear)
        self.wait()

        # Show d1
        (d1_line, d1_tex) = d_line(chart, MAX_BAL, d1 / 3, ["\\frac{D_{1}}{3}", "\\approx", f'{round(d1 / 3)}'])

        self.play(Create(d1_line))
        self.play(Write(d1_tex))
        self.wait()

        # Circumscribe d0 and d1 next to bar graph
        self.play(Circumscribe(VGroup(d0_tex[0][0], d0_tex[0][1])))
        self.play(Circumscribe(VGroup(d1_tex[0][0], d1_tex[0][1])))
        self.wait()

        # Show d1 / d0
        d_ratio = MathTex("\\frac{D_{1}}{D_{0}}", "\\approx", f'{d1 / d0:.2f}')
        d_ratio.to_corner(UP + RIGHT)
        self.play(Write(d_ratio))
        self.wait()

        # Fade d0 and d1 lines
        self.play(FadeOut(d0_tex, d1_tex))
        self.play(FadeOut(d0_line, d1_line))

