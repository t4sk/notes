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

def d_line(chart, max_b, b, tex):
    # Show d0
    # Manim coordinates
    # y_axis top != bar chart max height, being lazy and add buffer to top
    y_max = chart.y_axis.get_top()[1] * 0.999
    y_min = chart.y_axis.get_bottom()[1]
    x_min = chart.x_axis.get_left()[0]
    x_max = chart.x_axis.get_right()[0]
    # y = Manim coordinates, x = liquidity 
    y = lin(y_min, y_max, 0, max_b, b)
    d_line = Line(start=[x_min, y, 0], end=[x_max, y, 0], color = WHITE)
    d_line.set_opacity(0.5)

    d_tex = MathTex(*tex, font_size = 36) 
    d_tex.next_to(d_line.get_end(), RIGHT, buff = 0.2)

    return (d_line, d_tex)

def h_line(chart, i, max_b, b, texs, color):
    # Show d0
    # Manim coordinates
    # y_axis top != bar chart max height, being lazy and add buffer to top
    y_max = chart.y_axis.get_top()[1] * 0.999
    y_min = chart.y_axis.get_bottom()[1]
    x_min = chart.bars[i].get_left()[0]
    x_max = chart.bars[i].get_right()[0]
    # y = Manim coordinates, x = liquidity 
    y = lin(y_min, y_max, 0, max_b, b)
    line = Line(start=[x_min, y, 0], end=[x_max, y, 0], color = color)
    line.set_opacity(0.5)

    tex = MathTex(*texs, font_size = 36) 
    tex.next_to(line.get_end(), RIGHT, buff = 0.2)

    return (line, tex)

def v_line(chart, i, max_b, b0, b1, tex):
    # Show d0
    # Manim coordinates (assumes bars[0] is at max height)
    y_max = chart.bars[0].get_top()[1]
    y_min = chart.bars[0].get_bottom()[1]
    x_right = chart.bars[i].get_right()[0]
    # y = Manim coordinates, x = liquidity 
    y0 = lin(y_min, y_max, 0, max_b, b0)
    y1 = lin(y_min, y_max, 0, max_b, b1)
    d_line = Line(start=[x_right, y0, 0], end=[x_right, y1, 0], color = PINK)
    d_line.set_opacity(0.5)
    d_line.shift(RIGHT * 0.2)

    d_tex = MathTex(*tex, font_size = 36) 
    d_tex.next_to(d_line.get_center(), RIGHT, buff = 0.2)

    return (d_line, d_tex)


class AddLiqImbalanceFee(Scene):
    def wait(self): 
        pass
        # super().wait()

    def construct(self):
        N = 3
        bals0 = [0, 0, 0]
        bals1 = [100, 90, 110]
        bals2 = [400, 90, 110]
        MAX_BAL = bals2[0]

        d0 = 299
        d1 = 581
        d2 = 576
        f = 0.01

        # ideal balances
        i_bals = [math.floor(d1 / d0 * b) for b in bals1]
        diffs = [b - bi for (b, bi) in zip(bals2, i_bals)]

        fees = [round(abs(d) * f * 100) / 100 for d in diffs]
        bals3 = [b - f for (b, f) in zip(bals2, fees)]

        count_anims = []
        for (b0, b1) in zip(bals0, bals1):
            num = DecimalNumber().set_color(WHITE)
            count = Count(num, b0, b1)
            count_anims.append(count)

        bar_colors = ["orange", "blue", "green"]

        chart = BarChart(
            bals0,
            bar_names = ["DAI", "USDC", "USDT"],
            bar_colors = bar_colors,
            bar_fill_opacity = 0.2,
            x_length = 10, 
            y_range=[0, MAX_BAL, 50],
            y_axis_config={"font_size": 24},
            x_axis_config={"font_size": 48},
        )

        def updater(chart):
            chart.change_bar_values([c.num.get_value() for c in count_anims])
            for i in range(N):
                count_anims[i].num.next_to(chart.bars[i], UP, buff = 0.2)

        chart.add_updater(updater)

        # Create bar chart and show bals0
        self.play(Create(chart))
        self.wait()

        # Show bals1
        self.play(*count_anims, run_time=1, rate_func=linear)
        self.wait()

        # Show d0
        (d0_line, d0_tex) = d_line(chart, MAX_BAL, d0 / 3, ["\\frac{D_{0}}{3}", "\\approx", f'{round(d0 / 3)}'])

        self.play(Create(d0_line))
        self.play(Write(d0_tex))
        self.wait()

        # SHow bals2
        for i in range(N):
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
        d_ratio = MathTex("\\frac{D_{1}}{D_{0}}", "\\approx", "\\frac{{{}}}{{{}}}".format(d1, d0), "\\approx", f'{d1 / d0:.2f}')
        d_ratio.to_corner(UP + RIGHT)
        self.play(Write(d_ratio))
        self.wait()

        # Fade d0 and d1 lines
        self.play(FadeOut(d0_tex, d1_tex, d0_line, d1_line))
        # self.play(FadeOut(d0_line, d1_line))
        self.wait()

        # Show ideal balances
        h_lines = []
        h_texs = []
        for i in range(N):
            b = i_bals[i]
            (line, tex) = h_line(chart, i, MAX_BAL, b, [f'{round(b)}'], bar_colors[i])
            h_lines.append(line)
            h_texs.append(tex)
            self.play(Create(line))
            self.play(Write(tex))
            self.wait()
        self.wait()

        # Animate difference in balances
        y_lines = []
        y_texs = []
        for i in range(N):
            self.play(Circumscribe(h_texs[i]))
            self.play(Circumscribe(count_anims[i].num))
            self.wait()

            bi = i_bals[i]
            b = bals2[i]
            (line, tex) = v_line(chart, i, MAX_BAL, bi, b, [f'{abs(round(b - bi))}'])
            y_lines.append(line)
            y_texs.append(tex)

            self.play(Create(line))
            self.play(Write(tex))
            self.wait()

        # Fee
        fee = MathTex("fee", "=", f'{f}')
        fee.to_corner(UP)
        self.play(Write(fee))
        self.wait()

        # Calculate imbalance fee
        for i in range(N):
            self.play(Circumscribe(y_texs[i]))
            self.wait()

            # round to 2 decimals
            fee_eq = MathTex(f'{round(abs(diffs[i]))}', "\\times", "fee", "=", f'{fees[i]}')
            fee_eq.shift(UP + RIGHT)
            self.play(Write(fee_eq))

            self.play(Circumscribe(count_anims[i].num))
            self.wait()

            self.play(FadeOut(y_lines[i], y_texs[i]))
            self.wait()

            count_anims[i].start = bals2[i]
            count_anims[i].end = bals3[i]

            self.play(count_anims[i], run_time=1, rate_func=linear)
            self.wait()

            self.play(FadeOut(fee_eq))
            self.wait()

        # Fade out h lines and texs
        self.play(FadeOut(*h_lines, *h_texs))
        self.wait()

        # Show d2
        (d2_line, d2_tex) = d_line(chart, MAX_BAL, d2 / 3, ["\\frac{D_{2}}{3}", "\\approx", f'{round(d2 / 3)}'])

        self.play(Create(d2_line))
        self.play(Write(d2_tex))
        self.wait()
