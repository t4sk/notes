from manim import *


class StabilityFee(Scene):
    def construct(self):

        # Title
        title = Text("Stability Fee", font_size=60).to_edge(UP)
        self.play(Write(title))

        # Description block
        desc = VGroup(
            Text("Fee for borrowing USDS or DAI", font_size=28),
            Text("Fee compounds every second", font_size=28),
            Text("Rate may change every second", font_size=28),
        ).arrange(DOWN, aligned_edge=LEFT)

        desc.next_to(title, DOWN, buff=0.6)

        self.play(LaggedStart(*[FadeIn(x) for x in desc], lag_ratio=0.2))
        self.wait(2)

        self.play(FadeOut(desc))

        # Debt formula section
        section = Text("Debt after j seconds", font_size=36)
        section.next_to(title, DOWN)

        debt_formula = MathTex(
            r"d(1+r_k)(1+r_{k+1})(1+r_{k+2})\cdots(1+r_{k+j-1})"
        ).scale(1.2)

        debt_formula.next_to(section, DOWN)

        self.play(Write(section))
        self.play(Write(debt_formula))
        self.wait(2)

        # Rate accumulator
        rate_title = Text("Rate Accumulator", font_size=36)
        rate_title.to_edge(UP)

        rate_formula = MathTex(r"R(t)=(1+r_0)(1+r_1)\cdots(1+r_t)").scale(1.3)

        rate_formula.next_to(rate_title, DOWN)

        self.play(
            ReplacementTransform(section, rate_title),
            Transform(debt_formula, rate_formula),
        )

        self.wait(2)

        # Ratio transformation
        ratio = MathTex(r"d\frac{R(k+j-1)}{R(k-1)}").scale(1.5)

        ratio.next_to(rate_formula, DOWN)

        self.play(Write(ratio))
        self.wait(2)

        # Final equation
        final_formula = MathTex(
            r"\left(\frac{d}{R(k-1)} + \frac{\Delta d}{R(k+j-1)}\right)R(k+n-1)"
        ).scale(1.3)

        final_formula.next_to(ratio, DOWN, buff=0.8)

        self.play(Write(final_formula))
        self.wait(2)

        # Move formulas up to make space for graph
        formulas = VGroup(rate_title, rate_formula, ratio, final_formula)
        self.play(formulas.animate.scale(0.8).to_edge(UP))

        # Graph axes
        axes = Axes(
            x_range=[0, 10, 1],
            y_range=[0, 10, 2],
            x_length=8,
            y_length=4,
            axis_config={"include_tip": False},
        )

        axes.to_edge(DOWN)

        labels = axes.get_axis_labels("time", "debt")

        self.play(Create(axes), Write(labels))

        # Step debt curve
        step_points = [
            axes.coords_to_point(0, 2),
            axes.coords_to_point(2, 2),
            axes.coords_to_point(2, 3),
            axes.coords_to_point(4, 3),
            axes.coords_to_point(4, 5),
            axes.coords_to_point(6, 5),
            axes.coords_to_point(6, 7),
            axes.coords_to_point(8, 7),
        ]

        path = VMobject()
        path.set_points_as_corners(step_points)

        self.play(Create(path), run_time=3)

        # Mint label
        mint_label = Text("Mint Δd", font_size=24)
        mint_label.next_to(axes.coords_to_point(4, 5), UP)

        self.play(FadeIn(mint_label))

        self.wait(3)
