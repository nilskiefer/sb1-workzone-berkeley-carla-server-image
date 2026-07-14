# syntax=docker/dockerfile:1.7
FROM nvidia/opengl:1.2-glvnd-runtime-ubuntu20.04

ENV DEBIAN_FRONTEND=noninteractive

RUN useradd -m carla

WORKDIR /workspace

RUN packages='libsdl2-2.0 xserver-xorg libvulkan1 libomp5 xdg-user-dirs tar' \
    && apt-get update \
    && apt-get install -y --no-install-recommends $packages \
    && rm -rf /var/lib/apt/lists/*

ENV OMP_PROC_BIND="FALSE"
ENV OMP_NUM_THREADS="48"
ENV NVIDIA_DRIVER_CAPABILITIES="all"
ENV NVIDIA_VISIBLE_DEVICES="all"

# RUNTIME_LAYERS

RUN chmod a+x \
        /workspace/CarlaUE4.sh \
        /workspace/CarlaUE4/Binaries/Linux/CarlaUE4-Linux-Shipping

USER carla

EXPOSE 2000-2002 8000

CMD ["./CarlaUE4.sh", "-RenderOffScreen", "-nosound", "-stdout", "-FullStdOutLogOutput", "-carla-rpc-port=2000", "-quality-level=Epic"]
