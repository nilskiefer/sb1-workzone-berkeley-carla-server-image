#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
runtime_root="${CARLA_RUNTIME_ROOT:-${repo_root}/../carla-server/carla}"
image="${CARLA_SERVER_IMAGE:-ghcr.io/nilskiefer/sb1-workzone-berkeley-carla-server-image:0.9.16-sanramon}"

docker build \
  --file "${repo_root}/docker/carla-server.Dockerfile" \
  --tag "${image}" \
  "${runtime_root}"

echo "Built ${image}"
