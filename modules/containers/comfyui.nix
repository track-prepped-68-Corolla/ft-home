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
    echo "--- Base: Ubuntu 24.04 ---"

    # 1. Install System Dependencies (Ephemeral)
    # Since we are using a bare Ubuntu image now, we must install ROCm deps manually.
    apt-get update
    apt-get install -y git wget python3 python3-pip python3-venv \
                       libgl1 libglib2.0-0 software-properties-common gnupg2

    # 2. Add ROCm Repository (Required for drivers inside container)
    if [ ! -f /etc/apt/sources.list.d/amdgpu.list ]; then
        echo "Adding ROCm repositories..."
        wget -q -O - https://repo.radeon.com/rocm/rocm.gpg.key | apt-key add -
        echo 'deb [arch=amd64] https://repo.radeon.com/rocm/apt/6.3.1/ jammy main' | tee /etc/apt/sources.list.d/rocm.list
        apt-get update
    fi

    # Install basic HIP runtime (needed for the GPU to talk to the container)
    # We use --no-install-recommends to keep it small
    apt-get install -y --no-install-recommends rocm-hip-runtime-dev

    cd $WORK_DIR

    # 3. Clone ComfyUI (Persistent)
    if [ ! -d "$WORK_DIR/.git" ]; then
        echo "Cloning ComfyUI..."
        git clone https://github.com/comfyanonymous/ComfyUI .
    fi

    # 4. Python Environment (Persistent)
    if [ ! -d "$VENV_DIR" ]; then
        echo "Creating persistent Python virtual environment..."
        python3 -m venv $VENV_DIR
        source $VENV_DIR/bin/activate

        echo "Uninstalling conflicting torch packages..."
        pip uninstall torch torchvision torchaudio -y

        echo "Installing ROCm python libraries..."
        pip install --index-url https://d2awnip2yjpvqn.cloudfront.net/v2/gfx1151/ rocm[libraries,devel]

        # 5. Handle Wheels
        # The script attempts to download, but you likely need to place them manually in /var/lib/comfyui-rocm
        if ls *.whl 1> /dev/null 2>&1; then
            echo "Installing local wheels found in directory..."
            pip install ./*.whl
        else 
            echo "WARNING: No .whl files found! You must download the gfx1151 wheels manually."
            echo "Please download: torch, torchvision, torchaudio, flash_attn for cp312"
            echo "Place them in $dataDir on your host machine and restart."
            # We don't exit here, so you can check logs and fix it without crashing the loop
            sleep 10
        fi

        echo "Installing Requirements..."
        pip install -r requirements.txt
        
        # Linker fix
        echo /usr/local/lib/python3.12/dist-packages/_rocm_sdk_core/lib >> /etc/ld.so.conf
        ldconfig
    else
        source $VENV_DIR/bin/activate
    fi

    # 6. Launch
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
      # CHANGED: Using official Ubuntu 24.04 instead of the deleted "therock" image
      image = "ubuntu:24.04";
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
