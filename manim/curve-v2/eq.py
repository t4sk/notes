from manim import *

class CurveEq(Scene):
    def construct(self):
        """
        $$AK_0D^{N-1}\sum_{i=1}^{N}{x_i} + \prod_{i=1}^N{x_i} = AK_0D^N + \left(\frac{D}{N}\right)^N$$

        $$K_0 = \frac{\prod_{i=1}^N{x_i} }{\left(\frac{D}{N}\right)^N}$$

        $$K=K_0\left(\frac{\gamma}{\gamma + 1 - K_0}\right)^2$$
        """
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

        curve_v2_eq.move_to(curve_v1_eq.get_center())
        k.move_to(k_eq[0].get_center())

        ### Animations ###
        self.play(Write(curve_v1_eq))
        self.play(Write(k0_eq))

        # K equation
        self.play(Write(k_eq))
        self.play(FadeToColor(k0_eq[0], color = ORANGE))
        self.play(
            FadeToColor(k_eq[2], color = ORANGE),
            FadeToColor(k_eq[4], color = ORANGE),
        )
        self.play(
            FadeToColor(k_eq[0], color = YELLOW),
        )

        # Move k and transform to Curve v2 equation
        k_copy_0 = k.copy()
        k_copy_1 = k.copy()
        self.play(
            k_copy_0.animate.move_to(curve_v1_eq[1].get_center()),
            k_copy_1.animate.move_to(curve_v1_eq[6].get_center()),
        )

        self.play(
            FadeOut(k_copy_0),
            FadeOut(k_copy_1),
            run_time = 1
        )

        self.play(ReplacementTransform(curve_v1_eq, curve_v2_eq))

        self.wait()
