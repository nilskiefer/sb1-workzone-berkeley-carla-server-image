#!/usr/bin/env bash
set -euo pipefail

published_sif="carla-sanramon.sif"
published_sif_reference="oras://ghcr.io/nilskiefer/sb1-workzone-berkeley-carla-server-image-sif:0.9.16-sanramon"

if [[ $# -gt 2 ]]; then
  echo "Usage: $0 [image.sif] [oras-uri]" >&2
  exit 2
fi

sif="${1:-${published_sif}}"
sif_reference="${2:-${published_sif_reference}}"

if [[ ! -f "${sif}" ]]; then
  echo "SIF not found: ${sif}" >&2
  exit 2
fi

if ! command -v apptainer >/dev/null 2>&1; then
  echo "apptainer is required to push a SIF" >&2
  exit 2
fi

apptainer exec "${sif}" test -x /workspace/CarlaUE4.sh
apptainer push --allow-unsigned "${sif}" "${sif_reference}"

echo "Pushed SIF: ${sif_reference}"
