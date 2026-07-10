#!/usr/bin/env bash
set -euo pipefail

image="${CARLA_SERVER_IMAGE:-ghcr.io/nilskiefer/sb1-workzone-berkeley-carla-server-image:0.9.16-sanramon}"

docker push "${image}"
