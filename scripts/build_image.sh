#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
in_repo_runtime_root="${repo_root}/Place_carla_Folder_in_here/carla"
published_image_reference="ghcr.io/nilskiefer/sb1-workzone-berkeley-carla-server-image:0.9.16-sanramon"
target_layer_size_bytes=$((4 * 1024 * 1024 * 1024))
target_layer_size_label="4 GiB"
maximum_layer_size_bytes=$((10 * 1000 * 1000 * 1000))
maximum_layer_size_label="10 GB"

if [[ $# -gt 2 ]]; then
  echo "Usage: $0 [/path/to/carla-runtime] [image]" >&2
  exit 2
fi

if [[ $# -ge 1 ]]; then
  runtime_root="$1"
else
  runtime_root="${in_repo_runtime_root}"
fi
image="${2:-${published_image_reference}}"

if [[ ! -f "${runtime_root}/CarlaUE4.sh" ]]; then
  echo "CARLA runtime not found: ${runtime_root}" >&2
  echo "Place it in ${in_repo_runtime_root} or pass its path as the first argument." >&2
  exit 2
fi

format_gib() {
  awk -v bytes="$1" 'BEGIN { printf "%.2f GiB", bytes / 1024 / 1024 / 1024 }'
}

manifest_dir="$(mktemp -d)"
trap 'rm -rf "${manifest_dir}"' EXIT

echo "Preparing runtime layers from ${runtime_root}"
runtime_size_bytes="$(du -sb "${runtime_root}" | awk '{print $1}')"
runtime_entry_count="$(find "${runtime_root}" -printf . | wc -c)"
estimated_layer_count=$(((runtime_size_bytes + target_layer_size_bytes - 1) / target_layer_size_bytes))
progress_total_bytes="${runtime_size_bytes}"
if (( progress_total_bytes == 0 )); then
  progress_total_bytes=1
fi
echo "Runtime inventory: $(format_gib "${runtime_size_bytes}") across ${runtime_entry_count} entries"
echo "Layer target: ${target_layer_size_label} (${estimated_layer_count} estimated runtime layers; ${maximum_layer_size_label} hard cap)"
layer_manifests=()
chunk_list="${manifest_dir}/chunk-paths"
chunk_size=0
chunk_path_count=0
chunk_index=0
packed_size=0
: > "${chunk_list}"

flush_chunk() {
  if [[ ! -s "${chunk_list}" ]]; then
    return
  fi
  local completed_size
  local completed_percent
  local layer_manifest
  layer_manifest="${manifest_dir}/runtime-${chunk_index}.list"
  completed_size=$((packed_size + chunk_size))
  completed_percent=$((completed_size * 100 / progress_total_bytes))
  mv "${chunk_list}" "${layer_manifest}"
  layer_manifests+=("${layer_manifest}")
  packed_size="${completed_size}"
  echo "Planned layer $((chunk_index + 1)): $(format_gib "${chunk_size}") from ${chunk_path_count} paths; ${completed_percent}% total"
  chunk_index=$((chunk_index + 1))
  chunk_size=0
  chunk_path_count=0
  : > "${chunk_list}"
}

echo "Scanning runtime files"
while IFS= read -r -d '' path; do
  file_size="$(stat -c '%s' "${runtime_root}/${path#./}")"
  if (( file_size > maximum_layer_size_bytes )); then
    echo "File exceeds the ${maximum_layer_size_label} runtime layer limit: ${path}" >&2
    exit 2
  fi
  if (( chunk_size > 0 && chunk_size + file_size > target_layer_size_bytes )); then
    flush_chunk
  fi
  printf '%s\0' "${path}" >> "${chunk_list}"
  chunk_size=$((chunk_size + file_size))
  chunk_path_count=$((chunk_path_count + 1))
done < <(
  cd "${runtime_root}"
  find . \( -type f -o -type l \) -print0
)
flush_chunk

generated_dockerfile="${manifest_dir}/Dockerfile"
awk '/^# RUNTIME_LAYERS$/ { exit } { print }' \
  "${repo_root}/docker/carla-server.Dockerfile" > "${generated_dockerfile}"
cat >> "${generated_dockerfile}" <<'EOF'
RUN --mount=type=bind,target=/runtime,readonly \
    cd /runtime && find . -type d -exec install -d -o carla -g carla /workspace/{} \;
EOF
for layer_manifest in "${layer_manifests[@]}"; do
  manifest_name="$(basename "${layer_manifest}")"
  cat >> "${generated_dockerfile}" <<EOF
RUN --mount=type=bind,target=/runtime,readonly \\
    --mount=type=bind,from=runtime-manifests,source=${manifest_name},target=/layer.list,readonly \\
    cd /runtime && tar --null --verbatim-files-from --files-from=/layer.list --owner=1000 --group=1000 -cf - | tar -xf - -C /workspace
EOF
done
awk 'found { print } /^# RUNTIME_LAYERS$/ { found = 1 }' \
  "${repo_root}/docker/carla-server.Dockerfile" >> "${generated_dockerfile}"

echo "Starting Docker BuildKit build with ${#layer_manifests[@]} runtime layers"
docker buildx build --load --progress=auto \
  --build-context runtime-manifests="${manifest_dir}" \
  --file "${generated_dockerfile}" \
  --tag "${image}" \
  "${runtime_root}"

echo "Built local image: ${image}"
echo
echo "Publish this image:"
echo "  docker login ghcr.io"
echo "  ./scripts/push_image.sh ${image}"
echo
echo "To deploy it remotely, set docker-compose.yml image: to ${image}"
echo "then run: docker compose pull && docker compose up -d --wait carla-server"
