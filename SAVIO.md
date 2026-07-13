# CARLA and CarlaMayo on Berkeley Savio

This runbook sets up and runs the CARLA server image and CarlaMayo on a Savio
A40 node. Commands are grouped by where they run: local Mac, login node, or
allocated compute node.

## Storage

Use the home directory for small user-specific files, including SSH configuration,
credentials, and the VS Code server:

```text
/global/home/users/nkiefer
```

Keep source code in a permanent home-directory workspace:

```text
/global/home/users/nkiefer/carla-stack-permanent/
    CarlaMayo/
    sb1-workzone-berkeley-carla-server-image/
```

Use scratch only for large or temporary runtime files:

```text
/global/scratch/users/nkiefer/carla-stack/
    containers/
        carla-sanramon.sif
    envs/
        carlamayo/
        carla2real/
    cache/
        apptainer/
        huggingface/
        uv/
    data/
    outputs/
    logs/
    tmp/
```

Scratch is temporary and is not backed up. Keep source code and anything that
must survive cleanup in home or project storage.

## Connect

On the local Mac, request a Berkeley SSH certificate:

```bash
git clone https://github.com/lbnl-science-it/lrc-scripts.git
cd lrc-scripts
./request_cert.sh
```

The generated certificate is stored at:

```text
/Users/nils/.ssh/ssh_certs/brc_cert
```

Connect to the login node:

```bash
ssh \
  -i /Users/nils/.ssh/ssh_certs/brc_cert \
  -l nkiefer \
  hpc.brc.berkeley.edu
```

## Clone the Repositories

Run this on the Savio login node. The repositories are small and belong in
home, not scratch:

```bash
export PROJECT="$HOME/carla-stack-permanent"
mkdir -p "$PROJECT"

if [ -d "$PROJECT/CarlaMayo/.git" ]; then
  echo "CarlaMayo already exists: $PROJECT/CarlaMayo"
else
  test ! -e "$PROJECT/CarlaMayo"
  git clone https://github.berkeley.edu/nkiefer/CarlaMayo.git \
    "$PROJECT/CarlaMayo"
fi

if [ -d "$PROJECT/sb1-workzone-berkeley-carla-server-image/.git" ]; then
  echo "CARLA image repository already exists: $PROJECT/sb1-workzone-berkeley-carla-server-image"
else
  test ! -e "$PROJECT/sb1-workzone-berkeley-carla-server-image"
  git clone https://github.com/nilskiefer/sb1-workzone-berkeley-carla-server-image.git \
    "$PROJECT/sb1-workzone-berkeley-carla-server-image"
fi
```

The Berkeley Enterprise GitHub clone prompts for a username and password. Use
your GitHub username and a GitHub personal access token as the password. Paste
the token only at the `Password` prompt; do not enter it as a shell command.
The public image repository does not require authentication.

Verify the persistent checkout before requesting a compute node:

```bash
test -f "$PROJECT/CarlaMayo/carla_alpamayo_closed_loop.py" \
  && echo "CarlaMayo checkout verified"
test -f "$PROJECT/sb1-workzone-berkeley-carla-server-image/README.md" \
  && echo "CARLA image repository checkout verified"
```

If either destination already exists, do not run `git clone` again. The
`destination path already exists and is not an empty directory` message means
that repository is already cloned. Verify it with the two `test` commands
above and continue.

## Request Two A40 GPUs

Run this from the login node:

```bash
srun \
  --account=fc_workzone \
  --partition=savio3_gpu \
  --qos=a40_gpu3_normal \
  --gres=gpu:A40:2 \
  --nodes=1 \
  --ntasks=1 \
  --cpus-per-task=16 \
  --time=04:00:00 \
  --exclude=n0215.savio3 \
  --pty bash -i
```

For one A40 instead, use:

```bash
srun \
  --account=fc_workzone \
  --partition=savio3_gpu \
  --qos=a40_gpu3_normal \
  --gres=gpu:A40:1 \
  --nodes=1 \
  --ntasks=1 \
  --cpus-per-task=8 \
  --time=04:00:00 \
  --exclude=n0215.savio3 \
  --pty bash -i
```

Keep the terminal open for the lifetime of the allocation.

After Slurm assigns a node, the prompt changes from the login node to a compute
node such as `nkiefer@n0216`

Verify the allocation:

```bash
hostname
echo "$SLURM_JOB_ID"
echo "$CUDA_VISIBLE_DEVICES"
nvidia-smi -L
nvidia-smi
```

```bash
squeue -j "$SLURM_JOB_ID"
squeue -u "$USER"
```

## Reconnect to an Existing Allocation

You can use a new local terminal without requesting another node. First SSH
to the login node as usual, then find the running job:

```bash
squeue -u "$USER"
```

Use the node shown in the `NODELIST` column. The original terminal and its
running processes remain active. If the job is no longer listed as `R`, it has
ended and cannot be re-entered.

After reconnecting, restore the environment variables for that shell:

```bash
export WORK="/global/scratch/users/$USER/carla-stack"
export PROJECT="$HOME/carla-stack-permanent"
export SIF="$WORK/containers/carla-sanramon.sif"
export DEV_SIF="$WORK/containers/cuda-12.8.2-devel-ubuntu22.04.sif"
export APPTAINER_CACHEDIR="$WORK/cache/apptainer"
export APPTAINER_TMPDIR="$WORK/tmp/apptainer"
export HF_HOME="$WORK/cache/huggingface"
export UV_CACHE_DIR="$WORK/cache/uv"
cd "$PROJECT/CarlaMayo"
```

Only source the Python environment after the setup section has completed:

```bash
source "$WORK/envs/carlamayo/bin/activate"
```

Do not run the GPU `srun` request again when reconnecting; that would request a
second allocation. You can also simply keep using the original terminal.

If you are already at a Savio login-node prompt such as `ln002`, connect to the
existing node directly with one command:

```bash
nodes=$(squeue -h -u "$USER" -t RUNNING -o "%N|%P" | awk -F'|' '$2 == "savio3_gpu" {print $1}' | sort -u); count=$(printf "%s\n" "$nodes" | sed "/^$/d" | wc -l | tr -d " "); if [ "$count" -ne 1 ]; then echo "Expected exactly one running savio3_gpu node; found $count." >&2; squeue -u "$USER"; exit 1; fi; node=$(printf "%s\n" "$nodes" | sed "/^$/d"); echo "Connecting to $node"; exec ssh "$node"
```

If the prompt changes to `>` and does not execute, press `Ctrl-C`. That means
the shell received an unmatched quote or an unfinished line. Paste the single
line above again; it has no trailing quote.

This connects directly to the node assigned to exactly one running A40
allocation. It does not create another Slurm job step.

## Set Up the Workspace

The repositories are in `$PROJECT` on home. Scratch is only for the CARLA
container, Python environment, caches, logs, and run outputs.

Create the temporary runtime directories:

```bash
mkdir -p "/global/scratch/users/$USER/carla-stack"
```

```bash
export WORK="/global/scratch/users/$USER/carla-stack"
export PROJECT="$HOME/carla-stack-permanent"
export SIF="$WORK/containers/carla-sanramon.sif"
export APPTAINER_CACHEDIR="$WORK/cache/apptainer"
export APPTAINER_TMPDIR="$WORK/tmp/apptainer"
export HF_HOME="$WORK/cache/huggingface"
export UV_CACHE_DIR="$WORK/cache/uv"
```

Create the runtime subdirectories and move into scratch. The prompt should
then show the scratch path:

```bash
mkdir -p \
  "$WORK/containers" \
  "$WORK/envs" \
  "$WORK/cache/apptainer" \
  "$WORK/cache/huggingface" \
  "$WORK/cache/uv" \
  "$WORK/data" \
  "$WORK/outputs" \
  "$WORK/logs" \
  "$WORK/tmp/apptainer"

cd "$WORK"
pwd
```

Pull the published CARLA image as a local SIF file:

```bash
if [ -f "$SIF" ]; then
  echo "CARLA image already exists: $SIF"
else
  apptainer pull "$SIF" \
    docker://ghcr.io/nilskiefer/sb1-workzone-berkeley-carla-server-image:0.9.16-sanramon
fi
```

```bash
ls -lh "$SIF"
```

Pull a CUDA development image for building `flash-attn`. The CARLA image is a
runtime image and does not contain `nvcc`.

```bash
if [ -f "$DEV_SIF" ]; then
  echo "CUDA development image already exists: $DEV_SIF"
else
  apptainer pull "$DEV_SIF" \
    docker://nvidia/cuda:12.8.2-devel-ubuntu22.04
fi

apptainer exec "$DEV_SIF" nvcc --version
```

Set up the Python environment inside the CUDA development image. The Savio
host has glibc 2.28, while the CARLA 0.9.16 Python wheel requires glibc 2.31.
The project installs the matching wheel from PyPI inside the CUDA image.

```bash
test -f "$PROJECT/CarlaMayo/carla_alpamayo_closed_loop.py" \
  && echo "CarlaMayo controller verified"

command -v uv >/dev/null 2>&1 || {
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
}

if [ -d "$WORK/envs/carlamayo" ] && [ ! -x "$WORK/envs/carlamayo/bin/python" ]; then
  mv "$WORK/envs/carlamayo" "$WORK/envs/carlamayo-failed"
fi

apptainer exec --nv \
  --bind "$PROJECT:$PROJECT" \
  --bind "$WORK:$WORK" \
  --env PROJECT="$PROJECT" \
  --env WORK="$WORK" \
  "$DEV_SIF" \
  bash -lc '
    export PATH="$HOME/.local/bin:$PATH"
    export CUDA_HOME=/usr/local/cuda
    export PATH="$CUDA_HOME/bin:$PATH"
    cd "$PROJECT/CarlaMayo"
    uv venv "$WORK/envs/carlamayo" --python 3.12
    UV_PROJECT_ENVIRONMENT="$WORK/envs/carlamayo" uv sync \
      --locked \
      --active \
      --python-platform x86_64-manylinux_2_31
  '
```

Authenticate for Alpamayo model downloads after the environment is installed:

```bash
apptainer exec --nv \
  --bind "$PROJECT:$PROJECT" \
  --bind "$WORK:$WORK" \
  --env PROJECT="$PROJECT" \
  --env WORK="$WORK" \
  "$DEV_SIF" \
  bash -lc '
    export PATH="$HOME/.local/bin:$PATH"
    source "$WORK/envs/carlamayo/bin/activate"
    hf auth login
  '
```

Follow the Hugging Face model access requirements for
`nvidia/Alpamayo-1.5-10B` when prompted.

## Start CARLA

Verify the CARLA launcher in the Apptainer image:

```bash
apptainer exec "$SIF" test -x /workspace/CarlaUE4.sh
```

Start CARLA:

```bash
apptainer exec \
  --nv \
  --env OMP_PROC_BIND=FALSE \
  --env OMP_NUM_THREADS="$SLURM_CPUS_PER_TASK" \
  --pwd /workspace \
  "$SIF" \
  ./CarlaUE4.sh \
    -RenderOffScreen \
    -nosound \
    -stdout \
    -FullStdOutLogOutput \
    -carla-rpc-port=2000 \
    -quality-level=Epic \
  > "$WORK/logs/carla-${SLURM_JOB_ID}.log" 2>&1 &
export CARLA_PID=$!
echo "CARLA PID: $CARLA_PID"
```

Check that CARLA is ready:

```bash
sleep 30
ps -p "$CARLA_PID"
bash -c '</dev/tcp/127.0.0.1/2000' \
  && echo "CARLA is ready" \
  || echo "CARLA is not ready"
tail -n 50 "$WORK/logs/carla-${SLURM_JOB_ID}.log"
nvidia-smi
```

CARLA runs through Apptainer on Savio. Do not use Docker commands on the
compute node.

## Run CarlaMayo

Run CarlaMayo inside the CUDA development image used to install its environment:

```bash
apptainer exec --nv \
  --bind "$PROJECT:$PROJECT" \
  --bind "$WORK:$WORK" \
  --env PROJECT="$PROJECT" \
  --env WORK="$WORK" \
  "$DEV_SIF" \
  bash -lc '
    export PATH="$HOME/.local/bin:$PATH"
    export CUDA_HOME=/usr/local/cuda
    export PATH="$CUDA_HOME/bin:$PATH"
    source "$WORK/envs/carlamayo/bin/activate"
    cd "$PROJECT/CarlaMayo"
    which python
    python --version
    python -c "
import torch
print(\"CUDA available:\", torch.cuda.is_available())
print(\"GPU count:\", torch.cuda.device_count())
"
  '
```

```bash
apptainer exec --nv \
  --bind "$PROJECT:$PROJECT" \
  --bind "$WORK:$WORK" \
  --env PROJECT="$PROJECT" \
  --env WORK="$WORK" \
  "$DEV_SIF" \
  bash -lc '
    export PATH="$HOME/.local/bin:$PATH"
    export CUDA_HOME=/usr/local/cuda
    export PATH="$CUDA_HOME/bin:$PATH"
    source "$WORK/envs/carlamayo/bin/activate"
    cd "$PROJECT/CarlaMayo"
    python -u carla_alpamayo_closed_loop.py \
      --controller-mode mpc \
      --route-conditioned \
      --route-trajectory carla_data/examples/SanRamon_highway_work_zone.json \
      --inference-interval-frames 10 \
      --initial-speed-kph 3.6 \
      --npc-vehicles 100 \
      --npc-walkers 0 \
      --duration-sec 100 \
      --quantization
  '
```

## Monitor

```bash
watch -n 1 nvidia-smi
```

```bash
sinfo -N \
  -p savio3_gpu \
  -O NodeList:20,StateCompact:10,Gres:32,GresUsed:32 \
  | grep -E 'NODELIST|A40'
```

`idle` nodes are unused. `mix` nodes are partially allocated and may still have
an available GPU. `alloc`, `down`, and `drain` nodes may not be available.

## Connect VS Code

Add the login node and the allocated compute node to the local SSH config:

```sshconfig
Host savio
    User nkiefer
    HostName hpc.brc.berkeley.edu
    IdentityFile /Users/nils/.ssh/ssh_certs/brc_cert
    IdentitiesOnly yes

Host savio-compute
    User nkiefer
    HostName n0275.savio3
    ProxyJump savio
    StrictHostKeyChecking no
```

Update `HostName` for `savio-compute` whenever Slurm assigns a different node:

```bash
hostname
```

Then open this directory through VS Code Remote SSH:

```text
/global/home/users/nkiefer/carla-stack-permanent/CarlaMayo
```

## End the Session

```bash
kill "$CARLA_PID"
wait "$CARLA_PID" 2>/dev/null
exit
```

The interactive allocation ends when the shell exits. Source code under home
remains available. Scratch files are temporary and are not backed up, so copy
important model outputs to home or project storage before ending the session.
