#!/usr/bin/env bash
set -euo pipefail

if [[ $# -gt 2 ]]; then
  echo "Usage: $0 /path/to/carla.sif [writable-runtime-dir]" >&2
  exit 2
fi

sif="${1:-}"
runtime_dir="${2:-${CARLA_RUNTIME_DIR:-${TMPDIR:-/tmp}/carla-runtime}}"
server="/workspace/CarlaUE4/Binaries/Linux/CarlaUE4-Linux-Shipping"

if [[ -z "${sif}" ]]; then
  echo "A CARLA SIF path is required." >&2
  exit 2
fi

if ! command -v apptainer >/dev/null 2>&1; then
  echo "apptainer is required to run a CARLA SIF" >&2
  exit 2
fi

if [[ ! -f "${sif}" ]]; then
  echo "SIF not found: ${sif}" >&2
  exit 2
fi

if ! apptainer exec "${sif}" test -x "${server}"; then
  echo "CARLA server executable is missing or not executable in ${sif}" >&2
  exit 2
fi

mkdir -p \
  "${runtime_dir}/Saved" \
  "${runtime_dir}/Intermediate" \
  "${runtime_dir}/home"

cpus="${SLURM_CPUS_PER_TASK:-$(nproc)}"

# Do not invoke CarlaUE4.sh here.  It chmods the binary at startup, but a SIF
# is immutable; invoking the shipping binary directly is the SIF-safe path.
exec apptainer exec \
  --nv \
  --bind "${runtime_dir}/Saved:/workspace/CarlaUE4/Saved" \
  --bind "${runtime_dir}/Intermediate:/workspace/CarlaUE4/Intermediate" \
  --home "${runtime_dir}/home" \
  --env OMP_PROC_BIND=FALSE \
  --env OMP_NUM_THREADS="${cpus}" \
  --pwd /workspace \
  "${sif}" \
  "${server}" \
    CarlaUE4 \
    -RenderOffScreen \
    -nosound \
    -stdout \
    -FullStdOutLogOutput \
    -carla-rpc-port=2000 \
    -quality-level=Epic
