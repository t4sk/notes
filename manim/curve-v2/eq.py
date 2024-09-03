from manim import *

class CurveEqIntro(Scene):
    def construct(self):
        curve_v2_eq = MathTex(
            "A", "K", "D^{N-1}\\sum_{i=1}^{N}{x_i} + \\prod_{i=1}^N{x_i}",
            "=", 
            "A", "K", "D^N + \\left(\\frac{D}{N}\\right)^N"
        )

        k0_eq = MathTex(
            "K_0", "=", "\\frac{\\prod_{i=1}^N{x_i} }{\\left(\\frac{D}{N}\\right)^N}"
        )
        k_eq = MathTex(
            "K", "=", "K_0", "\left(\\frac{\gamma}{\gamma + 1 - ", "K_0", "}\\right)^2"
        )

        ### Positions ###
        VGroup(curve_v2_eq, k0_eq, k_eq).arrange(DOWN, buff = 1)

        self.play(Write(curve_v2_eq))
        self.play(Write(k0_eq))
        self.play(Write(k_eq))
        self.wait()

        self.play(
            FadeOut(curve_v2_eq),
            FadeOut(k0_eq),
            FadeOut(k_eq),
        )
        self.wait()

class CurveEq(Scene):
    def construct(self):
        """
        $$AK_0D^{N-1}\sum_{i=1}^{N}{x_i} + \prod_{i=1}^N{x_i} = AK_0D^N + \left(\frac{D}{N}\right)^N$$

        $$K_0 = \frac{\prod_{i=1}^N{x_i} }{\left(\frac{D}{N}\right)^N}$$

        $$K=K_0\left(\frac{\gamma}{\gamma + 1 - K_0}\right)^2$$
        """
        eqs = [
                MathTex(
                    "\\sum_{i=1}^{N}{x_i}",
                    "=", 
                    "D"
                ),
                MathTex(
                    # 0                      1
                    "\\sum_{i=1}^{N}{x_i}", "+ \\prod_{i=1}^N{x_i}",
                    # 2
                    "=", 
                    # 3   4
                    "D", "+ \\left(\\frac{D}{N}\\right)^N"
                ),
                MathTex(
                    # 0         1                       2
                    "D^{N-1}", "\\sum_{i=1}^{N}{x_i}", "+ \\prod_{i=1}^N{x_i}",
                    # 3
                    "=", 
                    # 4   5     6
                    "D", "^N", "+ \\left(\\frac{D}{N}\\right)^N"
                ),
                MathTex(
                    # 0      1           2                         3
                    "AK_0", "D^{N-1}", "\\sum_{i=1}^{N}{x_i}", "+ \\prod_{i=1}^N{x_i}",
                    # 4
                    "=", 
                    # 5      6     7    8
                    "AK_0", "D", "^N", "+ \\left(\\frac{D}{N}\\right)^N"
                ),
        ]
        eq = MathTex(
            "AK_0", "D", "^{N-1}", "\\sum_{i=1}^{N}{x_i}", "+ \\prod_{i=1}^N{x_i}",
            "=", 
            "AK_0", "D", "^N", "+ \\left(\\frac{D}{N}\\right)^N"
        )
        curve_v1_eq = MathTex(
            "A", "K", "_0", "D^{N-1}\\sum_{i=1}^{N}{x_i} + \\prod_{i=1}^N{x_i}",
            "=", 
            "A", "K", "_0", "D^N + \\left(\\frac{D}{N}\\right)^N"
        )
        curve_v2_eq = MathTex(
            "A", "K", "D^{N-1}\\sum_{i=1}^{N}{x_i} + \\prod_{i=1}^N{x_i}",
            "=", 
            "A", "K", "D^N + \\left(\\frac{D}{N}\\right)^N"
        )
        curve_v2_eq[1].set_color(YELLOW)
        curve_v2_eq[5].set_color(YELLOW)

        k0_eq = MathTex(
            "K_0", "=", "\\frac{\\prod_{i=1}^N{x_i} }{\\left(\\frac{D}{N}\\right)^N}"
        )
        k_eq = MathTex(
            "K", "=", "K_0", "\left(\\frac{\gamma}{\gamma + 1 - ", "K_0", "}\\right)^2"
        )
        k = MathTex("K", color = YELLOW)

        ### Positions ###
        VGroup(curve_v1_eq, k0_eq, k_eq).arrange(DOWN, buff = 1)

        for eq in eqs:
            eq.move_to(curve_v1_eq.get_center())

        curve_v2_eq.move_to(curve_v1_eq.get_center())
        k.move_to(k_eq[0].get_center())

        ### Animations ###
        self.play(Write(eqs[0]))
        self.wait()

        self.play(
            eqs[0][0].animate.move_to(eqs[1][0].get_center()),
            eqs[0][1].animate.move_to(eqs[1][2].get_center()),
            eqs[0][2].animate.move_to(eqs[1][3].get_center()),
        )
        self.play(Write(eqs[1]))
        self.remove(eqs[0])
        self.wait()

        self.play(
            eqs[1][0].animate.move_to(eqs[2][1].get_center()),
            eqs[1][1].animate.move_to(eqs[2][2].get_center()),
            eqs[1][2].animate.move_to(eqs[2][3].get_center()),
            eqs[1][3].animate.move_to(eqs[2][4].get_center()),
            eqs[1][4].animate.move_to(eqs[2][6].get_center()),
        )
        self.play(Write(eqs[2]))
        self.remove(eqs[1])
        self.wait()

        self.play(
            eqs[2][0].animate.move_to(eqs[3][1].get_center()),
            eqs[2][1].animate.move_to(eqs[3][2].get_center()),
            eqs[2][2].animate.move_to(eqs[3][3].get_center()),
            eqs[2][3].animate.move_to(eqs[3][4].get_center()),
            eqs[2][4].animate.move_to(eqs[3][6].get_center()),
            eqs[2][5].animate.move_to(eqs[3][7].get_center()),
            eqs[2][6].animate.move_to(eqs[3][8].get_center()),
        )
        self.play(Write(eqs[3]))
        self.remove(eqs[2])
        self.wait()

        # Curve v1 equation
        self.add(curve_v1_eq)
        self.remove(eqs[3])
        self.play(Write(k0_eq))
        self.wait()

        # K equation
        self.play(Write(k_eq))
        self.wait()

        self.play(FadeToColor(k0_eq[0], color = ORANGE))
        self.wait()

        self.play(
            FadeToColor(k_eq[2], color = ORANGE),
            FadeToColor(k_eq[4], color = ORANGE),
        )
        self.wait()

        self.play(
            FadeToColor(k_eq[0], color = YELLOW),
        )
        self.wait()

        # Move k and transform to Curve v2 equation
        k_copy_0 = k.copy()
        k_copy_1 = k.copy()
        self.play(
            k_copy_0.animate.move_to(curve_v1_eq[1].get_center()),
            k_copy_1.animate.move_to(curve_v1_eq[6].get_center()),
        )
        self.wait()

        self.play(
            FadeOut(k_copy_0),
            FadeOut(k_copy_1),
            run_time = 1
        )
        self.wait()

        self.play(ReplacementTransform(curve_v1_eq, curve_v2_eq))
        self.wait()
