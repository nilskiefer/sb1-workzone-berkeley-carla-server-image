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

5. To deploy your image on any machine, change the `image:` value in
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
