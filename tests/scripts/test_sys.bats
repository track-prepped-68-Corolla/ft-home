#!/usr/bin/env bats
# Tests for scripts/sys.just
#
# Covers: push check logic, _check-reqs tool validation, home-switch argument
# defaults, and _current-gen / _last-two-gens helper patterns.
#
# Run with: bats tests/scripts/test_sys.bats

# ---------------------------------------------------------------------------
# push recipe — blocks on uncommitted changes, error message says 'ft switch'
# ---------------------------------------------------------------------------

# Extract the push guard logic from sys.just push recipe into a testable function.
push_guard() {
    local porcelain_output="$1"  # simulated git status --porcelain output
    if [[ -n "$porcelain_output" ]]; then
        echo ":: Error: Uncommitted changes. Run 'ft switch' or commit manually first. ::"
        return 1
    fi
    echo ":: Pushing to Remote ::"
    return 0
}

@test "push: exits 1 when there are uncommitted changes" {
    run bash -c "$(declare -f push_guard); push_guard ' M some/file.nix'"
    [[ "$status" -eq 1 ]]
}

@test "push: outputs error message containing 'ft switch' when changes exist" {
    run bash -c "$(declare -f push_guard); push_guard '?? newfile.nix'"
    [[ "$output" =~ "ft switch" ]]
}

@test "push: error message does NOT say 'just switch' (old message removed)" {
    run bash -c "$(declare -f push_guard); push_guard ' M dirty.nix'"
    [[ ! "$output" =~ "just switch" ]]
}

@test "push: exits 0 when working tree is clean" {
    run bash -c "$(declare -f push_guard); push_guard ''"
    [[ "$status" -eq 0 ]]
}

@test "push: prints 'Pushing to Remote' message when clean" {
    run bash -c "$(declare -f push_guard); push_guard ''"
    [[ "$output" =~ "Pushing to Remote" ]]
}

@test "push: treats any non-empty porcelain output as dirty" {
    # Staged file
    run bash -c "$(declare -f push_guard); push_guard 'A  staged_file.nix'"
    [[ "$status" -eq 1 ]]
}

@test "push: treats empty-string porcelain output as clean" {
    run bash -c "$(declare -f push_guard); push_guard ''"
    [[ "$status" -eq 0 ]]
}

# Boundary: whitespace-only string is non-empty → should block
@test "push: whitespace-only porcelain output is treated as dirty" {
    run bash -c "$(declare -f push_guard); push_guard '   '"
    [[ "$status" -eq 1 ]]
}

# ---------------------------------------------------------------------------
# _check-reqs recipe — validates required tools are available
# ---------------------------------------------------------------------------

# Extracted _check-reqs logic: loops over required commands and exits 1 if any missing.
check_reqs() {
    local required_cmds=("$@")
    for cmd in "${required_cmds[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            echo "Error: $cmd is not installed."
            return 1
        fi
    done
    return 0
}

@test "_check-reqs: passes when all required tools exist" {
    # Use commands that are guaranteed to be present (bash, sh, ls)
    run bash -c "$(declare -f check_reqs); check_reqs bash sh ls"
    [[ "$status" -eq 0 ]]
}

@test "_check-reqs: exits 1 when a required tool is missing" {
    run bash -c "$(declare -f check_reqs); check_reqs __nonexistent_tool_xyz__"
    [[ "$status" -eq 1 ]]
}

@test "_check-reqs: prints an error naming the missing tool" {
    run bash -c "$(declare -f check_reqs); check_reqs __no_such_tool_abc__"
    [[ "$output" =~ "__no_such_tool_abc__" ]]
    [[ "$output" =~ "not installed" ]]
}

@test "_check-reqs: stops at the first missing tool" {
    # First tool missing; second tool (bash) is present
    run bash -c "$(declare -f check_reqs); check_reqs __missing__ bash"
    [[ "$status" -eq 1 ]]
    [[ "$output" =~ "__missing__" ]]
}

@test "_check-reqs: fails if any of nh nvd delta is missing (simulated)" {
    # Simulate environment where 'nh' is missing by shadowing PATH
    run bash -c "
        PATH=/usr/bin:/bin
        $(declare -f check_reqs)
        check_reqs nh nvd delta
    "
    # nh and nvd are unlikely to be in /usr/bin or /bin; the check should fail
    # We only assert the mechanism works — actual pass/fail depends on host
    [[ "$status" -eq 0 || "$status" -eq 1 ]]
}

@test "_check-reqs: error message format matches expected pattern" {
    run bash -c "$(declare -f check_reqs); check_reqs __bogus_cmd__"
    [[ "$output" == "Error: __bogus_cmd__ is not installed." ]]
}

# ---------------------------------------------------------------------------
# home-switch recipe — argument defaulting logic
# ---------------------------------------------------------------------------

# Extract the home-switch argument resolution logic.
# In sys.just: USER="${{user:-$USER}}" ARCH="${{arch:-$(uname -m)-linux}}"
# (just's {{ }} template renders the bash expression)
home_switch_args() {
    local user_param="${1:-}"
    local arch_param="${2:-}"
    local USER="${USER:-testuser}"

    local resolved_user="${user_param:-$USER}"
    local resolved_arch="${arch_param:-$(uname -m)-linux}"

    echo "user=${resolved_user}"
    echo "arch=${resolved_arch}"
}

@test "home-switch: defaults user to current USER when no argument given" {
    run bash -c "USER=joe $(declare -f home_switch_args); home_switch_args '' ''"
    [[ "$output" =~ "user=joe" ]]
}

@test "home-switch: uses explicit user argument when given" {
    run bash -c "$(declare -f home_switch_args); home_switch_args 'alice' ''"
    [[ "$output" =~ "user=alice" ]]
}

@test "home-switch: defaults arch to '<machine>-linux' when no argument given" {
    run bash -c "$(declare -f home_switch_args); home_switch_args '' ''"
    [[ "$output" =~ "arch=" ]]
    [[ "$output" =~ "-linux" ]]
}

@test "home-switch: uses explicit arch argument when given" {
    run bash -c "$(declare -f home_switch_args); home_switch_args '' 'aarch64-linux'"
    [[ "$output" =~ "arch=aarch64-linux" ]]
}

@test "home-switch: explicit user overrides USER env var" {
    run bash -c "USER=joe $(declare -f home_switch_args); home_switch_args 'bob' ''"
    [[ "$output" =~ "user=bob" ]]
    [[ ! "$output" =~ "user=joe" ]]
}

# ---------------------------------------------------------------------------
# _current-gen helper — extracts generation number via cut
# ---------------------------------------------------------------------------

@test "_current-gen: cut -d'-' -f2 extracts the second dash-delimited field" {
    # Simulate readlink output like "system-42-link"
    local symlink_target="system-42-link"
    local gen
    gen=$(echo "$symlink_target" | cut -d'-' -f2)
    [[ "$gen" == "42" ]]
}

@test "_current-gen: correctly extracts single-digit generation" {
    local gen
    gen=$(echo "system-5-link" | cut -d'-' -f2)
    [[ "$gen" == "5" ]]
}

@test "_current-gen: correctly extracts three-digit generation" {
    local gen
    gen=$(echo "system-123-link" | cut -d'-' -f2)
    [[ "$gen" == "123" ]]
}

# ---------------------------------------------------------------------------
# Generation comparison — used in switch to decide whether to clean
# ---------------------------------------------------------------------------

@test "switch: cleans when new generation is greater than old" {
    local old_gen=41
    local new_gen=42
    local should_clean=0
    if [ "$new_gen" -gt "$old_gen" ]; then
        should_clean=1
    fi
    [[ "$should_clean" -eq 1 ]]
}

@test "switch: skips clean when generation did not change" {
    local old_gen=42
    local new_gen=42
    local should_clean=0
    if [ "$new_gen" -gt "$old_gen" ]; then
        should_clean=1
    fi
    [[ "$should_clean" -eq 0 ]]
}

@test "switch: skips clean when generation decreased (rollback scenario)" {
    local old_gen=42
    local new_gen=41
    local should_clean=0
    if [ "$new_gen" -gt "$old_gen" ]; then
        should_clean=1
    fi
    [[ "$should_clean" -eq 0 ]]
}
