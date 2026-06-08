# Failover recipe — wraps nh os switch, clears and rebuilds stable-overrides.list
# each session, retries until the build passes or no new overrides are found.

_overrides := justfile_directory() / "var/stable-overrides.list"
_max_retries := "5"

# Replaces `nh os switch .` in the switch workflow.
# Clears stable-overrides.list at the top of each run so packages fixed in
# nixpkgs-unstable auto-drop rather than accumulating indefinitely.
# On failure, extracts the failing package attribute from .drv paths via regex,
# appends it to the list, stages the file, and retries up to _max_retries times.
failover-switch:
    #!/usr/bin/env bash
    set -uo pipefail

    OVERRIDES="{{_overrides}}"
    MAX={{_max_retries}}

    # Clear at session start — packages fixed upstream auto-drop from the list.
    : > "$OVERRIDES"

    for attempt in $(seq 1 "$MAX"); do
        LOG=$(mktemp /tmp/nh-build-XXXXXX.log)

        if nh os switch . 2>&1 | tee "$LOG"; then
            rm -f "$LOG"
            echo "failover: succeeded on attempt $attempt" >&2
            exit 0
        fi
        build_status=$?

        # Extract pname from failed .drv paths.
        # Input:    /nix/store/<32hex>-<pname>-<version>.drv
        # Strategy: strip hash prefix and .drv suffix, then strip -VERSION
        #           (everything from the first -digit onward).
        # Caveat:   compound names like python312-requests map to "python312"
        #           rather than the real pkgs attribute; manual correction may
        #           be needed for those cases.
        attrs=$(grep -oP '(?<=/nix/store/[a-z0-9]{32}-)[^/\n]+(?=\.drv)' "$LOG" \
            | sed 's/-[0-9].*$//' \
            | sort -u \
            | grep -v '^$' || true)
        rm -f "$LOG"

        if [[ -z "$attrs" ]]; then
            echo "failover: no package attributes extractable — build broken for another reason" >&2
            exit $build_status
        fi

        any_new=false
        while IFS= read -r attr; do
            if ! grep -qxF "$attr" "$OVERRIDES"; then
                echo "$attr" >> "$OVERRIDES"
                echo "failover: pinned '$attr' to stable" >&2
                any_new=true
            fi
        done <<< "$attrs"

        if ! $any_new; then
            echo "failover: no new packages to override — build still failing" >&2
            exit $build_status
        fi

        # Stage updated list so nix's source-tree copy picks up the change.
        git -C "{{justfile_directory()}}" add "$OVERRIDES" 2>/dev/null || true
        echo "failover: retrying (attempt $attempt/$MAX)..." >&2
    done

    echo "failover: max retries reached. Current overrides:" >&2
    cat "$OVERRIDES" >&2
    exit 1
