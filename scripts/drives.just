# --- Bulk Drive Management ---
#
# Drives are formatted with a btrfs label starting with "bulk-":
#   bulk-data-N    → mergerfs pool + snapraid data
#   bulk-parity-N  → snapraid parity (not in pool)
#   bulk-cache-N   → mergerfs pool only (not in snapraid)
#
# After formatting or syncing drives, commit the updated var/bulk-drives.nix
# and run `ft switch` to activate the new configuration.

DRIVES_FILE := "machines/" + `hostname` + "/var/bulk-drives.nix"

# Scan uninitialized drives, select role, format, and register. Interactive — no arguments needed.
drives-format:
    #!/usr/bin/env bash
    set -euo pipefail

    DRIVES_FILE="machines/$(hostname)/var/bulk-drives.nix"

    # Identify the system disk (contains the root filesystem)
    ROOT_DEV=$(findmnt -n -o SOURCE / | sed 's|\[.*\]||')
    ROOT_DISK=$(lsblk -n -o PKNAME "$ROOT_DEV" 2>/dev/null | head -1 || true)
    [[ -z "$ROOT_DISK" ]] && ROOT_DISK=$(basename "$ROOT_DEV" | sed 's/p\?[0-9]*$//')

    echo ":: Scanning for uninitialized drives (system disk: $ROOT_DISK) ::"
    echo ""

    # Build candidate list: non-loop, non-USB, non-system, no bulk-* label
    CANDIDATES=()
    while IFS= read -r line; do
        DEV_NAME=$(echo "$line" | awk '{print $1}')
        [[ "$DEV_NAME" == "$ROOT_DISK" ]] && continue

        TRAN=$(lsblk -d -n -o TRAN "/dev/$DEV_NAME" 2>/dev/null | head -1 | tr -d ' ')
        [[ "$TRAN" == "usb" ]] && continue

        if lsblk -n -o LABEL "/dev/$DEV_NAME" 2>/dev/null | grep -q "^bulk-"; then
            continue
        fi

        CANDIDATES+=("$line")
    done < <(lsblk -d -n -o NAME,SIZE,MODEL --sort SIZE 2>/dev/null | grep -v "^loop")

    if [[ ${#CANDIDATES[@]} -eq 0 ]]; then
        echo "No uninitialized drives found."
        exit 0
    fi

    for i in "${!CANDIDATES[@]}"; do
        printf "  %2d)  %s\n" "$((i+1))" "${CANDIDATES[$i]}"
    done
    echo ""

    read -rp "Select drives to format (e.g. 1 2 3 or 1,2,3): " RAW_SEL
    IFS=', ' read -ra SELECTIONS <<< "$RAW_SEL"

    SELECTED_DEVS=()
    for sel in "${SELECTIONS[@]}"; do
        [[ -z "$sel" ]] && continue
        if ! [[ "$sel" =~ ^[0-9]+$ ]] || [[ "$sel" -lt 1 ]] || [[ "$sel" -gt "${#CANDIDATES[@]}" ]]; then
            echo ":: Invalid selection: $sel. Aborting. ::"
            exit 1
        fi
        SELECTED_DEVS+=("${CANDIDATES[$((sel-1))]}")
    done

    if [[ ${#SELECTED_DEVS[@]} -eq 0 ]]; then
        echo "No drives selected."
        exit 0
    fi

    echo ""
    echo ":: Selected ::"
    for dev in "${SELECTED_DEVS[@]}"; do
        echo "  $dev"
    done
    echo ""

    # Load current drives file
    CURRENT=$(nix eval --json -f "$DRIVES_FILE" 2>/dev/null \
        || echo '{"parity":[],"data":[],"cache":[]}')

    for dev in "${SELECTED_DEVS[@]}"; do
        DEV_NAME=$(echo "$dev" | awk '{print $1}')
        DEVICE="/dev/$DEV_NAME"

        echo ":: Role for $DEVICE ::"
        echo "   1) data    — mergerfs pool + snapraid"
        echo "   2) parity  — snapraid parity only"
        echo "   3) cache   — mergerfs pool only"
        while true; do
            read -rp "   Select [1-3]: " role_sel
            case "$role_sel" in
                1) ROLE="data";   break ;;
                2) ROLE="parity"; break ;;
                3) ROLE="cache";  break ;;
                *) echo "   Please enter 1, 2, or 3." ;;
            esac
        done

        # Auto-assign number: max existing number for this role + 1
        MAX_N=0
        while IFS= read -r label; do
            [[ -z "$label" ]] && continue
            N=$(echo "$label" | grep -oE '[0-9]+$' || echo "0")
            [[ "$N" -gt "$MAX_N" ]] && MAX_N="$N"
        done < <(echo "$CURRENT" | jq -r --arg r "$ROLE" '.[$r][]' 2>/dev/null || true)
        NEXT_N=$((MAX_N + 1))
        LABEL="bulk-${ROLE}-${NEXT_N}"

        echo ""
        echo "  $DEVICE  →  $LABEL"
        lsblk "$DEVICE" 2>/dev/null || true
        echo ""
        read -rp "  WIPE AND FORMAT $DEVICE as $LABEL? This is IRREVERSIBLE. [y/N]: " confirm
        if ! [[ "$confirm" =~ ^[yY]$ ]]; then
            echo "  Skipping $DEVICE."
            echo ""
            continue
        fi

        echo ":: Wiping $DEVICE ::"
        sudo wipefs -a "$DEVICE"

        echo ":: Partitioning $DEVICE ::"
        sudo parted -s "$DEVICE" mklabel gpt mkpart primary btrfs 0% 100%
        sleep 1
        sudo partprobe "$DEVICE" 2>/dev/null || true
        sleep 1

        PART=$(lsblk -n -o NAME "$DEVICE" | grep -v "^$DEV_NAME$" | head -1)
        if [[ -z "$PART" ]]; then
            echo ":: Error: could not detect partition on $DEVICE. ::"
            exit 1
        fi
        PARTITION="/dev/$PART"

        echo ":: Formatting $PARTITION as btrfs (label: $LABEL) ::"
        sudo mkfs.btrfs -L "$LABEL" -f "$PARTITION"

        echo ":: Creating @data and @snapshots subvolumes ::"
        TMPDIR=$(mktemp -d)
        sudo mount "$PARTITION" "$TMPDIR"
        sudo btrfs subvolume create "$TMPDIR/@data"
        sudo btrfs subvolume create "$TMPDIR/@snapshots"
        sudo umount "$TMPDIR"
        rmdir "$TMPDIR"

        case "$ROLE" in
            parity) CURRENT=$(echo "$CURRENT" | jq --arg l "$LABEL" '.parity += [$l]') ;;
            cache)  CURRENT=$(echo "$CURRENT" | jq --arg l "$LABEL" '.cache  += [$l]') ;;
            *)      CURRENT=$(echo "$CURRENT" | jq --arg l "$LABEL" '.data   += [$l]') ;;
        esac

        echo ":: $DEVICE formatted and registered as $LABEL ::"
        echo ""
    done

    # Write updated drives file
    mkdir -p "$(dirname "$DRIVES_FILE")"
    P=$(echo "$CURRENT" | jq -r '[.parity[]] | map("\"" + . + "\"") | join(" ")')
    D=$(echo "$CURRENT" | jq -r '[.data[]]   | map("\"" + . + "\"") | join(" ")')
    C=$(echo "$CURRENT" | jq -r '[.cache[]]  | map("\"" + . + "\"") | join(" ")')

    cat > "$DRIVES_FILE" <<NIXEOF
# Managed by ft drives-format and ft drives-sync. Clear with ft drives-clear.
{
  parity = [ $P ];
  data   = [ $D ];
  cache  = [ $C ];
}
NIXEOF

    echo ":: $DRIVES_FILE updated. ::"
    echo ":: Review changes, commit, and run 'ft switch' to activate. ::"

# Reconcile bulk-drives.nix with /dev/disk/by-label/ — removes missing entries, registers untracked ones.
drives-sync:
    #!/usr/bin/env bash
    set -euo pipefail

    DRIVES_FILE="machines/$(hostname)/var/bulk-drives.nix"
    mkdir -p "$(dirname "$DRIVES_FILE")"

    echo ":: Syncing $DRIVES_FILE with /dev/disk/by-label/ ::"
    echo ""

    CURRENT=$(nix eval --json -f "$DRIVES_FILE" 2>/dev/null \
        || echo '{"parity":[],"data":[],"cache":[]}')
    NEW="$CURRENT"
    CHANGED=0

    mapfile -t REGISTERED < <(echo "$CURRENT" | jq -r '(.parity + .data + .cache)[]' 2>/dev/null || true)

    declare -A VISIBLE
    shopt -s nullglob
    for label_path in /dev/disk/by-label/bulk*; do
        VISIBLE["$(basename "$label_path")"]=1
    done

    # Remove registered drives that are no longer visible
    for label in "${REGISTERED[@]}"; do
        [[ -z "$label" ]] && continue
        if [[ -z "${VISIBLE[$label]+x}" ]]; then
            echo "  MISSING: $label (in $DRIVES_FILE but not found in /dev/disk/by-label/)"
            read -rp "  Remove $label from $DRIVES_FILE? [y/N]: " confirm
            if [[ "$confirm" =~ ^[yY]$ ]]; then
                NEW=$(echo "$NEW" | jq --arg l "$label" \
                    '.parity -= [$l] | .data -= [$l] | .cache -= [$l]')
                echo "  Removed: $label"
                CHANGED=1
            fi
        fi
    done

    # Register visible drives not yet in the file (e.g. after a manual label)
    for label in "${!VISIBLE[@]}"; do
        already=$(echo "$NEW" | jq -r --arg l "$label" \
            '(.parity + .data + .cache) | any(. == $l) | tostring')
        if [[ "$already" == "false" ]]; then
            echo "  UNREGISTERED: $label (visible but not in $DRIVES_FILE)"
            read -rp "  Register $label? [y/N]: " confirm
            if [[ "$confirm" =~ ^[yY]$ ]]; then
                if [[ "$label" == *parity* ]]; then
                    NEW=$(echo "$NEW" | jq --arg l "$label" '.parity += [$l]')
                elif [[ "$label" == *cache* ]]; then
                    NEW=$(echo "$NEW" | jq --arg l "$label" '.cache  += [$l]')
                else
                    NEW=$(echo "$NEW" | jq --arg l "$label" '.data   += [$l]')
                fi
                echo "  Registered: $label"
                CHANGED=1
            fi
        fi
    done

    if [[ $CHANGED -gt 0 ]]; then
        P=$(echo "$NEW" | jq -r '[.parity[]] | map("\"" + . + "\"") | join(" ")')
        D=$(echo "$NEW" | jq -r '[.data[]]   | map("\"" + . + "\"") | join(" ")')
        C=$(echo "$NEW" | jq -r '[.cache[]]  | map("\"" + . + "\"") | join(" ")')

        cat > "$DRIVES_FILE" <<NIXEOF
# Managed by ft drives-format and ft drives-sync. Clear with ft drives-clear.
{
  parity = [ $P ];
  data   = [ $D ];
  cache  = [ $C ];
}
NIXEOF
        echo ":: $DRIVES_FILE updated. Commit and run 'ft switch' to apply. ::"
    else
        echo ":: No changes needed. ::"
    fi

# Show registered drives and drives currently visible in /dev/disk/by-label/.
drives-list:
    #!/usr/bin/env bash
    set -euo pipefail

    DRIVES_FILE="machines/$(hostname)/var/bulk-drives.nix"

    echo ":: Registered drives ($DRIVES_FILE) ::"
    if [[ -f "$DRIVES_FILE" ]]; then
        cat "$DRIVES_FILE"
    else
        echo "  (file not found — run 'ft drives-format' or 'ft drives-sync')"
    fi

    echo ""
    echo ":: Currently visible in /dev/disk/by-label/ ::"
    shopt -s nullglob
    found=(/dev/disk/by-label/bulk*)
    if [[ ${#found[@]} -gt 0 ]]; then
        for f in "${found[@]}"; do
            label=$(basename "$f")
            dev=$(readlink -f "$f")
            echo "  $label  →  $dev"
        done
    else
        echo "  (none)"
    fi

# Clear all drive records (with confirmation). Commit and run 'ft switch' after.
drives-clear:
    #!/usr/bin/env bash
    set -euo pipefail

    DRIVES_FILE="machines/$(hostname)/var/bulk-drives.nix"

    echo ":: This will erase all drive records from $DRIVES_FILE. ::"
    echo ":: SnapRAID parity will no longer be able to reference these drives. ::"
    read -rp "Clear all records? [y/N]: " confirm
    if [[ "$confirm" =~ ^[yY]$ ]]; then
        cat > "$DRIVES_FILE" <<'NIXEOF'
# Managed by ft drives-format and ft drives-sync. Clear with ft drives-clear.
{
  parity = [ ];
  data   = [ ];
  cache  = [ ];
}
NIXEOF
        echo ":: $DRIVES_FILE cleared. Commit and run 'ft switch' to apply. ::"
    else
        echo "Cancelled."
    fi
