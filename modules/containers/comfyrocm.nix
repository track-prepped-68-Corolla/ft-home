{

  config,

  pkgs,

  lib,

  ...

}:

let

  cfg = config.modules.containers.comfyrocm;

  # FIX: Use the 'latest' tag.

  # In 2026, this points to ROCm 7.x which natively supports gfx1151 (Strix Halo).

  baseImage = "docker.io/rocm/pytorch:latest";

  dataDir = "/var/lib/comfyui";

in

{

  options.modules.containers.comfyrocm = {

    enable = lib.mkOption {

      type = lib.types.bool;

      default = false;

      description = "Enable the native Strix Halo (gfx1151) ComfyUI container.";

    };

  };

  config = lib.mkIf cfg.enable {

    # 1. Kernel Optimization

    # Strix Halo benefits from IOMMU passthrough for unified memory access.

    boot.kernelParams = [ "iommu=pt" ];

    networking.firewall.allowedTCPPorts = [ 8188 ];

    virtualisation.oci-containers.containers."comfyui-native" = {

      image = baseImage;

      autoStart = true;

      ports = [ "8188:8188" ];

      volumes = [

        "${dataDir}:/workspace"

      ];

      environment = {

        # --- NATIVE STRIX HALO CONFIGURATION ---

        # Enables System DMA for faster APU memory transfers

        "HSA_ENABLE_SDMA" = "1";

        # Ensures PyTorch sees the APU

        "HIP_VISIBLE_DEVICES" = "0";

        # Standard ComfyUI Args

        "CLI_ARGS" = "--listen 0.0.0.0 --port 8188";

        # Optional: If 'latest' somehow grabs an older ROCm (e.g. 6.2),

        # uncomment this line to force Strix Halo to run as a 7900 XTX.

        # But 'latest' should support gfx1151 natively now.

        # "HSA_OVERRIDE_GFX_VERSION" = "11.0.0";

      };

      # The container is raw PyTorch, so we must bootstrap ComfyUI

      entrypoint = "/bin/bash";

      cmd = [
        "-c"
        ''
          # 1. Enter the persistent workspace
          cd /workspace

          # 2. Source the existing virtual environment in the ROCm image
          # This provides access to pip and the correct torch version
          source /opt/venv/bin/activate

          # 3. Install ComfyUI if missing
          if [ ! -d ".git" ]; then
            echo "--- Bootstrapping ComfyUI ---"
            git clone https://github.com/comfyanonymous/ComfyUI.git .
          fi

          # 4. Install critical Manager dependencies
          # We manually install 'GitPython' because the Manager is failing without it
          echo "--- Fixing Dependencies ---"
          pip install --no-cache-dir -r requirements.txt
          pip install --no-cache-dir gitpython

          # 5. Start ComfyUI using the venv's python
          echo "--- Starting ComfyUI on Strix Halo ---"
          python main.py --listen 0.0.0.0 --port 8188
        ''
      ];

      extraOptions = [

        "--device=/dev/kfd"

        "--device=/dev/dri"

        "--group-add=video"

        "--group-add=render"

        "--ipc=host"

        "--security-opt=seccomp=unconfined"

        "--cap-add=SYS_PTRACE"

      ];

    };

    systemd.tmpfiles.rules = [

      "d ${dataDir} 0775 root root -"

    ];

  };

}
