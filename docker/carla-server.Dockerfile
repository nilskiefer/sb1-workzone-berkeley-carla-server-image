FROM nvidia/opengl:1.2-glvnd-runtime-ubuntu20.04

ENV DEBIAN_FRONTEND=noninteractive

RUN useradd -m carla

WORKDIR /workspace

RUN packages='libsdl2-2.0 xserver-xorg libvulkan1 libomp5 xdg-user-dirs' \
    && apt-get update \
    && apt-get install -y --no-install-recommends $packages \
    && rm -rf /var/lib/apt/lists/*

ENV OMP_PROC_BIND="FALSE"
ENV OMP_NUM_THREADS="48"
ENV NVIDIA_DRIVER_CAPABILITIES="all"
ENV NVIDIA_VISIBLE_DEVICES="all"

COPY --chown=carla:carla CHANGELOG CarlaUE4.sh Dockerfile ImportAssets.sh LICENSE Manifest_DebugFiles_Linux.txt README VERSION ./
COPY --chown=carla:carla Co-Simulation ./Co-Simulation
COPY --chown=carla:carla Engine ./Engine
COPY --chown=carla:carla HDMaps ./HDMaps
COPY --chown=carla:carla Import ./Import
COPY --chown=carla:carla PythonAPI ./PythonAPI
COPY --chown=carla:carla Tools ./Tools
COPY --chown=carla:carla carla-0-9-16-linux ./carla-0-9-16-linux
COPY --chown=carla:carla CarlaUE4/AssetRegistry.bin CarlaUE4/CarlaUE4.uproject ./CarlaUE4/
COPY --chown=carla:carla CarlaUE4/Binaries ./CarlaUE4/Binaries
COPY --chown=carla:carla CarlaUE4/Config ./CarlaUE4/Config
COPY --chown=carla:carla CarlaUE4/Plugins ./CarlaUE4/Plugins
COPY --chown=carla:carla CarlaUE4/Content/Richmond_Field_Station_Richmond_CA ./CarlaUE4/Content/Richmond_Field_Station_Richmond_CA
COPY --chown=carla:carla CarlaUE4/Content/San_Ramon_P1_Roads ./CarlaUE4/Content/San_Ramon_P1_Roads
COPY --chown=carla:carla CarlaUE4/Content/Carla/Blueprints ./CarlaUE4/Content/Carla/Blueprints
COPY --chown=carla:carla CarlaUE4/Content/Carla/Config ./CarlaUE4/Content/Carla/Config
COPY --chown=carla:carla CarlaUE4/Content/Carla/Maps ./CarlaUE4/Content/Carla/Maps
COPY --chown=carla:carla CarlaUE4/Content/Carla/Static/Building ./CarlaUE4/Content/Carla/Static/Building
COPY --chown=carla:carla CarlaUE4/Content/Carla/Static/Car ./CarlaUE4/Content/Carla/Static/Car
COPY --chown=carla:carla CarlaUE4/Content/Carla/Static/Pedestrian ./CarlaUE4/Content/Carla/Static/Pedestrian
COPY --chown=carla:carla CarlaUE4/Content/Carla/Static/Vegetation ./CarlaUE4/Content/Carla/Static/Vegetation
COPY --chown=carla:carla CarlaUE4/Content/Carla/Static/Bicycle ./CarlaUE4/Content/Carla/Static/Bicycle
COPY --chown=carla:carla CarlaUE4/Content/Carla/Static/Bridge ./CarlaUE4/Content/Carla/Static/Bridge
COPY --chown=carla:carla CarlaUE4/Content/Carla/Static/Bus ./CarlaUE4/Content/Carla/Static/Bus
COPY --chown=carla:carla CarlaUE4/Content/Carla/Static/CubeMaps ./CarlaUE4/Content/Carla/Static/CubeMaps
COPY --chown=carla:carla CarlaUE4/Content/Carla/Static/Decals ./CarlaUE4/Content/Carla/Static/Decals
COPY --chown=carla:carla CarlaUE4/Content/Carla/Static/Dynamic ./CarlaUE4/Content/Carla/Static/Dynamic
COPY --chown=carla:carla CarlaUE4/Content/Carla/Static/Fence ./CarlaUE4/Content/Carla/Static/Fence
COPY --chown=carla:carla CarlaUE4/Content/Carla/Static/GenericMaterials ./CarlaUE4/Content/Carla/Static/GenericMaterials
COPY --chown=carla:carla CarlaUE4/Content/Carla/Static/Ground ./CarlaUE4/Content/Carla/Static/Ground
COPY --chown=carla:carla CarlaUE4/Content/Carla/Static/GuardRail ./CarlaUE4/Content/Carla/Static/GuardRail
COPY --chown=carla:carla CarlaUE4/Content/Carla/Static/HDRi ./CarlaUE4/Content/Carla/Static/HDRi
COPY --chown=carla:carla CarlaUE4/Content/Carla/Static/Hair ./CarlaUE4/Content/Carla/Static/Hair
COPY --chown=carla:carla CarlaUE4/Content/Carla/Static/Motorcycle ./CarlaUE4/Content/Carla/Static/Motorcycle
COPY --chown=carla:carla CarlaUE4/Content/Carla/Static/Other ./CarlaUE4/Content/Carla/Static/Other
COPY --chown=carla:carla CarlaUE4/Content/Carla/Static/Particles ./CarlaUE4/Content/Carla/Static/Particles
COPY --chown=carla:carla CarlaUE4/Content/Carla/Static/Pole ./CarlaUE4/Content/Carla/Static/Pole
COPY --chown=carla:carla CarlaUE4/Content/Carla/Static/RailTrack ./CarlaUE4/Content/Carla/Static/RailTrack
COPY --chown=carla:carla CarlaUE4/Content/Carla/Static/Road ./CarlaUE4/Content/Carla/Static/Road
COPY --chown=carla:carla CarlaUE4/Content/Carla/Static/RoadLine ./CarlaUE4/Content/Carla/Static/RoadLine
COPY --chown=carla:carla CarlaUE4/Content/Carla/Static/SideWalk ./CarlaUE4/Content/Carla/Static/SideWalk
COPY --chown=carla:carla CarlaUE4/Content/Carla/Static/Sky ./CarlaUE4/Content/Carla/Static/Sky
COPY --chown=carla:carla CarlaUE4/Content/Carla/Static/Static ./CarlaUE4/Content/Carla/Static/Static
COPY --chown=carla:carla CarlaUE4/Content/Carla/Static/StreetLight ./CarlaUE4/Content/Carla/Static/StreetLight
COPY --chown=carla:carla CarlaUE4/Content/Carla/Static/Terrain ./CarlaUE4/Content/Carla/Static/Terrain
COPY --chown=carla:carla CarlaUE4/Content/Carla/Static/TestWindowsParts ./CarlaUE4/Content/Carla/Static/TestWindowsParts
COPY --chown=carla:carla CarlaUE4/Content/Carla/Static/TrafficLight ./CarlaUE4/Content/Carla/Static/TrafficLight
COPY --chown=carla:carla CarlaUE4/Content/Carla/Static/TrafficSign ./CarlaUE4/Content/Carla/Static/TrafficSign
COPY --chown=carla:carla CarlaUE4/Content/Carla/Static/Truck ./CarlaUE4/Content/Carla/Static/Truck
COPY --chown=carla:carla CarlaUE4/Content/Carla/Static/Wall ./CarlaUE4/Content/Carla/Static/Wall
COPY --chown=carla:carla CarlaUE4/Content/Carla/Static/Water ./CarlaUE4/Content/Carla/Static/Water

USER carla

EXPOSE 2000-2002 8000

CMD ["./CarlaUE4.sh", "-RenderOffScreen", "-nosound", "-stdout", "-FullStdOutLogOutput", "-carla-rpc-port=2000", "-quality-level=Epic"]
