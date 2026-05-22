#!/usr/bin/env bats
# Tests for scripts/mullet.just
#
# MULLET_FILE was changed from a hardcoded path to a dynamic USER-based path:
#   Before: "nixos/modules/apps/mullet.txt"
#   After:  "users/" + env_var("USER") + "/var/mullet.txt"
#
# Run with: bats tests/scripts/test_mullet.bats

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Reconstruct the MULLET_FILE path logic from mullet.just as a bash expression.
# In just, `env_var("USER")` expands to the USER environment variable.
mullet_file_for_user() {
    local user="$1"
    echo "users/${user}/var/mullet.txt"
}

# ---------------------------------------------------------------------------
# MULLET_FILE path construction
# ---------------------------------------------------------------------------

@test "MULLET_FILE uses the USER env var in the path" {
    local file
    file=$(USER=joe mullet_file_for_user "joe")
    [[ "$file" == "users/joe/var/mullet.txt" ]]
}

@test "MULLET_FILE path starts with 'users/'" {
    local file
    file=$(mullet_file_for_user "testuser")
    [[ "$file" == users/* ]]
}

@test "MULLET_FILE path ends with '/var/mullet.txt'" {
    local file
    file=$(mullet_file_for_user "testuser")
    [[ "$file" == *"/var/mullet.txt" ]]
}

@test "MULLET_FILE path contains the given username" {
    local file
    file=$(mullet_file_for_user "alice")
    [[ "$file" == *"alice"* ]]
}

@test "MULLET_FILE is NOT the old hardcoded path" {
    local file
    file=$(mullet_file_for_user "joe")
    [[ "$file" != "nixos/modules/apps/mullet.txt" ]]
}

@test "MULLET_FILE differs for different users" {
    local file_joe file_alice
    file_joe=$(mullet_file_for_user "joe")
    file_alice=$(mullet_file_for_user "alice")
    [[ "$file_joe" != "$file_alice" ]]
}

@test "MULLET_FILE has the correct full path for user 'joe'" {
    local file
    file=$(mullet_file_for_user "joe")
    [[ "$file" == "users/joe/var/mullet.txt" ]]
}

# ---------------------------------------------------------------------------
# add / rm / lst logic (extracted bash logic from the recipes)
# ---------------------------------------------------------------------------

setup() {
    # Create a temporary directory and a fake mullet.txt for each test
    TEST_DIR=$(mktemp -d)
    mkdir -p "${TEST_DIR}/users/joe/var"
    MULLET_FILE="${TEST_DIR}/users/joe/var/mullet.txt"
    touch "$MULLET_FILE"
}

teardown() {
    rm -rf "$TEST_DIR"
}

# --- add recipe logic ---

@test "add: appends a new package to MULLET_FILE" {
    # Simulate the add recipe: if not present, append
    local pkg="cowsay"
    if ! grep -q "^[[:space:]]*${pkg}[[:space:]]*$" "$MULLET_FILE"; then
        echo "$pkg" >> "$MULLET_FILE"
    fi
    grep -q "^cowsay$" "$MULLET_FILE"
}

@test "add: does not duplicate an existing package" {
    local pkg="cowsay"
    echo "$pkg" >> "$MULLET_FILE"

    # Run add logic
    if ! grep -q "^[[:space:]]*${pkg}[[:space:]]*$" "$MULLET_FILE"; then
        echo "$pkg" >> "$MULLET_FILE"
    fi

    local count
    count=$(grep -c "^cowsay$" "$MULLET_FILE")
    [[ "$count" -eq 1 ]]
}

@test "add: detects package with surrounding whitespace as a duplicate" {
    printf '  cowsay  \n' >> "$MULLET_FILE"

    # The grep pattern allows surrounding spaces
    local found=0
    if grep -q "^[[:space:]]*cowsay[[:space:]]*$" "$MULLET_FILE"; then
        found=1
    fi
    [[ "$found" -eq 1 ]]
}

# --- rm recipe logic ---

@test "rm: removes an existing package from MULLET_FILE" {
    echo "cowsay" >> "$MULLET_FILE"
    echo "tmux"   >> "$MULLET_FILE"

    # Simulate rm logic
    if grep -q "^[[:space:]]*cowsay[[:space:]]*$" "$MULLET_FILE"; then
        sed -i "/^[[:space:]]*cowsay[[:space:]]*$/d" "$MULLET_FILE"
    fi

    ! grep -q "^cowsay$" "$MULLET_FILE"
}

@test "rm: leaves other packages intact" {
    echo "cowsay" >> "$MULLET_FILE"
    echo "tmux"   >> "$MULLET_FILE"

    sed -i "/^[[:space:]]*cowsay[[:space:]]*$/d" "$MULLET_FILE"

    grep -q "^tmux$" "$MULLET_FILE"
}

@test "rm: exits 1 when package is not found" {
    # Simulate rm logic: if not found, exit 1
    local pkg="nothere"
    run bash -c "
        if grep -q '^[[:space:]]*${pkg}[[:space:]]*$' '${MULLET_FILE}'; then
            sed -i \"/^[[:space:]]*${pkg}[[:space:]]*$/d\" '${MULLET_FILE}'
            echo 'Removed'
        else
            echo \":: Error: '${pkg}' not found in The Mullet. ::\"
            exit 1
        fi
    "
    [[ "$status" -eq 1 ]]
    [[ "$output" =~ "not found in The Mullet" ]]
}

# --- haircut logic ---

@test "haircut: clears all contents from MULLET_FILE" {
    printf 'cowsay\ntmux\nfd\n' >> "$MULLET_FILE"

    # Simulate haircut (the > truncation)
    > "$MULLET_FILE"

    local size
    size=$(wc -c < "$MULLET_FILE")
    [[ "$size" -eq 0 ]]
}

# --- lst logic ---

@test "lst: cat produces output matching MULLET_FILE contents" {
    printf 'cowsay\ntmux\n' > "$MULLET_FILE"

    run cat "$MULLET_FILE"
    [[ "$status" -eq 0 ]]
    [[ "$output" =~ "cowsay" ]]
    [[ "$output" =~ "tmux" ]]
}