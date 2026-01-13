{
  config,
  pkgs,
  lib,
  ...
}:

with lib;

let
  cfg = config.ft.containers.comfyui;
  dataDir = "/var/lib/comfyui-rocm";

  startScript = pkgs.writeScript "comfyui-start.sh" ''
    #!/bin/bash
    set -e

    WORK_DIR="/opt/ComfyUI"
    VENV_DIR="$WORK_DIR/venv"

    echo "--- Starting ComfyUI ROCm (Strix Halo/gfx1151) ---"
    echo "--- Base: Debian Bookworm (12) + Python 3.12 ---"

    # 1. Install System Dependencies
    # 'python:3.12-bookworm' is very minimal. We need the basics.
    apt-get update
    apt-get install -y wget git software-properties-common gnupg2 libgl1 libglib2.0-0

    # 2. Add ROCm Repository
    # AMD doesn't have a "Debian" repo, so we use the Ubuntu 22.04 (jammy) one.
    # Debian 12 can run these binaries perfectly.
    if [ ! -f /etc/apt/sources.list.d/rocm.list ]; then
        echo "Adding ROCm repositories..."
        mkdir -p /etc/apt/keyrings
        wget -q -O - https://repo.radeon.com/rocm/rocm.gpg.key | gpg --dearmor -o /etc/apt/keyrings/rocm.gpg
        echo 'deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com/rocm/apt/6.3.1/ jammy main' | tee /etc/apt/sources.list.d/rocm.list
        apt-get update
    fi

    # 3. Install ROCm Runtime
    # Since Debian doesn't have its own rocm packages, this shouldn't conflict.
    apt-get install -y --no-install-recommends rocm-hip-runtime-dev

    cd $WORK_DIR

    # 4. Clone ComfyUI (Persistent)
    if [ ! -d "$WORK_DIR/.git" ]; then
        echo "Cloning ComfyUI..."
        git clone https://github.com/comfyanonymous/ComfyUI .
    fi

    # 5. Python Environment (Persistent)
    if [ ! -d "$VENV_DIR" ]; then
        echo "Creating persistent Python virtual environment..."
        # We are already in a Python 3.12 image, so 'python3' is 3.12.
        python3 -m venv $VENV_DIR
        source $VENV_DIR/bin/activate

        echo "Uninstalling conflicting torch packages..."
        pip install --upgrade pip
        pip uninstall torch torchvision torchaudio -y

        echo "Installing ROCm python libraries..."
        pip install --index-url https://d2awnip2yjpvqn.cloudfront.net/v2/gfx1151/ rocm[libraries,devel]

        # 6. Install Wheels
        if ls *.whl 1> /dev/null 2>&1; then
            echo "Installing local wheels found in directory..."
            pip install ./*.whl
        else 
            echo "WARNING: No .whl files found in $WORK_DIR!"
            echo "You must download the 4 whl files manually to $dataDir on the host."
            sleep 10
        fi

        echo "Installing Requirements..."
        pip install -r requirements.txt
        
        # Linker fix
        # Note: In the python docker image, site-packages is usually the standard path
        echo /usr/local/lib/python3.12/site-packages/_rocm_sdk_core/lib >> /etc/ld.so.conf
        ldconfig
    else
        source $VENV_DIR/bin/activate
    fi

    # 7. Launch
    echo "Launching ComfyUI..."
    export PYTORCH_TUNABLEOP_ENABLED=1 
    export MIOPEN_FIND_MODE=FAST 
    export ROCBLAS_USE_HIPBLASLT=1

    python3 main.py --listen 0.0.0.0 --use-flash-attention
  '';

in
{
  options.ft.containers.comfyui = {
    enable = mkEnableOption "ComfyUI Container for Strix Halo (gfx1151)";
    port = mkOption {
      type = types.port;
      default = 8188;
    };
  };

  config = mkIf cfg.enable {
    virtualisation.oci-containers.backend = "podman";
    virtualisation.podman.enable = true;
    networking.firewall.allowedTCPPorts = [ cfg.port ];

    systemd.tmpfiles.rules = [
      "d ${dataDir} 0775 root users -"
    ];

    virtualisation.oci-containers.containers.comfyui-rocm = {
      # CHANGED: Using Official Python 3.12 image (Built on Debian 12 Bookworm)
      image = "python:3.12-bookworm";
      autoStart = true;
      ports = [ "${toString cfg.port}:8188" ];
      volumes = [
        "${dataDir}:/opt/ComfyUI"
        "${startScript}:/start.sh"
      ];
      cmd = [
        "/bin/bash"
        "/start.sh"
      ];
      extraOptions = [
        "--device=/dev/kfd"
        "--device=/dev/dri"
        "--group-add=video"
        "--cap-add=SYS_PTRACE"
        "--security-opt=seccomp=unconfined"
        "--ipc=host"
      ];
    };
  };
}
