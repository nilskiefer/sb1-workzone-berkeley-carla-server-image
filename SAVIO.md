# Run CarlaMayo on Savio

This is the working procedure for running CARLA and CarlaMayo on a Savio A40
node.

## Storage

| Location                                           | Use                                     | Persists? |
| -------------------------------------------------- | --------------------------------------- | --------- |
| `/global/home/users/$USER/carla-stack-permanent` | Source code                             | Yes       |
| `/global/scratch/users/$USER/carla-stack`        | CARLA SIF,`.venv`, logs, caches       | Temporary |
| CUDA Apptainer image                               | CUDA, Python, and`flash-attn` runtime | Temporary |

Your source code is in home. The CARLA SIF, Python environment, and run files
are in scratch. The CUDA Apptainer image mounts the source directory from home;
it does not contain your only copy of the code.

`Place_carla_Folder_in_here/carla` and the original CARLA ZIP are only build
inputs for creating a new Docker image on a Linux machine. They are not needed
to run the already-published SIF on Savio.

## One-Time Mac Setup

Run this on the Mac. Do this once.

### Mac Terminal 1: Set Up SSH

Use the BRC SSH certificate for both terminal and VS Code connections. The
certificate avoids entering the PIN and OTP for every connection and expires
after 12 hours.

Do not add `ControlMaster`, `ControlPath`, or `ControlPersist` to `savio`.
Those options can break VS Code's dynamic port forwarding.

Install the BRC certificate script and request a certificate:

```bash
if [ -d "$HOME/lrc-scripts/.git" ]; then
    cd "$HOME/lrc-scripts"
else
    git clone https://github.com/lbnl-science-it/lrc-scripts.git "$HOME/lrc-scripts"
    cd "$HOME/lrc-scripts"
fi
./request_cert.sh -p brc
```

Add `savio` to `~/.ssh/config`, replacing `YOUR_SAVIO_USERNAME` with your
Savio username:

```sshconfig
Host savio
    User YOUR_SAVIO_USERNAME
    HostName hpc.brc.berkeley.edu
    IdentityFile ~/.ssh/ssh_certs/brc_cert
    IdentitiesOnly yes
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

Check the certificate expiry and test the connection:

```bash
ssh-keygen -L -f ~/.ssh/ssh_certs/brc_cert-cert.pub
ssh savio
```

When the certificate expires, rerun the request command from
`$HOME/lrc-scripts` and test `ssh savio` again. Do not use `ssh-copy-id`; a
regular public key does not replace the BRC certificate authentication flow.

If VS Code reports `Address already in use`, `Could not request local forwarding`, or `ControlSocket ... already exists`, close all VS Code windows
connected to Savio and run this on the Mac:

```bash
ssh -O exit savio 2>/dev/null || true
find ~/.ssh -maxdepth 1 -name 'control-*' -delete
```

## Every Run

Follow these steps in order.

### Mac Terminal 1: Connect to the Login Node

Open a new Mac terminal and run:

```bash
ssh savio
```

The prompt should now look like:

```text
[nkiefer@ln001 ~]$
```

This is the login node. Do not run CARLA or CarlaMayo here.

### Savio Login Node: Check the Source Code

Run this on the login node. This is only needed the first time:

```bash
export PROJECT="$HOME/carla-stack-permanent"
mkdir -p "$PROJECT"

if [ -d "$PROJECT/CarlaMayo/.git" ]; then
  echo "CarlaMayo already cloned"
else
  test ! -e "$PROJECT/CarlaMayo"
  git clone https://github.berkeley.edu/nkiefer/CarlaMayo.git \
    "$PROJECT/CarlaMayo"
fi

if [ -d "$PROJECT/sb1-workzone-berkeley-carla-server-image/.git" ]; then
  echo "CARLA image repository already cloned"
else
  test ! -e "$PROJECT/sb1-workzone-berkeley-carla-server-image"
  git clone https://github.com/nilskiefer/sb1-workzone-berkeley-carla-server-image.git \
    "$PROJECT/sb1-workzone-berkeley-carla-server-image"
fi
```

For the Berkeley Enterprise GitHub prompt, enter your GitHub username and use
a personal access token as the password. Paste the token only at the password
prompt.

### Savio Login Node: Install Codex CLI Once

This installs the Node and Codex executables in `$WORK/tools/codex-cli`. The
Codex sign-in state remains in persistent `~/.codex`, so reinstalling the
executables after scratch cleanup does not require another sign-in. Run it on a
login node, not inside a GPU allocation. 

```bash
node_version=v24.18.0
node_dir="node-${node_version}-linux-x64"
work="/global/scratch/users/$USER/carla-stack"
install_root="$work/tools/codex-cli"
node_root="$install_root/$node_dir"
archive="$HOME/.local/$node_dir.tar.xz"
checksums="$HOME/.local/SHASUMS256.txt"
temporary_root="$install_root/.${node_dir}.$$"
path_line='export PATH="/global/scratch/users/$USER/carla-stack/tools/codex-cli/node-v24.18.0-linux-x64/bin:/global/scratch/users/$USER/carla-stack/tools/codex-cli/codex/bin:$PATH"'

mkdir -p "$install_root"

if [ ! -x "$node_root/bin/node" ]; then
  if [ ! -f "$archive" ]; then
    curl -fL --progress-bar -o "$archive" \
      "https://nodejs.org/dist/${node_version}/${node_dir}.tar.xz"
  fi

  if [ ! -f "$checksums" ]; then
    curl -fL --progress-bar -o "$checksums" \
      "https://nodejs.org/dist/${node_version}/SHASUMS256.txt"
  fi

  expected_sum="$(awk -v file="${node_dir}.tar.xz" '$2 == file { print $1 }' "$checksums")"
  actual_sum="$(sha256sum "$archive" | awk '{ print $1 }')"

  if [ -n "$expected_sum" ] && [ "$actual_sum" = "$expected_sum" ]; then
    if mkdir "$temporary_root" && \
        tar -xJvf "$archive" -C "$temporary_root" && \
        mv "$temporary_root/$node_dir" "$node_root"
    then
      rmdir "$temporary_root"
    else
      echo "Node extraction failed: $temporary_root" >&2
    fi
  else
    echo "Node checksum verification failed" >&2
  fi
fi

if [ -x "$node_root/bin/node" ]; then
  export PATH="$node_root/bin:$PATH"
  npm install --global --prefix "$install_root/codex" @openai/codex

  grep -qxF "$path_line" "$HOME/.bashrc" 2>/dev/null || \
    printf '\n%s\n' "$path_line" >> "$HOME/.bashrc"

  "$install_root/codex/bin/codex" --version
else
  echo "Codex was not installed because Node is unavailable" >&2
fi
```

Open a new Savio shell after this block, then run `codex` from the directory
you want it to work in. Codex stores its sign-in state in `~/.codex`, which is
in persistent home storage.

### Savio Login Node: Request the GPU Node

Run this on the login node:

```bash
srun \
  --account=fc_workzone \
  --partition=savio3_gpu \
  --qos=a40_gpu3_normal \
  --gres=gpu:A40:2 \
  --nodes=1 \
  --ntasks=1 \
  --cpus-per-task=16 \
  --time=08:00:00 \
  --exclude=n0215.savio3 \
  --pty bash -i
```

Wait. The prompt must change to a compute node, for example:

```text
[nkiefer@n0274 ~]$
```

Do not continue until the prompt contains `n....savio3`.

Verify the allocation:

```bash
hostname
echo "$SLURM_JOB_ID"
nvidia-smi -L
```

Keep this terminal open to hold the Slurm allocation. Use a second terminal for
the actual CARLA and CarlaMayo work.

If this terminal prints `CANCELLED ... DUE TO TIME LIMIT`, the allocation is
gone. Close any prepared compute terminals from that job and request a new GPU
node with `srun` before continuing.

### Savio Login Node: Open Prepared Compute Terminal

Run this from a Savio login-node shell in each working terminal. It finds the
existing GPU allocation, connects to its compute node, initializes the runtime
variables, prepares the scratch directories, and then opens an interactive
compute-node shell:

```bash
nodes=$(squeue -h -u "$USER" -t RUNNING -o "%N|%P" \
  | awk -F'|' '$2 == "savio3_gpu" {print $1}' \
  | sort -u)
count=$(printf "%s\n" "$nodes" | sed "/^$/d" | wc -l | tr -d " ")
if [ "$count" -ne 1 ]; then
  echo "Expected exactly one running savio3_gpu node; found $count." >&2
  squeue -u "$USER"
else
  node=$(printf "%s\n" "$nodes" | sed "/^$/d")
  echo "Connecting to $node"
  exec ssh -t "$node" 'bash -l -c "
  export WORK=\"/global/scratch/users/\$USER/carla-stack\"
  export PROJECT=\"\$HOME/carla-stack-permanent\"
  export SIF=\"\$WORK/containers/carla-sanramon.sif\"
  export SIF_ORAS=\"oras://ghcr.io/nilskiefer/sb1-workzone-berkeley-carla-server-image-sif:0.9.16-sanramon\"
  export DEV_SIF=\"\$WORK/containers/cuda-12.8.2-devel-ubuntu22.04.sif\"
  export HF_HOME=\"\$WORK/cache/huggingface\"
  export UV_CACHE_DIR=\"\$WORK/cache/uv\"
  export UV_PROJECT_ENVIRONMENT=\"\$WORK/envs/carlamayo\"
  export UV_LINK_MODE=hardlink
  export APPTAINER_CACHEDIR=\"\$WORK/cache/apptainer\"
  export APPTAINER_TMPDIR=\"\$WORK/tmp/apptainer\"

  mkdir -p \
    \"\$WORK/containers\" \
    \"\$WORK/cache/apptainer\" \
    \"\$WORK/cache/huggingface\" \
    \"\$WORK/cache/uv\" \
    \"\$WORK/envs\" \
    \"\$WORK/logs\" \
    \"\$WORK/outputs\" \
    \"\$WORK/tmp/apptainer\"

  cd \"\$PROJECT\"
  cat > \"\$WORK/tmp/compute-bashrc\" <<'\''EOF'\''
export PS1='\''[compute:\h \W]\$ '\''
alias ll='\''ls -lh'\''
alias la='\''ls -lah'\''
EOF
  exec bash --rcfile \"\$WORK/tmp/compute-bashrc\" -i
  "'
fi
```

### Compute Node Terminal 2: Run CARLA Server

Open a separate prepared compute-node terminal for CARLA. Run CARLA in the
foreground so the terminal is the server lifecycle. This block also ensures the
CARLA SIF exists before starting the server:

```bash
if [ -f "$SIF" ] && apptainer exec "$SIF" test -x /workspace/CarlaUE4.sh >/dev/null 2>&1; then
  echo "CARLA SIF already exists and is valid"
else
  rm -f "$SIF"
  tmp_sif="$SIF.tmp.$$"
  rm -f "$tmp_sif"
  if apptainer pull "$tmp_sif" "$SIF_ORAS" \
      && apptainer exec "$tmp_sif" test -x /workspace/CarlaUE4.sh; then
    mv "$tmp_sif" "$SIF"
  else
    echo "CARLA SIF pull failed: $SIF_ORAS" >&2
    rm -f "$tmp_sif"
  fi
fi

if [ ! -f "$SIF" ]; then
  echo "CARLA SIF is missing: $SIF" >&2
elif ! apptainer exec "$SIF" test -x /workspace/CarlaUE4.sh; then
  echo "CARLA SIF validation failed: $SIF" >&2
else
  mkdir -p \
    "$WORK/carla-runtime/Saved" \
    "$WORK/carla-runtime/Intermediate" \
    "$WORK/carla-runtime/home"

  apptainer exec \
    --nv \
    --bind "$WORK/carla-runtime/Saved:/workspace/CarlaUE4/Saved" \
    --bind "$WORK/carla-runtime/Intermediate:/workspace/CarlaUE4/Intermediate" \
    --home "$WORK/carla-runtime/home" \
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
      -quality-level=Epic
fi
```

Leave this terminal occupied by CARLA. Stop the server with `Ctrl-C`.

After publishing a new `0.9.16-sanramon` SIF, remove the old SIF before
starting CARLA:

```bash
rm -f "$SIF"
```

The CARLA server block pulls the prebuilt SIF from `oras://ghcr.io/...-sif` if
it is missing. It writes to a temporary file first, validates that file, and
only then moves it to `$SIF`. This avoids treating a failed partial download as
a usable image. Treat `FATAL:`, a missing SIF, or a failed validation command as
a real failure.

## VS Code

### VS Code: Open CarlaMayo

1. Install **Remote - SSH** in VS Code.
2. Run **Remote-SSH: Connect to Host...** and select `savio`.
3. Open `/global/home/users/$USER/carla-stack-permanent/CarlaMayo`.

Use VS Code on the login node only for editing source files in home. Do not run
CARLA, CarlaMayo, Python package installs, or Dev Containers on the login node.

### Compute Node Terminal 3: Enter CarlaMayo Container

Open another prepared compute-node terminal for CarlaMayo. Run this there:

```bash
if [ -f "$DEV_SIF" ]; then
  echo "CUDA development image already exists"
else
  apptainer pull "$DEV_SIF" docker://nvidia/cuda:12.8.2-devel-ubuntu22.04
fi

apptainer exec "$DEV_SIF" /bin/bash -lc "nvcc --version"

cat > "$WORK/tmp/carlamayo-bashrc" <<'EOF'
export CUDA_HOME=/usr/local/cuda
export PATH="$HOME/.local/bin:$CUDA_HOME/bin:$PATH"
export PS1='[carla-container \W]\$ '
cd "$PROJECT/CarlaMayo"
if [ -x "$UV_PROJECT_ENVIRONMENT/bin/activate" ]; then
  source "$UV_PROJECT_ENVIRONMENT/bin/activate"
fi
EOF

apptainer exec --nv \
  --bind "$PROJECT:$PROJECT" \
  --bind "$WORK:$WORK" \
  --env PROJECT="$PROJECT" \
  --env WORK="$WORK" \
  --env HF_HOME="$HF_HOME" \
  --env UV_CACHE_DIR="$UV_CACHE_DIR" \
  --env UV_PROJECT_ENVIRONMENT="$UV_PROJECT_ENVIRONMENT" \
  --env UV_LINK_MODE="$UV_LINK_MODE" \
  "$DEV_SIF" \
  /bin/bash --rcfile "$WORK/tmp/carlamayo-bashrc" -i
```

Run the rest of the CarlaMayo commands inside that container shell. Do not run
them in the host compute-node shell.

### Apptainer Container: Create or Update CarlaMayo Environment

This reuses the existing scratch venv. It creates the venv only if it does not
exist, then syncs missing or changed packages from the lockfile:

```bash
command -v uv
test -n "$UV_PROJECT_ENVIRONMENT"

if [ ! -x "$UV_PROJECT_ENVIRONMENT/bin/python" ]; then
  uv venv "$UV_PROJECT_ENVIRONMENT" --python 3.12
fi

source "$UV_PROJECT_ENVIRONMENT/bin/activate"
uv sync --locked --active --python-platform x86_64-manylinux_2_31
```

Authenticate for model downloads:

```bash
hf auth login
```

Check the GPU and CARLA connection:

```bash
python -c "import torch; print(torch.cuda.is_available()); print(torch.cuda.device_count())"
python -c "import carla; c=carla.Client('127.0.0.1', 2000); c.set_timeout(5); print(c.get_server_version())"
```

### Apptainer Container: Run CarlaMayo

Run CarlaMayo:

```bash
python -u carla_alpamayo_closed_loop.py \
  --controller-mode mpc \
  --route-conditioned \
  --route-trajectory carla_data/examples/SanRamon_highway_work_zone.json \
  --inference-interval-frames 10 \
  --initial-speed-kph 3.6 \
  --npc-vehicles 100 \
  --npc-walkers 0 \
  --duration-sec 100
```

## End the Run

Stop CARLA with `Ctrl-C` in the CARLA server terminal. Exit any CarlaMayo
container shells, then exit the original `srun` allocation terminal. Source
code remains in home. The `.venv` and scratch files may be removed and are not
backed up.
