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
        echo "--- Base: Ubuntu 22.04 (Jammy) + Pinning Fix ---"

        # 1. Base Dependencies
        apt-get update
        apt-get install -y wget git software-properties-common gnupg2

        # 2. Add Python 3.12 (Deadsnakes PPA)
        # Ubuntu 22.04 defaults to Py3.10, but we need 3.12 for your wheels.
        if ! command -v python3.12 &> /dev/null; then
            echo "Adding Python 3.12 PPA..."
            add-apt-repository -y ppa:deadsnakes/ppa
            apt-get update
        fi

        # 3. Add AMD ROCm Repo
        if [ ! -f /etc/apt/sources.list.d/rocm.list ]; then
            echo "Adding ROCm repositories..."
            mkdir -p /etc/apt/keyrings
            wget -q -O - https://repo.radeon.com/rocm/rocm.gpg.key | gpg --dearmor -o /etc/apt/keyrings/rocm.gpg
            echo 'deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com/rocm/apt/6.3.1/ jammy main' | tee /etc/apt/sources.list.d/rocm.list
            
            # --- CRITICAL FIX: PINNING ---
            # This tells apt: "Always prefer packages from repo.radeon.com, 
            # even if the system thinks it has a 'newer' version."
            echo "Pinning AMD Repository..."
            cat <<EOF > /etc/apt/preferences.d/rocm-pin
    Package: *
    Pin: origin repo.radeon.com
    Pin-Priority: 1001
    EOF
            apt-get update
        fi

        # 4. Install Drivers & Python
        # With pinning active, this will now succeed.
        apt-get install -y --no-install-recommends \
            rocm-hip-runtime-dev \
            libgl1 libglib2.0-0 \
            python3.12 python3.12-venv python3.12-dev python3.12-distutils

        cd $WORK_DIR

        # 5. Clone ComfyUI
        if [ ! -d "$WORK_DIR/.git" ]; then
            echo "Cloning ComfyUI..."
            git clone https://github.com/comfyanonymous/ComfyUI .
        fi

        # 6. Python Environment
        if [ ! -d "$VENV_DIR" ]; then
            echo "Creating persistent Python 3.12 virtual environment..."
            python3.12 -m venv $VENV_DIR
            source $VENV_DIR/bin/activate

            echo "Uninstalling conflicting torch packages..."
            pip install --upgrade pip
            pip uninstall torch torchvision torchaudio -y

            echo "Installing ROCm python libraries..."
            pip install --index-url https://d2awnip2yjpvqn.cloudfront.net/v2/gfx1151/ rocm[libraries,devel]

            # 7. Install Wheels
            if ls *.whl 1> /dev/null 2>&1; then
                echo "Installing local wheels found in directory..."
                pip install ./*.whl
            else 
                echo "WARNING: No .whl files found!"
                echo "Please ensure the 4 whl files are in $dataDir on the host."
                sleep 10
            fi

            echo "Installing Requirements..."
            pip install -r requirements.txt
            
            # Linker fix
            echo /usr/local/lib/python3.12/site-packages/_rocm_sdk_core/lib >> /etc/ld.so.conf
            ldconfig
        else
            source $VENV_DIR/bin/activate
        fi

        # 8. Launch
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
      image = "ubuntu:22.04";
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
