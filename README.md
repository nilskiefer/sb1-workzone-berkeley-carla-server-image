# CARLA Server Image

Docker packaging for the local CARLA 0.9.16 server runtime used by CarlaMayo.

This repository intentionally does not store the CARLA runtime itself. It builds
from the packaged runtime at `../carla-server/carla`, which currently includes
the custom `San_Ramon_P1_Roads` map.

## Build

Copy the sample env file and set the target image:

```bash
cp .env.example .env
```

For GHCR on normal GitHub, use an image name like:

```text
CARLA_SERVER_IMAGE=ghcr.io/nilskiefer/sb1-workzone-berkeley-carla-server-image:0.9.16-sanramon
```

Build the image:

```bash
./scripts/build_image.sh
```

The build context is the CARLA runtime directory, but the Dockerfile is owned by
this repository.

## Run Locally

```bash
docker compose up -d carla-server
docker compose logs -f carla-server
```

On a new machine, set `CARLA_SERVER_IMAGE` to the published registry image and
run the same Compose command. The local CARLA runtime directory is only needed
for building the image.

The server runs headlessly with `-RenderOffScreen` and exposes:

- `2000`: CARLA RPC
- `2001`: streaming
- `2002`: secondary CARLA port
- `18000`: container Traffic Manager port `8000`

From CarlaMayo, keep using:

```bash
export CARLA_HOST=127.0.0.1
export CARLA_PORT=2000
export CARLA_TM_PORT=8000
```

`CARLA_TM_PORT=8000` is intentionally left free on the host so CarlaMayo can
create its local Traffic Manager without colliding with the container port.

## Push

Authenticate to GHCR:

```bash
echo "$GITHUB_TOKEN" | docker login ghcr.io -u nilskiefer --password-stdin
```

The token needs `write:packages`. For private images, consumers need
`read:packages`.

Push:

```bash
./scripts/push_image.sh
```
