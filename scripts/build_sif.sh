#!/usr/bin/env bash
set -euo pipefail

published_image_reference="ghcr.io/nilskiefer/sb1-workzone-berkeley-carla-server-image:0.9.16-sanramon"
published_sif="carla-sanramon.sif"

if [[ $# -gt 3 ]]; then
  echo "Usage: $0 [image] [output.sif] [/path/to/carla-runtime|apptainer-source]" >&2
  exit 2
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
image="${1:-${published_image_reference}}"
sif="${2:-${published_sif}}"
source_arg="${3:-docker-daemon://${image}}"
tmp_sif="${sif}.tmp.$$"
cache_root="${APPTAINER_BUILD_CACHE_ROOT:-${HOME}/.cache/carla-apptainer}"

if ! command -v apptainer >/dev/null 2>&1; then
  echo "apptainer is required to build a SIF" >&2
  exit 2
fi

mkdir -p "${cache_root}/tmp" "${cache_root}/cache"
export TMPDIR="${TMPDIR:-${cache_root}/tmp}"
export APPTAINER_TMPDIR="${APPTAINER_TMPDIR:-${cache_root}/tmp}"
export APPTAINER_CACHEDIR="${APPTAINER_CACHEDIR:-${cache_root}/cache}"

if [[ "${source_arg}" == docker-daemon://* || "${source_arg}" == docker://* || "${source_arg}" == oras://* || "${source_arg}" == library://* || "${source_arg}" == shub://* ]]; then
  source_ref="${source_arg}"
else
  "${repo_root}/scripts/build_image.sh" "${source_arg}" "${image}"
  source_ref="docker-daemon://${image}"
fi

if [[ "${source_ref}" == docker-daemon://* ]]; then
  if ! command -v docker >/dev/null 2>&1; then
    echo "docker is required for ${source_ref}" >&2
    exit 2
  fi
  if ! docker image inspect "${image}" >/dev/null; then
    echo "Local Docker image not found: ${image}" >&2
    echo "Build it first:" >&2
    echo "  ./scripts/build_image.sh /path/to/carla-runtime ${image}" >&2
    echo "Or build the Docker image and SIF together:" >&2
    echo "  ./scripts/build_sif.sh ${image} ${sif} /path/to/carla-runtime" >&2
    exit 2
  fi
  echo "Building SIF from local Docker image: ${image}"
else
  echo "Building SIF from Apptainer source: ${source_ref}"
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
