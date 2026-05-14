{ pkgs, ... }:

{
  # 1. Prevent the modules from loading automatically
  boot.blacklistedKernelModules = [
    "esp4"
    "esp6"
    "rxrpc"
  ];

  # 2. Hard-block them even if something else tries to pull them in as a dependency
  # This maps the "install" command for these modules to /bin/false
  boot.extraModprobeConfig = ''
    install esp4 ${pkgs.coreutils}/bin/false
    install esp6 ${pkgs.coreutils}/bin/false
    install rxrpc ${pkgs.coreutils}/bin/false
  '';
}
