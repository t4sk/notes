### Docs

https://docs.manim.community/en/stable/installation/docker.html#running-jupyterlab-via-docker

https://docs.manim.community/en/stable/tutorials/quickstart.html#your-first-scene

https://docs.manim.community/en/stable/examples.html

```shell
docker run -it --name my-manim --rm -v "$PWD:/manim" manimcommunity/manim bash

docker exec -it my-manim manim -qm title.py TitleScene
docker exec -it my-manim manim -qm array.py ArrayScene
```
