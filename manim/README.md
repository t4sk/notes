https://docs.manim.community/en/stable/installation/docker.html#running-jupyterlab-via-docker

https://docs.manim.community/en/stable/tutorials/quickstart.html#your-first-scene

```shell
docker run -it --name my-manim -v "$PWD:/manim" manimcommunity/manim bash

manim -p -ql example.py SquareToCircle

docker exec -it my-manim manim -qm test_scenes.py CircleToSquare

docker run -it -p 8888:8888 manimcommunity/manim jupyter lab --ip=0.0.0.0

```
