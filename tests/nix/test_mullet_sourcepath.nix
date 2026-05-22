# Nix evaluation tests for the mullet NixOS module sourcePath option.
#
# These tests verify that:
#   1. ft.mullet.sourcePath is a configurable option (not hardcoded)
#   2. The module reads packages from the given sourcePath
#   3. An empty / missing file produces an empty package list
#   4. A non-empty file produces packages in environment.systemPackages
#   5. The strix machine wires the correct relative path
#
# Run with:
#   nix eval --file tests/nix/test_mullet_sourcepath.nix
#
# All expressions should evaluate to `true`.  A derivation-based runner can
# also be wired up via `nix-build tests/nix/test_mullet_sourcepath.nix`.

let
  # Bring in nixpkgs for `lib` and a minimal package set used by the module.
  nixpkgs = builtins.getFlake "nixpkgs";
  pkgs = nixpkgs.legacyPackages.x86_64-linux;
  lib = nixpkgs.lib;

  # ---------------------------------------------------------------------------
  # Helper: evaluate the mullet module under a given configuration
  # ---------------------------------------------------------------------------
  evalMullet =
    { enable ? true, sourcePath ? null, extraContent ? "" }:
    let
      # Write a temporary mullet.txt file in the Nix store for testing
      fakeFile =
        if sourcePath != null then
          sourcePath
        else
          pkgs.writeText "mullet-test.txt" extraContent;
    in
    lib.evalModules {
      modules = [
        # The module under test
        ../../modules/nixos/apps/mullet.nix
        # Minimal configuration
        {
          ft.mullet.enable = enable;
          ft.mullet.sourcePath = fakeFile;
        }
      ];
      specialArgs = { inherit pkgs lib; };
    };

  # ---------------------------------------------------------------------------
  # Test 1 — sourcePath option exists and is of type path
  # ---------------------------------------------------------------------------
  test_sourcePath_option_type =
    let
      result = evalMullet { };
      optionType = result.options.ft.mullet.sourcePath.type.name;
    in
    optionType == "path";

  # ---------------------------------------------------------------------------
  # Test 2 — empty mullet.txt produces no system packages
  # ---------------------------------------------------------------------------
  test_empty_file_no_packages =
    let
      result = evalMullet { extraContent = ""; };
    in
    result.config.environment.systemPackages == [ ];

  # ---------------------------------------------------------------------------
  # Test 3 — file with only newlines produces no packages (blank line filtering)
  # ---------------------------------------------------------------------------
  test_blank_lines_filtered =
    let
      result = evalMullet { extraContent = "\n\n\n"; };
    in
    result.config.environment.systemPackages == [ ];

  # ---------------------------------------------------------------------------
  # Test 4 — file with a valid package name results in a non-empty package list
  # ---------------------------------------------------------------------------
  test_valid_package_resolves =
    let
      result = evalMullet { extraContent = "hello\n"; };
      packages = result.config.environment.systemPackages;
    in
    builtins.length packages == 1;

  # ---------------------------------------------------------------------------
  # Test 5 — invalid/typo package name is silently dropped (null-filtered)
  # ---------------------------------------------------------------------------
  test_invalid_package_dropped =
    let
      result = evalMullet { extraContent = "__this_pkg_does_not_exist_xyz__\n"; };
      packages = result.config.environment.systemPackages;
    in
    packages == [ ];

  # ---------------------------------------------------------------------------
  # Test 6 — multiple packages resolve correctly
  # ---------------------------------------------------------------------------
  test_multiple_packages =
    let
      result = evalMullet { extraContent = "hello\ncowsay\n"; };
      packages = result.config.environment.systemPackages;
    in
    builtins.length packages == 2;

  # ---------------------------------------------------------------------------
  # Test 7 — module is a no-op when ft.mullet.enable = false
  # ---------------------------------------------------------------------------
  test_disabled_no_packages =
    let
      result = evalMullet {
        enable = false;
        extraContent = "hello\n";
      };
      packages = result.config.environment.systemPackages;
    in
    packages == [ ];

  # ---------------------------------------------------------------------------
  # Test 8 — default sourcePath is relative to the module directory (./mullet.txt)
  # ---------------------------------------------------------------------------
  test_default_sourcePath_is_module_relative =
    let
      result = lib.evalModules {
        modules = [
          ../../modules/nixos/apps/mullet.nix
          { ft.mullet.enable = true; }
        ];
        specialArgs = { inherit pkgs lib; };
      };
      defaultPath = result.options.ft.mullet.sourcePath.default;
    in
    # The default should be a path value (Nix path type, not a string)
    builtins.typeOf defaultPath == "path";

  # ---------------------------------------------------------------------------
  # Test 9 — nested attribute syntax (e.g. "vimPlugins.LazyVim") is supported
  # ---------------------------------------------------------------------------
  test_nested_attr_resolution =
    let
      # Use a real nested package that exists in nixpkgs
      result = evalMullet { extraContent = "python3Packages.pip\n"; };
      packages = result.config.environment.systemPackages;
    in
    builtins.length packages == 1;

  # ---------------------------------------------------------------------------
  # Test 10 — strix default.nix ft.mullet sourcePath points to the renamed file
  # ---------------------------------------------------------------------------
  test_strix_sourcePath_points_to_renamed_file =
    let
      strixContent = builtins.readFile ../../machines/strix/default.nix;
    in
    # The strix config must contain ft.mullet sourcePath pointing at users/joe/var/mullet.txt
    builtins.match ".*sourcePath = \\.\\./\\.\\./users/joe/var/mullet\\.txt.*" strixContent != null;

  # ---------------------------------------------------------------------------
  # Test 11 — mullet.txt exists at the new path (file system check)
  # ---------------------------------------------------------------------------
  test_mullet_txt_exists_at_new_path =
    builtins.pathExists ../../users/joe/var/mullet.txt;

  # ---------------------------------------------------------------------------
  # Test 12 — old mullet.txt path does NOT exist (file was renamed, not copied)
  # ---------------------------------------------------------------------------
  test_old_mullet_txt_path_removed =
    !(builtins.pathExists ../../modules/nixos/apps/mullet.txt);

  # ---------------------------------------------------------------------------
  # Test 13 — mullet.txt contains at least one package
  # ---------------------------------------------------------------------------
  test_mullet_txt_non_empty =
    let
      content = builtins.readFile ../../users/joe/var/mullet.txt;
      lines = lib.splitString "\n" content;
      nonEmpty = builtins.filter (l: l != "") lines;
    in
    builtins.length nonEmpty > 0;

  # ---------------------------------------------------------------------------
  # Aggregate all tests into a derivation so `nix-build` can run them
  # ---------------------------------------------------------------------------
  allTests = {
    inherit
      test_sourcePath_option_type
      test_empty_file_no_packages
      test_blank_lines_filtered
      test_valid_package_resolves
      test_invalid_package_dropped
      test_multiple_packages
      test_disabled_no_packages
      test_default_sourcePath_is_module_relative
      test_nested_attr_resolution
      test_strix_sourcePath_points_to_renamed_file
      test_mullet_txt_exists_at_new_path
      test_old_mullet_txt_path_removed
      test_mullet_txt_non_empty
      ;
  };

  failingTests = builtins.filter (name: !allTests.${name}) (builtins.attrNames allTests);

in
pkgs.runCommand "mullet-sourcepath-tests"
  { }
  ''
    ${lib.optionalString (failingTests != [ ]) ''
      echo "FAILING TESTS:"
      ${lib.concatMapStringsSep "\n" (t: ''echo "  - ${t}"'') failingTests}
      exit 1
    ''}
    echo "All ${toString (builtins.length (builtins.attrNames allTests))} mullet sourcePath tests passed."
    touch $out
  ''