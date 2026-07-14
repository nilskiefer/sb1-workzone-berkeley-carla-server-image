# Run CarlaMayo on Savio

This is the working procedure for running CARLA and CarlaMayo on a Savio A40
node.

## Storage

| Location                                           | Use                                     | Persists? |
| -------------------------------------------------- | --------------------------------------- | --------- |
| `/global/home/users/$USER/carla-stack-permanent` | Source code                            | Yes       |
| `/global/scratch/users/$USER/carla-stack`        | CARLA image, `.venv`, logs, caches      | Temporary |
| CUDA Apptainer image                               | CUDA, Python, and`flash-attn` runtime | Temporary |

Your source code is in home. CARLA's large image, Python environment, and run
files are in scratch. The CUDA Apptainer image mounts the source directory from
home; it does not contain your only copy of the code.

## One-Time Mac Setup

Run this on the Mac. Do this once.

### Mac Terminal 1: Set Up SSH

Use exactly this SSH layout:

| Host alias     | Purpose                                 | Key                           |
| -------------- | --------------------------------------- | ----------------------------- |
| `savio-cert` | One-time bootstrap with the BRC cert    | `~/.ssh/ssh_certs/brc_cert` |
| `savio`      | Normal terminal and VS Code connections | `~/.ssh/savio_vscode`       |

Do not add `ControlMaster`, `ControlPath`, or `ControlPersist` to `savio`.
Those options can break VS Code's dynamic port forwarding.

```bash
git clone https://github.com/lbnl-science-it/lrc-scripts.git
cd lrc-scripts
./request_cert.sh -p brc
ssh-keygen -t ed25519 -f ~/.ssh/savio_vscode -C "$USER@$(hostname)-savio-vscode"
```

Add this to `~/.ssh/config`:

```sshconfig
Host savio-cert
    User nkiefer
    HostName hpc.brc.berkeley.edu
    IdentityFile ~/.ssh/ssh_certs/brc_cert
    IdentitiesOnly yes

Host savio
    User nkiefer
    HostName hpc.brc.berkeley.edu
    IdentityFile ~/.ssh/savio_vscode
    IdentitiesOnly yes
    AddKeysToAgent yes
    UseKeychain yes
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

Install the `savio` key using the `savio-cert` bootstrap login:

```bash
ssh-copy-id -i ~/.ssh/savio_vscode.pub savio-cert
ssh-add --apple-use-keychain ~/.ssh/savio_vscode
ssh -o ControlMaster=no -o ControlPath=none -o PreferredAuthentications=publickey -o PasswordAuthentication=no savio true
ssh savio
```

The `ControlMaster=no` and `PasswordAuthentication=no` command must exit
successfully before VS Code is expected to work. It verifies a fresh
public-key login without password auth or a reused SSH connection.

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
  --time=04:00:00 \
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

### Savio Login Node: Open Prepared Compute Terminal

Run this from a Savio login-node shell in each working terminal. It finds the
existing GPU allocation, connects to its compute node, initializes the runtime
variables, prepares the scratch directories, pulls missing runtime images, and
then opens an interactive compute-node shell:

```bash
nodes=$(squeue -h -u "$USER" -t RUNNING -o "%N|%P" \
  | awk -F'|' '$2 == "savio3_gpu" {print $1}' \
  | sort -u)
count=$(printf "%s\n" "$nodes" | sed "/^$/d" | wc -l | tr -d " ")
if [ "$count" -ne 1 ]; then
  echo "Expected exactly one running savio3_gpu node; found $count." >&2
  squeue -u "$USER"
  exit 1
fi
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

  if [ -f \"\$SIF\" ]; then
    echo \"CARLA image already exists\"
  else
    apptainer pull \"\$SIF\" \"\$SIF_ORAS\"
  fi

  if [ -f \"\$DEV_SIF\" ]; then
    echo \"CUDA development image already exists\"
  else
    apptainer pull \"\$DEV_SIF\" docker://nvidia/cuda:12.8.2-devel-ubuntu22.04
  fi

  apptainer exec \"\$SIF\" test -x /workspace/CarlaUE4.sh
  apptainer exec \"\$DEV_SIF\" /bin/bash -lc \"nvcc --version\"

  cd \"\$PROJECT\"
  cat > \"\$WORK/tmp/compute-bashrc\" <<'\''EOF'\''
export PS1='\''[compute:\h \W]\$ '\''
alias ll='\''ls -lh'\''
alias la='\''ls -lah'\''
EOF
  exec bash --rcfile \"\$WORK/tmp/compute-bashrc\" -i
"'
```

After publishing a new `0.9.16-sanramon` image, remove the old SIF before
running the prepared terminal block:

```bash
rm -f /global/scratch/users/$USER/carla-stack/containers/carla-sanramon.sif
```

Publish the Savio SIF directly to GHCR as an ORAS artifact. From a Linux
machine with Apptainer, build the SIF from the already-built Docker image:

```bash
./scripts/build_sif.sh \
  ghcr.io/nilskiefer/sb1-workzone-berkeley-carla-server-image:0.9.16-sanramon \
  carla-sanramon.sif
```

Log in to GHCR with a GitHub token that has `write:packages`, then push the SIF:

```bash
apptainer registry login --username YOUR_GITHUB_USER oras://ghcr.io
./scripts/push_sif.sh \
  carla-sanramon.sif \
  oras://ghcr.io/nilskiefer/sb1-workzone-berkeley-carla-server-image-sif:0.9.16-sanramon
```

If the SIF is already present, the prepared terminal block prints
`CARLA image already exists`. If it is missing, the prepared terminal pulls the
prebuilt SIF from `oras://ghcr.io/...-sif`. This avoids the slow `docker://`
layer extraction and SIF conversion on Savio. Treat `FATAL:`, a missing SIF, or
a failed validation command as a real failure.

### Compute Node Terminal 2: Run CARLA Server

Open a separate prepared compute-node terminal for CARLA. Run CARLA in the
foreground so the terminal is the server lifecycle:

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
```

Leave this terminal occupied by CARLA. Stop the server with `Ctrl-C`.

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
apptainer exec --nv \
  --bind "$PROJECT:$PROJECT" \
  --bind "$WORK:$WORK" \
  --env PROJECT="$PROJECT" \
  --env WORK="$WORK" \
  --env HF_HOME="$HF_HOME" \
  --env UV_CACHE_DIR="$UV_CACHE_DIR" \
  --env UV_PROJECT_ENVIRONMENT="$UV_PROJECT_ENVIRONMENT" \
  --env UV_LINK_MODE="$UV_LINK_MODE" \
  --env PS1='[carla-container \W]\$ ' \
  "$DEV_SIF" \
  /bin/bash --noprofile --norc -i
```

Run the rest of the CarlaMayo commands inside that container shell. Do not run
them in the host compute-node shell.

### Apptainer Container: Create or Update CarlaMayo Environment

This reuses the existing scratch venv. It creates the venv only if it does not
exist, then syncs missing or changed packages from the lockfile:

```bash
export CUDA_HOME=/usr/local/cuda
export PATH="$HOME/.local/bin:$CUDA_HOME/bin:$PATH"
cd "$PROJECT/CarlaMayo"
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
  --duration-sec 100 \
```

## End the Run

Stop CARLA with `Ctrl-C` in the CARLA server terminal. Exit any CarlaMayo
container shells, then exit the original `srun` allocation terminal. Source
code remains in home. The `.venv` and scratch files may be removed and are not
backed up.
