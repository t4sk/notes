from manim import *

class TitleScene(Scene):
    def construct(self):
        lines = VGroup(
            Text("EVM Memory", font_size=120, color=PURE_GREEN),
            Text("in Solidity", font_size=80),
        ).arrange(DOWN)
        self.play(Write(lines), run_time=1)
        self.wait(1)
        self.play(FadeOut(lines))
        self.wait(1)
