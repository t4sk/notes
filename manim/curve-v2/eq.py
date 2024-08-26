from manim import *

class CurveEq(Scene):
    def construct(self):
        """
        $$AK_0D^{N-1}\sum_{i=1}^{N}{x_i} + \prod_{i=1}^N{x_i} = AK_0D^N + \left(\frac{D}{N}\right)^N$$

        $$K_0 = \frac{\prod_{i=1}^N{x_i} }{\left(\frac{D}{N}\right)^N}$$

        $$K=K_0\left(\frac{\gamma}{\gamma + 1 - K_0}\right)^2$$
        """
        curve_v1_eq = MathTex(
                "A", "K_0", "D^{N-1}\\sum_{i=1}^{N}{x_i} + \\prod_{i=1}^N{x_i}",
                "=", 
                "A", "K_0", "D^N + \\left(\\frac{D}{N}\\right)^N"
            #"\\frac{d}{dx}f(x)g(x)=","f(x)\\frac{d}{dx}g(x)","+",
            #"g(x)\\frac{d}{dx}f(x)"
        )
        k0_eq = MathTex(
            "K_0 = \\frac{\\prod_{i=1}^N{x_i} }{\\left(\\frac{D}{N}\\right)^N}"
        )
        k_eq = MathTex(
            "K","=", "K_0\left(\\frac{\gamma}{\gamma + 1 - K_0}\\right)^2"
        )
        k = MathTex("K")

        g = VGroup(curve_v1_eq, k0_eq, k_eq).arrange(DOWN, buff = 1)

        self.play(Write(curve_v1_eq))
        self.play(Write(k0_eq))
        self.play(Write(k_eq))

        eq_transform = VGroup(*curve_v1_eq, k)

        # self.play(ReplacementTransform(eq_transform[1], eq_transform[1]))
        self.play(ReplacementTransform(k_eq[0], eq_transform[1]))
        # framebox1 = SurroundingRectangle(curve_v1_eq[0], buff = .1)
        # framebox2 = SurroundingRectangle(curve_v1_eq[3], buff = .1)
        # self.play(
        #     Create(framebox1),
        # )
        self.wait()
        # self.play(
        #     ReplacementTransform(framebox1,framebox2),
        # )
        # self.wait()
