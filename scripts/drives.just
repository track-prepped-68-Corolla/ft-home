# --- Bulk Drive Management ---
#
# Drives are formatted with a btrfs label starting with "bulk-":
#   bulk-data-N    → mergerfs pool + snapraid data
#   bulk-parity-N  → snapraid parity (not in pool)
#   bulk-cache-N   → mergerfs pool only (not in snapraid)
#
# After adding or scanning drives, commit the updated var/bulk-drives.nix
# and run `ft switch` to activate the new configuration.

DRIVES_FILE := "machines/" + `hostname` + "/var/bulk-drives.nix"

# Format a drive, create btrfs subvolumes, and register it. Interactive — no arguments needed.
drives-format:
    #!/usr/bin/env bash
    set -euo pipefail

    DRIVES_FILE="machines/$(hostname)/var/bulk-drives.nix"

    echo ":: Available block devices ::"
    echo ""
    mapfile -t DEVICES < <(lsblk -d -n -o NAME,SIZE,MODEL --sort SIZE 2>/dev/null | grep -v "^loop")
    if [[ ${#DEVICES[@]} -eq 0 ]]; then
      echo "No block devices found."
      exit 1
    fi
    for i in "${!DEVICES[@]}"; do
      printf "  %2d)  %s\n" "$((i+1))" "${DEVICES[$i]}"
    done
    echo ""

    read -rp "Select device number: " sel
    if ! [[ "$sel" =~ ^[0-9]+$ ]] || [[ "$sel" -lt 1 ]] || [[ "$sel" -gt "${#DEVICES[@]}" ]]; then
      echo ":: Invalid selection. ::"
      exit 1
    fi
    DEV_NAME=$(echo "${DEVICES[$((sel-1))]}" | awk '{print $1}')
    DEVICE="/dev/$DEV_NAME"

    echo ""
    echo ":: Selected: $DEVICE ::"
    lsblk "$DEVICE" 2>/dev/null || true
    echo ""
    read -rp "WIPE AND FORMAT $DEVICE? This is IRREVERSIBLE. [y/N]: " confirm
    [[ "$confirm" =~ ^[yY]$ ]] || { echo "Cancelled."; exit 0; }

    echo ""
    echo ":: Label convention: bulk-data-N, bulk-parity-N, bulk-cache-N ::"
    read -rp "Enter btrfs label (must start with 'bulk-'): " LABEL
    if [[ "$LABEL" != bulk-* ]]; then
      echo ":: Error: label must start with 'bulk-'. ::"
      exit 1
    fi

    echo ""
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

    echo ":: Drive $LABEL ready ::"
    echo ""

    # Determine role from label substring
    if [[ "$LABEL" == *parity* ]]; then
      ROLE="parity"
    elif [[ "$LABEL" == *cache* ]]; then
      ROLE="cache"
    else
      ROLE="data"
    fi

    echo ":: Registering $LABEL as $ROLE drive in $DRIVES_FILE ::"
    mkdir -p "$(dirname "$DRIVES_FILE")"

    CURRENT=$(nix eval --json -f "$DRIVES_FILE" 2>/dev/null \
      || echo '{"parity":[],"data":[],"cache":[]}')

    case "$ROLE" in
      parity) NEW=$(echo "$CURRENT" | jq --arg l "$LABEL" '.parity += [$l] | .parity |= unique') ;;
      cache)  NEW=$(echo "$CURRENT" | jq --arg l "$LABEL" '.cache  += [$l] | .cache  |= unique') ;;
      *)      NEW=$(echo "$CURRENT" | jq --arg l "$LABEL" '.data   += [$l] | .data   |= unique') ;;
    esac

    P=$(echo "$NEW" | jq -r '[.parity[]] | map("\"" + . + "\"") | join(" ")')
    D=$(echo "$NEW" | jq -r '[.data[]]   | map("\"" + . + "\"") | join(" ")')
    C=$(echo "$NEW" | jq -r '[.cache[]]  | map("\"" + . + "\"") | join(" ")')

    {
      echo "# Managed by ft drives-format and ft drives-scan. Clear with ft drives-clear."
      echo "{"
      echo "  parity = [ $P ];"
      echo "  data   = [ $D ];"
      echo "  cache  = [ $C ];"
      echo "}"
    } > "$DRIVES_FILE"

    echo ":: $DRIVES_FILE updated. ::"
    echo ":: Review changes, commit, and run 'ft switch' to activate. ::"

# Scan /dev/disk/by-label/ for unlisted bulk* drives and register them.
drives-scan:
    #!/usr/bin/env bash
    set -euo pipefail

    DRIVES_FILE="machines/$(hostname)/var/bulk-drives.nix"
    mkdir -p "$(dirname "$DRIVES_FILE")"

    echo ":: Scanning /dev/disk/by-label/ for bulk* drives ::"

    CURRENT=$(nix eval --json -f "$DRIVES_FILE" 2>/dev/null \
      || echo '{"parity":[],"data":[],"cache":[]}')
    NEW="$CURRENT"
    ADDED=0

    shopt -s nullglob
    for label_path in /dev/disk/by-label/bulk*; do
      LABEL=$(basename "$label_path")

      already=$(echo "$NEW" | jq -r --arg l "$LABEL" \
        '(.parity + .data + .cache) | map(. == $l) | any | tostring')
      if [[ "$already" == "true" ]]; then
        echo "  Already registered: $LABEL"
        continue
      fi

      if [[ "$LABEL" == *parity* ]]; then
        NEW=$(echo "$NEW" | jq --arg l "$LABEL" '.parity += [$l]')
      elif [[ "$LABEL" == *cache* ]]; then
        NEW=$(echo "$NEW" | jq --arg l "$LABEL" '.cache  += [$l]')
      else
        NEW=$(echo "$NEW" | jq --arg l "$LABEL" '.data   += [$l]')
      fi

      echo "  Found and registered: $LABEL"
      ADDED=$((ADDED + 1))
    done

    if [[ "$ADDED" -gt 0 ]]; then
      P=$(echo "$NEW" | jq -r '[.parity[]] | map("\"" + . + "\"") | join(" ")')
      D=$(echo "$NEW" | jq -r '[.data[]]   | map("\"" + . + "\"") | join(" ")')
      C=$(echo "$NEW" | jq -r '[.cache[]]  | map("\"" + . + "\"") | join(" ")')

      {
        echo "# Managed by ft drives-format and ft drives-scan. Clear with ft drives-clear."
        echo "{"
        echo "  parity = [ $P ];"
        echo "  data   = [ $D ];"
        echo "  cache  = [ $C ];"
        echo "}"
      } > "$DRIVES_FILE"
      echo ":: $ADDED new drive(s) registered. Commit and run 'ft switch' to activate. ::"
    else
      echo ":: No new drives found. ::"
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
      echo "  (file not found — run 'ft drives-scan' or 'ft drives-format')"
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
      {
        echo "# Managed by ft drives-format and ft drives-scan. Clear with ft drives-clear."
        echo "{"
        echo "  parity = [ ];"
        echo "  data   = [ ];"
        echo "  cache  = [ ];"
        echo "}"
      } > "$DRIVES_FILE"
      echo ":: $DRIVES_FILE cleared. Commit and run 'ft switch' to apply. ::"
    else
      echo "Cancelled."
    fi
