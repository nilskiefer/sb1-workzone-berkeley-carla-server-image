#!/usr/bin/env bash
set -euo pipefail

published_image_reference="ghcr.io/nilskiefer/sb1-workzone-berkeley-carla-server-image:0.9.16-sanramon"
published_sif="carla-sanramon.sif"

if [[ $# -gt 3 ]]; then
  echo "Usage: $0 [image] [output.sif] [apptainer-source]" >&2
  exit 2
fi

image="${1:-${published_image_reference}}"
sif="${2:-${published_sif}}"
source_ref="${3:-docker-daemon://${image}}"
tmp_sif="${sif}.tmp.$$"

if ! command -v apptainer >/dev/null 2>&1; then
  echo "apptainer is required to build a SIF" >&2
  exit 2
fi

if [[ "${source_ref}" == docker-daemon://* ]]; then
  if ! command -v docker >/dev/null 2>&1; then
    echo "docker is required for ${source_ref}" >&2
    exit 2
  fi
  docker image inspect "${image}" >/dev/null
fi

rm -f "${tmp_sif}"
apptainer build "${tmp_sif}" "${source_ref}"
apptainer exec "${tmp_sif}" test -x /workspace/CarlaUE4.sh
mv "${tmp_sif}" "${sif}"

if command -v sha256sum >/dev/null 2>&1; then
  sha256sum "${sif}" > "${sif}.sha256"
else
  shasum -a 256 "${sif}" > "${sif}.sha256"
fi

echo "Built SIF: ${sif}"
echo "Wrote checksum: ${sif}.sha256"
