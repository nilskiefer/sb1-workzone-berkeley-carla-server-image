#!/usr/bin/env bash
set -euo pipefail

published_image_reference="ghcr.io/nilskiefer/sb1-workzone-berkeley-carla-server-image:0.9.16-sanramon"

if [[ $# -gt 1 ]]; then
  echo "Usage: $0 [image]" >&2
  exit 2
fi

image="${1:-${published_image_reference}}"

docker push "${image}"
