{ lib, config, inputs, ... }:
let
  cfg = config.ft.system.nixpkgsFailover;
in
{
  options.ft.system.nixpkgsFailover = {
    enable = lib.mkEnableOption "nixpkgs stable package failover overlay" // {
      description = "Installs a nixpkgs overlay that resolves packages listed in overridesFile from nixpkgs-stable instead of nixpkgs-unstable. The overrides list is rebuilt each rebuild session by the failover-switch just recipe.";
    };
    overridesFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to a newline-delimited list of top-level pkgs attribute names to resolve from nixpkgs-stable. Lines beginning with # are ignored. Set to null (default) to disable override resolution without disabling the module.";
      example = "../../var/stable-overrides.list";
    };
  };

  config = lib.mkIf cfg.enable {
    # nixpkgs.overlays is merged across modules by concatenation — lib.mkDefault
    # is intentionally omitted so this entry appends rather than competing on
    # priority with overlays set by other modules.
    nixpkgs.overlays = [
      (
        final: prev:
        let
          stablePkgs = inputs.nixpkgs-stable.legacyPackages.${prev.stdenv.hostPlatform.system};
          rawLines =
            if cfg.overridesFile != null && builtins.pathExists cfg.overridesFile then
              lib.splitString "\n" (builtins.readFile cfg.overridesFile)
            else
              [ ];
          overrideList = lib.filter (s: s != "" && !(lib.hasPrefix "#" s)) rawLines;
          overridePkg =
            name:
            if lib.elem name overrideList then stablePkgs.${name} or prev.${name} else prev.${name};
        in
        lib.genAttrs overrideList overridePkg
      )
    ];
  };
}
