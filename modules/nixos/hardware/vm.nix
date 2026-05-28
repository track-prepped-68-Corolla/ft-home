{ ... }:

{
  meta.description = "NixOS VM test variant settings for qemu-based virtual machine testing. Configures 8 GiB RAM, 6 cores, virtio display, SSH on port 2222, and Virtio NIC inside the vmVariant.";

  virtualisation.vmVariant = {
    virtualisation = {
      memorySize = 8192;
      cores = 6;
      graphics = true;

      qemu.options = [
        "-cpu host"
        "-vga virtio"
        "-display gtk,zoom-to-fit=false"
        # Forward host port 2222 to guest port 22
        "-net nic,model=virtio"
        "-net user,hostfwd=tcp::2222-:22"
        # OPTIONAL: YubiKey USB Passthrough
        # "-device usb-host,vendorid=0x1050,productid=0x0407"
      ];
    };
    services.openssh.enable = true;
    networking.firewall.allowedTCPPorts = [ 22 ];
    services.openssh.settings.PasswordAuthentication = false;
    boot.kernelParams = [ "video=Virtual-1:1920x1080@60" ];
  };
}
