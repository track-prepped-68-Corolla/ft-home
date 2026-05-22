#!/usr/bin/env bats
# Tests for file location changes in this PR.
#
# Verifies:
#   - users/joe/var/mullet.txt exists at its new location
#   - modules/nixos/apps/mullet.txt does NOT exist (it was renamed)
#   - scripts/.justfile does NOT exist (it was deleted)
#   - scripts/sys.just exists (new file)
#   - scripts/bootstrap.just exists (new file)
#   - scripts/ft.just exists and imports the new modules
#   - machines/strix/default.nix uses ft.mullet with sourcePath
#
# Run with: bats tests/scripts/test_file_locations.bats

REPO_ROOT="$(git -C "$(dirname "$BATS_TEST_FILENAME")" rev-parse --show-toplevel)"

# ---------------------------------------------------------------------------
# mullet.txt location
# ---------------------------------------------------------------------------

@test "users/joe/var/mullet.txt exists at new location" {
    [ -f "${REPO_ROOT}/users/joe/var/mullet.txt" ]
}

@test "users/joe/var/mullet.txt is non-empty" {
    [ -s "${REPO_ROOT}/users/joe/var/mullet.txt" ]
}

@test "users/joe/var/mullet.txt contains newline-delimited package names" {
    local line_count
    line_count=$(wc -l < "${REPO_ROOT}/users/joe/var/mullet.txt")
    [ "$line_count" -gt 0 ]
}

@test "users/joe/var/mullet.txt does not contain blank lines between packages (no double newlines)" {
    # Allow one trailing newline but no internal blank lines
    local blank_count
    blank_count=$(grep -c "^$" "${REPO_ROOT}/users/joe/var/mullet.txt" || echo 0)
    # At most one blank line (the trailing newline at EOF)
    [ "${blank_count:-0}" -le 1 ]
}

@test "modules/nixos/apps/mullet.txt does NOT exist (renamed to users/joe/var/)" {
    [ ! -f "${REPO_ROOT}/modules/nixos/apps/mullet.txt" ]
}

# ---------------------------------------------------------------------------
# Deleted / new script files
# ---------------------------------------------------------------------------

@test "scripts/.justfile does NOT exist (deleted in this PR)" {
    [ ! -f "${REPO_ROOT}/scripts/.justfile" ]
}

@test "scripts/sys.just exists (new file added in this PR)" {
    [ -f "${REPO_ROOT}/scripts/sys.just" ]
}

@test "scripts/bootstrap.just exists (new file added in this PR)" {
    [ -f "${REPO_ROOT}/scripts/bootstrap.just" ]
}

@test "scripts/ft.just exists" {
    [ -f "${REPO_ROOT}/scripts/ft.just" ]
}

@test "scripts/mullet.just exists" {
    [ -f "${REPO_ROOT}/scripts/mullet.just" ]
}

# ---------------------------------------------------------------------------
# ft.just imports
# ---------------------------------------------------------------------------

@test "scripts/ft.just imports sys.just" {
    grep -q 'import.*sys\.just' "${REPO_ROOT}/scripts/ft.just"
}

@test "scripts/ft.just imports bootstrap.just" {
    grep -q 'import.*bootstrap\.just' "${REPO_ROOT}/scripts/ft.just"
}

@test "scripts/ft.just imports mullet.just" {
    grep -q 'import.*mullet\.just' "${REPO_ROOT}/scripts/ft.just"
}

@test "scripts/ft.just does NOT contain inline recipe implementations (moved to modules)" {
    # ft.just should only have imports, aliases, and the default recipe
    # It must not define fmt, check, switch, pull, push directly
    ! grep -q '^fmt:' "${REPO_ROOT}/scripts/ft.just"
    ! grep -q '^check:' "${REPO_ROOT}/scripts/ft.just"
    ! grep -q '^switch:' "${REPO_ROOT}/scripts/ft.just"
}

@test "scripts/ft.just sets 'set quiet := true'" {
    grep -q '^set quiet := true' "${REPO_ROOT}/scripts/ft.just"
}

# ---------------------------------------------------------------------------
# mullet.just MULLET_FILE path
# ---------------------------------------------------------------------------

@test "scripts/mullet.just MULLET_FILE uses USER env var path" {
    grep -q 'MULLET_FILE.*users.*USER.*var/mullet\.txt' "${REPO_ROOT}/scripts/mullet.just"
}

@test "scripts/mullet.just MULLET_FILE does NOT use old hardcoded path" {
    ! grep -q 'nixos/modules/apps/mullet\.txt' "${REPO_ROOT}/scripts/mullet.just"
}

# ---------------------------------------------------------------------------
# machines/strix/default.nix — ft.mullet sourcePath
# ---------------------------------------------------------------------------

@test "machines/strix/default.nix exists" {
    [ -f "${REPO_ROOT}/machines/strix/default.nix" ]
}

@test "machines/strix/default.nix has ft.mullet as an attribute set (not just enable)" {
    grep -q 'ft\.mullet = {' "${REPO_ROOT}/machines/strix/default.nix"
}

@test "machines/strix/default.nix ft.mullet has enable = true" {
    grep -A5 'ft\.mullet = {' "${REPO_ROOT}/machines/strix/default.nix" | grep -q 'enable.*=.*true'
}

@test "machines/strix/default.nix ft.mullet has sourcePath pointing to users/joe/var/mullet.txt" {
    grep -A5 'ft\.mullet = {' "${REPO_ROOT}/machines/strix/default.nix" | \
        grep -q 'sourcePath.*users/joe/var/mullet\.txt'
}

@test "machines/strix/default.nix ft.mullet sourcePath uses relative ../../ prefix" {
    # The path must be a relative Nix path, not a string
    grep -A5 'ft\.mullet = {' "${REPO_ROOT}/machines/strix/default.nix" | \
        grep -q 'sourcePath = \.\./\.\./users/joe/var/mullet\.txt'
}

@test "machines/strix/default.nix does NOT use old-style 'ft.mullet.enable = true;' one-liner" {
    # Old style was: ft.mullet.enable = true;  (single line, no sourcePath)
    ! grep -q '^[[:space:]]*ft\.mullet\.enable = true;' "${REPO_ROOT}/machines/strix/default.nix"
}

# ---------------------------------------------------------------------------
# scripts/sys.just content verification
# ---------------------------------------------------------------------------

@test "scripts/sys.just push error message says 'ft switch' not 'just switch'" {
    grep -q "ft switch" "${REPO_ROOT}/scripts/sys.just"
    ! grep -q "'just switch'" "${REPO_ROOT}/scripts/sys.just"
}

@test "scripts/sys.just defines _check-reqs recipe" {
    grep -q '_check-reqs:' "${REPO_ROOT}/scripts/sys.just"
}

@test "scripts/sys.just _check-reqs checks for nh nvd delta" {
    grep -A5 '_check-reqs:' "${REPO_ROOT}/scripts/sys.just" | grep -q 'nh nvd delta'
}

@test "scripts/sys.just defines home-switch recipe" {
    grep -q '^home-switch' "${REPO_ROOT}/scripts/sys.just"
}

@test "scripts/sys.just defines rollback recipe" {
    grep -q '^rollback:' "${REPO_ROOT}/scripts/sys.just"
}

# ---------------------------------------------------------------------------
# scripts/bootstrap.just content verification
# ---------------------------------------------------------------------------

@test "scripts/bootstrap.just defines add-machine recipe" {
    grep -q '^add-machine' "${REPO_ROOT}/scripts/bootstrap.just"
}

@test "scripts/bootstrap.just defines generate-facts recipe" {
    grep -q '^generate-facts' "${REPO_ROOT}/scripts/bootstrap.just"
}

@test "scripts/bootstrap.just defines deploy recipe" {
    grep -q '^deploy' "${REPO_ROOT}/scripts/bootstrap.just"
}

@test "scripts/bootstrap.just defines bootstrap recipe" {
    grep -q '^bootstrap' "${REPO_ROOT}/scripts/bootstrap.just"
}

@test "scripts/bootstrap.just secrets-init references var/secrets/.sops.yaml" {
    grep -q 'var/secrets/\.sops\.yaml' "${REPO_ROOT}/scripts/bootstrap.just"
}

@test "scripts/bootstrap.just tailscale-init uses var/secrets/shared/tailscale.yaml" {
    grep -q 'var/secrets/shared/tailscale\.yaml' "${REPO_ROOT}/scripts/bootstrap.just"
}

@test "scripts/bootstrap.just add-machine template includes ft.mullet sourcePath" {
    # The heredoc in add-machine must set sourcePath to users/joe/var/mullet.txt
    grep -q 'sourcePath = .*users/joe/var/mullet\.txt' "${REPO_ROOT}/scripts/bootstrap.just"
}

@test "scripts/bootstrap.just uses --justfile flag for sub-just calls" {
    grep -q 'just --justfile' "${REPO_ROOT}/scripts/bootstrap.just"
}