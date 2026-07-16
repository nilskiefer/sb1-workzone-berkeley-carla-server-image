# CARLA Server Image

CARLA 0.9.16 server image for [CarlaMayo](https://github.berkeley.edu/peggywang/CarlaMayo).

## Use The Released Image

Requirements: Linux, Docker, Docker Compose, NVIDIA driver, and NVIDIA
Container Toolkit.

```bash
git clone https://github.com/nilskiefer/sb1-workzone-berkeley-carla-server-image.git
cd sb1-workzone-berkeley-carla-server-image
docker compose pull
docker compose up -d --wait carla-server
```

The released image is:

```text
ghcr.io/nilskiefer/sb1-workzone-berkeley-carla-server-image:0.9.16-sanramon
```

CARLA is available at `localhost:2000`.

```bash
docker compose ps
docker compose logs -f carla-server
docker compose down
```

For running CARLA and CarlaMayo on Berkeley Savio, see [SAVIO.md](SAVIO.md).
The Savio flow uses VS Code on the login node for editing and a separate
terminal on the allocated compute node for CARLA and CarlaMayo.
If you already have a running Savio GPU allocation and are on a Savio login
node, [SAVIO.md](SAVIO.md) includes a one-shot command to reconnect to the
assigned compute node without requesting another Slurm job.

## Run the SIF on an Apptainer Host

Pull the published SIF to a location with at least 35 GB available, then use
the SIF launcher. The second argument is a writable directory for CARLA's
saved data and temporary files.

```bash
export APPTAINER_CACHEDIR=/path/with-space/apptainer-cache
export APPTAINER_TMPDIR=/path/with-space/apptainer-tmp
mkdir -p "$APPTAINER_CACHEDIR" "$APPTAINER_TMPDIR"

apptainer pull carla-sanramon.sif \
  oras://ghcr.io/nilskiefer/sb1-workzone-berkeley-carla-server-image-sif:0.9.16-sanramon
./scripts/run_sif.sh carla-sanramon.sif /path/with-space/carla-runtime
```

The launcher intentionally invokes the CARLA shipping binary instead of
`CarlaUE4.sh`: the wrapper attempts to change file permissions, which is not
possible in a read-only SIF.

## Build And Publish Your Own Image

Use this only to publish a runtime different from the released image.

1. Place an unpacked CARLA 0.9.16 runtime in:

   ```text
   Place_carla_Folder_in_here/carla/
   ├── CarlaUE4.sh
   ├── CarlaUE4/
   └── PythonAPI/
   ```

2. Choose an image reference in your GitHub Container Registry namespace:

   ```text
   ghcr.io/YOUR_GITHUB_USER/YOUR_IMAGE:0.9.16
   ```

3. Build it:

   ```bash
   ./scripts/build_image.sh \
     Place_carla_Folder_in_here/carla \
     ghcr.io/YOUR_GITHUB_USER/YOUR_IMAGE:0.9.16
   ```

4. Sign in to GHCR with a GitHub token that has `write:packages`, then push:

   ```bash
   docker login ghcr.io
   ./scripts/push_image.sh ghcr.io/YOUR_GITHUB_USER/YOUR_IMAGE:0.9.16
   ```

5. For Savio, build a prebuilt SIF on a Linux machine with Apptainer:

   ```bash
   ./scripts/build_sif.sh \
     ghcr.io/YOUR_GITHUB_USER/YOUR_IMAGE:0.9.16 \
     carla-sanramon.sif
   ```

   Log in to GHCR with a GitHub token that has `write:packages`, then push the
   SIF as an ORAS artifact:

   ```bash
   apptainer registry login --username YOUR_GITHUB_USER oras://ghcr.io
   ./scripts/push_sif.sh \
     carla-sanramon.sif \
     oras://ghcr.io/YOUR_GITHUB_USER/YOUR_IMAGE-sif:0.9.16
   ```

   Use the matching `oras://...` reference in [SAVIO.md](SAVIO.md). This lets
   Savio pull the prebuilt SIF directly instead of converting the Docker image.

6. To deploy your image on any machine with Docker, change the `image:` value in
   `docker-compose.yml` to your image reference, then run:

   ```bash
   docker compose pull
   docker compose up -d --wait carla-server
   ```

The builder includes every file under the supplied CARLA runtime. The current
runtime includes the San Ramon map used by CarlaMayo's supplied routes.

## Ports

| Service | Host port |
|---|---|
| CARLA RPC | `2000` |
| CARLA streaming | `2001` |
| CARLA secondary | `2002` |
| Container Traffic Manager | `18000` |
