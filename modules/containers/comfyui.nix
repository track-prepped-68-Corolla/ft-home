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
    BACKUP_DIR="/tmp/comfy_backup"
    MANAGER_DIR="$WORK_DIR/custom_nodes/ComfyUI-Manager"

    echo "--- Starting ComfyUI ROCm (Strix Halo/gfx1151) ---"
    echo "--- Base: Ubuntu 24.04 (Noble) ---"

    # 1. Install System Dependencies
    apt-get update
    apt-get install -y git wget python3 python3-pip python3-venv \
                       libgl1 libglib2.0-0 \
                       libzstd1 libbz2-1.0 liblzma5 \
                       libsqlite3-0 libncurses6 libffi8 \
                       libsuitesparse-dev

    cd $WORK_DIR

    # 2. Smart Clone (ComfyUI Core)
    if [ ! -f "main.py" ]; then
        echo "ComfyUI not found. Checking for wheels..."
        if ls *.whl 1> /dev/null 2>&1; then
            echo "Backing up wheels..."
            mkdir -p $BACKUP_DIR
            mv *.whl $BACKUP_DIR/
        fi
        
        echo "Cloning ComfyUI..."
        rm -rf ./* .git
        git clone https://github.com/comfyanonymous/ComfyUI .

        if [ -d "$BACKUP_DIR" ]; then
            echo "Restoring wheels..."
            mv $BACKUP_DIR/*.whl .
            rm -rf $BACKUP_DIR
        fi
    fi

    # 2.5 Install ComfyUI Manager (Auto-Install)
    if [ ! -d "$MANAGER_DIR" ]; then
        echo "ComfyUI Manager not found. Installing..."
        git clone https://github.com/ltdrdata/ComfyUI-Manager.git "$MANAGER_DIR"
    else
        echo "Updating ComfyUI Manager..."
        cd "$MANAGER_DIR" && git pull && cd "$WORK_DIR"
    fi

    # 3. Python Environment Setup
    if [ ! -d "$VENV_DIR" ]; then
        echo "Creating persistent venv..."
        python3 -m venv $VENV_DIR
        source $VENV_DIR/bin/activate

        echo "Uninstalling conflicting torch packages..."
        pip install --upgrade pip
        pip uninstall torch torchvision torchaudio -y

        echo "Installing ROCm libraries via Pip..."
        pip install --index-url https://d2awnip2yjpvqn.cloudfront.net/v2/gfx1151/ rocm[libraries,devel]

        # Install Wheels
        if ls *.whl 1> /dev/null 2>&1; then
            echo "Installing local wheels..."
            pip install ./*.whl
        else 
            echo "WARNING: No .whl files found in $dataDir"
            sleep 5
        fi
    else
        source $VENV_DIR/bin/activate
    fi

    # 4. THE SYMLINK FIX (Always runs)
    ROCM_LIB_PATH=$(find "$VENV_DIR" -type d -name "lib" | grep "_rocm_sdk_core/lib" | head -n 1)

    if [ -n "$ROCM_LIB_PATH" ]; then
        link_lib() {
            SYS_NAME=$1  
            ROCM_NAME=$2 
            SYS_PATH=$(find /usr/lib -name "$SYS_NAME" | head -n 1)
            
            if [ -n "$SYS_PATH" ]; then
                if [ ! -e "$ROCM_LIB_PATH/$ROCM_NAME" ]; then
                    ln -s "$SYS_PATH" "$ROCM_LIB_PATH/$ROCM_NAME"
                fi
            fi
        }

        # Apply links
        link_lib "libzstd.so.1"    "librocm_sysdeps_zstd.so.1"
        link_lib "libbz2.so.1.0"   "librocm_sysdeps_bz2.so"
        link_lib "liblzma.so.5"    "librocm_sysdeps_lzma.so.5"
        link_lib "libsqlite3.so.0" "librocm_sysdeps_sqlite3.so"
        link_lib "libncurses.so.6" "librocm_sysdeps_ncurses.so"
        link_lib "libffi.so.8"     "librocm_sysdeps_ffi.so"

        export LD_LIBRARY_PATH="$ROCM_LIB_PATH:$LD_LIBRARY_PATH"
    fi

    # 5. REPAIR DEPENDENCIES
    echo "Checking for missing python packages..."
    pip install sqlalchemy spandrel opencv-python --no-warn-script-location

    # Check Manager requirements too
    if [ -f "$MANAGER_DIR/requirements.txt" ]; then
        echo "Installing ComfyUI Manager requirements..."
        pip install -r "$MANAGER_DIR/requirements.txt" --no-warn-script-location
    fi

    pip install -r requirements.txt --no-warn-script-location

    # 6. Launch
    echo "Launching ComfyUI..."
    export PYTORCH_TUNABLEOP_ENABLED=1 
    export MIOPEN_FIND_MODE=FAST 
    export ROCBLAS_USE_HIPBLASLT=0

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
