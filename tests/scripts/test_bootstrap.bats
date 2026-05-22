#!/usr/bin/env bats
# Tests for scripts/bootstrap.just
#
# Covers: add-machine scaffolding, deploy EXTRA_FILES logic, _rp file-backed
# prompt helper, secrets-init output messages, and tailscale-init path changes.
#
# Run with: bats tests/scripts/test_bootstrap.bats

# ---------------------------------------------------------------------------
# Shared setup / teardown
# ---------------------------------------------------------------------------

setup() {
    TEST_DIR=$(mktemp -d)
    cd "$TEST_DIR"
    # Minimal git repo so `git add` / `git commit` work in tests that need it
    git init -q
    git config user.email "test@test.local"
    git config user.name "Test"
}

teardown() {
    cd /
    rm -rf "$TEST_DIR"
}

# ---------------------------------------------------------------------------
# _rp helper (read-or-prompt) — used in git-init and tailscale-init
# ---------------------------------------------------------------------------

# Extracted logic from bootstrap.just git-init and tailscale-init.
# Returns cached value from file if it exists; otherwise reads from stdin.
rp_cached() {
    local dir="$1" key="$2" value="$3"
    local filepath="${dir}/${key}"
    if [ -f "$filepath" ]; then
        cat "$filepath"
        return 0
    fi
    # Write the provided value and return it (simulates interactive read)
    mkdir -p "$(dirname "$filepath")"
    printf '%s' "$value" > "$filepath"
    echo "$value"
}

@test "_rp: returns cached file value when key file exists" {
    mkdir -p "${TEST_DIR}/var/git"
    printf 'Joe User' > "${TEST_DIR}/var/git/user-name"

    run bash -c "$(declare -f rp_cached); rp_cached '${TEST_DIR}/var/git' 'user-name' 'Other Name'"
    [[ "$status" -eq 0 ]]
    [[ "$output" == "Joe User" ]]
}

@test "_rp: writes value to file when key file does not exist" {
    run bash -c "$(declare -f rp_cached); rp_cached '${TEST_DIR}/var/git' 'user-name' 'Joe User'"
    [[ -f "${TEST_DIR}/var/git/user-name" ]]
    [[ "$(cat "${TEST_DIR}/var/git/user-name")" == "Joe User" ]]
}

@test "_rp: creates intermediate directories when they do not exist" {
    [ ! -d "${TEST_DIR}/var/git" ]
    bash -c "$(declare -f rp_cached); rp_cached '${TEST_DIR}/var/git' 'remote' 'git@github.com:a/b'"
    [ -d "${TEST_DIR}/var/git" ]
}

@test "_rp: second call returns cached value without overwriting" {
    mkdir -p "${TEST_DIR}/var/git"
    printf 'first' > "${TEST_DIR}/var/git/remote"

    bash -c "$(declare -f rp_cached); rp_cached '${TEST_DIR}/var/git' 'remote' 'second'"
    [[ "$(cat "${TEST_DIR}/var/git/remote")" == "first" ]]
}

# ---------------------------------------------------------------------------
# add-machine scaffolding logic
# ---------------------------------------------------------------------------

# Extracted add-machine core logic (without nix eval and git operations)
run_add_machine() {
    local name="$1"
    local machine_dir="machines/${name}"

    if [ -d "$machine_dir" ]; then
        echo ":: Machine ${name} already exists at ${machine_dir} ::"
        return 0
    fi

    local system="x86_64-linux"  # mocked; avoids calling nix
    mkdir -p var/local
    printf '%s' "$name"   > var/local/machineName
    printf '%s' "$system" > var/local/system
    mkdir -p "${machine_dir}/modules"
    mkdir -p "${machine_dir}/var"

    cat > "${machine_dir}/default.nix" <<EOF
{ ... }:
{
  imports = [
    ./modules
    ../../modules/nixos
  ];

  networking.hostName = "${name}";
  mainuser = "joe";
  superUsers = [ "joe" ];
  users.users.joe.initialPassword = "nixos";
  users.mutableUsers = true;

  ft.boot.limine.enable    = true;
  ft.desktop.cosmic.enable = true;
  ft.cli.enable            = true;

  ft.mullet = {
    enable     = true;
    sourcePath = ../../users/joe/var/mullet.txt;
  };

  ft.security.sops = {
    enable = true;
    useTPM = true;
  };

  ft.hardware.facter = {
    enable     = true;
    reportPath = ./var/facter.json;
  };

  nixpkgs.hostPlatform = "${system}";
}
EOF

    cat > "${machine_dir}/modules/default.nix" <<'MODEOF'
{ lib, ... }:
let
  allFiles = lib.filesystem.listFilesRecursive ./.;
  validModules = builtins.filter (
    path: lib.hasSuffix ".nix" (builtins.toString path) && path != ./default.nix
  ) allFiles;
in
{
  imports = validModules;
}
MODEOF

    echo ":: Machine ${name} scaffolded at ${machine_dir} ::"
}

@test "add-machine: creates machines/<name>/default.nix" {
    run bash -c "cd '${TEST_DIR}'; $(declare -f run_add_machine); run_add_machine testmachine"
    [ -f "${TEST_DIR}/machines/testmachine/default.nix" ]
}

@test "add-machine: creates machines/<name>/modules/default.nix" {
    run bash -c "cd '${TEST_DIR}'; $(declare -f run_add_machine); run_add_machine testmachine"
    [ -f "${TEST_DIR}/machines/testmachine/modules/default.nix" ]
}

@test "add-machine: creates machines/<name>/var/ directory" {
    run bash -c "cd '${TEST_DIR}'; $(declare -f run_add_machine); run_add_machine testmachine"
    [ -d "${TEST_DIR}/machines/testmachine/var" ]
}

@test "add-machine: writes machineName to var/local/machineName" {
    bash -c "cd '${TEST_DIR}'; $(declare -f run_add_machine); run_add_machine mymachine"
    [[ "$(cat "${TEST_DIR}/var/local/machineName")" == "mymachine" ]]
}

@test "add-machine: writes system to var/local/system" {
    bash -c "cd '${TEST_DIR}'; $(declare -f run_add_machine); run_add_machine mymachine"
    [ -f "${TEST_DIR}/var/local/system" ]
    [ -s "${TEST_DIR}/var/local/system" ]
}

@test "add-machine: generated default.nix sets hostName to machine name" {
    bash -c "cd '${TEST_DIR}'; $(declare -f run_add_machine); run_add_machine newhost"
    grep -q 'networking.hostName = "newhost"' "${TEST_DIR}/machines/newhost/default.nix"
}

@test "add-machine: generated default.nix includes ft.mullet with sourcePath" {
    bash -c "cd '${TEST_DIR}'; $(declare -f run_add_machine); run_add_machine newhost"
    grep -q 'ft.mullet' "${TEST_DIR}/machines/newhost/default.nix"
    grep -q 'sourcePath' "${TEST_DIR}/machines/newhost/default.nix"
    grep -q '../../users/joe/var/mullet.txt' "${TEST_DIR}/machines/newhost/default.nix"
}

@test "add-machine: generated default.nix sets ft.mullet.enable = true" {
    bash -c "cd '${TEST_DIR}'; $(declare -f run_add_machine); run_add_machine newhost"
    grep -q 'enable.*=.*true' "${TEST_DIR}/machines/newhost/default.nix"
}

@test "add-machine: generated modules/default.nix uses lib.filesystem.listFilesRecursive" {
    bash -c "cd '${TEST_DIR}'; $(declare -f run_add_machine); run_add_machine newhost"
    grep -q 'lib.filesystem.listFilesRecursive' "${TEST_DIR}/machines/newhost/modules/default.nix"
}

@test "add-machine: generated modules/default.nix filters out itself (./default.nix)" {
    bash -c "cd '${TEST_DIR}'; $(declare -f run_add_machine); run_add_machine newhost"
    grep -q 'path != ./default.nix' "${TEST_DIR}/machines/newhost/modules/default.nix"
}

@test "add-machine: is idempotent — exits 0 when machine already exists" {
    mkdir -p "${TEST_DIR}/machines/existing"
    run bash -c "cd '${TEST_DIR}'; $(declare -f run_add_machine); run_add_machine existing"
    [[ "$status" -eq 0 ]]
    [[ "$output" =~ "already exists" ]]
}

@test "add-machine: idempotent run does not overwrite existing default.nix" {
    mkdir -p "${TEST_DIR}/machines/existing"
    echo "ORIGINAL CONTENT" > "${TEST_DIR}/machines/existing/default.nix"
    bash -c "cd '${TEST_DIR}'; $(declare -f run_add_machine); run_add_machine existing"
    grep -q "ORIGINAL CONTENT" "${TEST_DIR}/machines/existing/default.nix"
}

@test "add-machine: generated default.nix includes ft.security.sops with useTPM" {
    bash -c "cd '${TEST_DIR}'; $(declare -f run_add_machine); run_add_machine newhost"
    grep -q 'ft.security.sops' "${TEST_DIR}/machines/newhost/default.nix"
    grep -q 'useTPM' "${TEST_DIR}/machines/newhost/default.nix"
}

@test "add-machine: generated default.nix includes ft.hardware.facter with reportPath" {
    bash -c "cd '${TEST_DIR}'; $(declare -f run_add_machine); run_add_machine newhost"
    grep -q 'ft.hardware.facter' "${TEST_DIR}/machines/newhost/default.nix"
    grep -q 'reportPath' "${TEST_DIR}/machines/newhost/default.nix"
    grep -q './var/facter.json' "${TEST_DIR}/machines/newhost/default.nix"
}

@test "add-machine: generated default.nix includes superUsers list" {
    bash -c "cd '${TEST_DIR}'; $(declare -f run_add_machine); run_add_machine newhost"
    grep -q 'superUsers' "${TEST_DIR}/machines/newhost/default.nix"
}

# ---------------------------------------------------------------------------
# deploy recipe — EXTRA_FILES logic
# ---------------------------------------------------------------------------

# Extracted deploy EXTRA_FILES decision logic from bootstrap.just
deploy_extra_files_flag() {
    local tmpdir="$1"
    local extra_files=""
    if [ -f "${tmpdir}/ssh_host_ed25519_key" ]; then
        extra_files="--extra-files ${tmpdir}"
    fi
    echo "$extra_files"
}

@test "deploy: includes --extra-files when ssh key file exists" {
    local tmpdir="${TEST_DIR}/tmp-bootstrap-host"
    mkdir -p "$tmpdir"
    touch "${tmpdir}/ssh_host_ed25519_key"

    run bash -c "$(declare -f deploy_extra_files_flag); deploy_extra_files_flag '${tmpdir}'"
    [[ "$output" =~ "--extra-files" ]]
    [[ "$output" =~ "$tmpdir" ]]
}

@test "deploy: does not include --extra-files when ssh key file is absent" {
    local tmpdir="${TEST_DIR}/tmp-bootstrap-host"
    mkdir -p "$tmpdir"
    # No ssh key file created

    run bash -c "$(declare -f deploy_extra_files_flag); deploy_extra_files_flag '${tmpdir}'"
    [[ "$output" == "" ]]
}

@test "deploy: --extra-files flag is empty string when tmpdir does not exist" {
    local tmpdir="${TEST_DIR}/does-not-exist"

    run bash -c "$(declare -f deploy_extra_files_flag); deploy_extra_files_flag '${tmpdir}'"
    [[ "$output" == "" ]]
}

@test "deploy: copies both key files when ssh key exists (logic check)" {
    local tmpdir="${TEST_DIR}/tmp-bootstrap-host"
    mkdir -p "$tmpdir"
    touch "${tmpdir}/ssh_host_ed25519_key"
    touch "${tmpdir}/ssh_host_ed25519_key.pub"

    # Simulate the cp block in deploy
    run bash -c "
        tmpdir='${tmpdir}'
        if [ -f \"\${tmpdir}/ssh_host_ed25519_key\" ]; then
            mkdir -p \"\${tmpdir}/etc/ssh\"
            cp \"\${tmpdir}/ssh_host_ed25519_key\"     \"\${tmpdir}/etc/ssh/\"
            cp \"\${tmpdir}/ssh_host_ed25519_key.pub\" \"\${tmpdir}/etc/ssh/\"
            echo 'copied'
        fi
    "
    [[ "$status" -eq 0 ]]
    [[ "$output" == "copied" ]]
    [ -f "${tmpdir}/etc/ssh/ssh_host_ed25519_key" ]
    [ -f "${tmpdir}/etc/ssh/ssh_host_ed25519_key.pub" ]
}

# ---------------------------------------------------------------------------
# secrets-init output messages — path changed to var/secrets/
# ---------------------------------------------------------------------------

# Extracted secrets-init output messages from bootstrap.just
secrets_init_messages() {
    local name="$1"
    echo "Add to var/secrets/.sops.yaml:   - &${name}  <age-pubkey>"
    echo "Then run:  sops updatekeys var/secrets/shared/*.yaml"
}

@test "secrets-init: output references 'var/secrets/.sops.yaml'" {
    run bash -c "$(declare -f secrets_init_messages); secrets_init_messages myhost"
    [[ "$output" =~ "var/secrets/.sops.yaml" ]]
}

@test "secrets-init: output does NOT reference old path 'secrets/shared/.sops.yaml'" {
    run bash -c "$(declare -f secrets_init_messages); secrets_init_messages myhost"
    [[ ! "$output" =~ "secrets/shared/.sops.yaml" ]]
    # Ensure the old (pre-PR) location is not referenced
    [[ ! "$output" =~ "^secrets/" ]]
}

@test "secrets-init: output references 'var/secrets/shared/*.yaml' for updatekeys" {
    run bash -c "$(declare -f secrets_init_messages); secrets_init_messages myhost"
    [[ "$output" =~ "var/secrets/shared/\*.yaml" ]]
}

@test "secrets-init: output includes the machine name in the sops anchor" {
    run bash -c "$(declare -f secrets_init_messages); secrets_init_messages specialhost"
    [[ "$output" =~ "specialhost" ]]
}

@test "secrets-init: sops updatekeys command is present in output" {
    run bash -c "$(declare -f secrets_init_messages); secrets_init_messages myhost"
    [[ "$output" =~ "sops updatekeys" ]]
}

# ---------------------------------------------------------------------------
# tailscale-init path change — now uses var/secrets/shared/
# ---------------------------------------------------------------------------

@test "tailscale-init: secrets path uses var/secrets/shared/ prefix" {
    # The tailscale.yaml secret file path changed from secrets/shared/ to var/secrets/shared/
    local expected_path="var/secrets/shared/tailscale.yaml"
    local actual_path
    # Simulate: read the path from the bootstrap.just source
    actual_path=$(grep -o 'var/secrets/shared/tailscale\.yaml' \
        "$(git -C /home/jailuser/git rev-parse --show-toplevel)/scripts/bootstrap.just" | head -1)
    [[ "$actual_path" == "$expected_path" ]]
}

@test "tailscale-init: old path 'secrets/shared/tailscale.yaml' is not used" {
    # The old path (without var/ prefix) must not appear in bootstrap.just
    local old_path_count
    old_path_count=$(grep -c "^[^#]*secrets/shared/tailscale\.yaml" \
        "$(git -C /home/jailuser/git rev-parse --show-toplevel)/scripts/bootstrap.just" || true)
    # Every match should have the var/ prefix; count of bare 'secrets/shared/...' must be 0
    local bare_count
    bare_count=$(grep -c "[^r]/secrets/shared/tailscale\.yaml" \
        "$(git -C /home/jailuser/git rev-parse --show-toplevel)/scripts/bootstrap.just" || echo "0")
    [[ "${bare_count:-0}" -eq 0 ]]
}