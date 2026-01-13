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
    echo "--- Base: Python 3.12 (Debian Bookworm) ---"

    # 1. Minimal System Dependencies
    # We DO NOT install rocm via apt. We rely on the pip packages below.
    # We only need git (for cloning) and GL libs (for image processing).
    apt-get update
    apt-get install -y git libgl1 libglib2.0-0

    cd $WORK_DIR

    # 2. Clone ComfyUI
    if [ ! -d "$WORK_DIR/.git" ]; then
        echo "Cloning ComfyUI..."
        git clone https://github.com/comfyanonymous/ComfyUI .
    fi

    # 3. Python Environment
    if [ ! -d "$VENV_DIR" ]; then
        echo "Creating persistent venv..."
        python3 -m venv $VENV_DIR
        source $VENV_DIR/bin/activate

        echo "Uninstalling conflicting torch packages..."
        pip install --upgrade pip
        pip uninstall torch torchvision torchaudio -y

        echo "Installing ROCm libraries via Pip..."
        # This installs the runtime into the venv, avoiding the apt crash
        pip install --index-url https://d2awnip2yjpvqn.cloudfront.net/v2/gfx1151/ rocm[libraries,devel]

        # 4. Install Wheels
        # Make sure your manually downloaded wheels are in /var/lib/comfyui-rocm
        if ls *.whl 1> /dev/null 2>&1; then
            echo "Installing local wheels..."
            pip install ./*.whl
        else 
            echo "WARNING: No .whl files found!"
            echo "Please place the 4 Strix Halo wheels in $dataDir"
            sleep 10
        fi

        echo "Installing Requirements..."
        pip install -r requirements.txt
        
        # 5. Linker Fix
        # This points the OS to the ROCm libs we just installed via pip
        # Note: In 'python:3.12' image, site-packages is the standard path
        ROCM_LIB_PATH="$VENV_DIR/lib/python3.12/site-packages/_rocm_sdk_core/lib"
        echo "Adding $ROCM_LIB_PATH to ld.so.conf"
        echo "$ROCM_LIB_PATH" >> /etc/ld.so.conf
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
      # Official Python image = No PPA needed, no apt conflicts
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
