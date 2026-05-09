# --- Entrypoint Router ---

# Store a program's configuration. Use '-a' or '--all' to scan and store all unmanaged apps.
store +ARGS="":
    #!/usr/bin/env bash
    if [[ "{{ARGS}}" == "-a" || "{{ARGS}}" == "--all" ]]; then
        just --justfile "{{justfile()}}" _store_all
    elif [[ -n "{{ARGS}}" ]]; then
        just --justfile "{{justfile()}}" _store_single {{ARGS}}
    else
        echo "Usage:"
        echo "  ft store <app-name>    (Store a specific app)"
        echo "  ft store -a            (Scan and store all known apps)"
        echo "  ft store-custom ...    (Create a custom app config)"
    fi

# --- Core Commands ---

# Create a local Mackup config for custom/unlisted apps and immediately store them
store-custom APP_NAME +PATHS:
    #!/usr/bin/env bash
    set -euo pipefail

    APP="{{APP_NAME}}"
    REPO="${FT_REPO_PATH:-$HOME/git/ft-home}"
    LOCAL_DB="$REPO/mackup-local"
    
    mkdir -p "$LOCAL_DB"
    CFG_FILE="$LOCAL_DB/${APP}.cfg"
    
    echo ":: Generating local config for '$APP' ::"
    
    echo "[application]" > "$CFG_FILE"
    echo "name = $APP" >> "$CFG_FILE"
    echo "" >> "$CFG_FILE"
    echo "[configuration_files]" >> "$CFG_FILE"
    
    for PATH_ARG in {{PATHS}}; do
        REL_PATH="${PATH_ARG#$HOME/}"
        REL_PATH="${REL_PATH#/}"
        echo "$REL_PATH" >> "$CFG_FILE"
        echo "  [ADDED] $REL_PATH"
    done
    
    echo ":: Local config saved to $CFG_FILE ::"
    just --justfile "{{justfile()}}" _store_single "$APP"

# --- Private Worker Recipes ---

# Handles a single application (checks local, then upstream)
_store_single APP_NAME:
    #!/usr/bin/env bash
    set -euo pipefail

    APP="{{APP_NAME}}"
    REPO="${FT_REPO_PATH:-$HOME/git/ft-home}"
    DOTFILES="$REPO/homes/$USER/dotfiles"
    LOCAL_DB="$REPO/mackup-local"
    CFG_FILE="/tmp/mackup-${APP}.cfg"
    
    # 1. Check local database first
    if [ -f "$LOCAL_DB/${APP}.cfg" ]; then
        cp "$LOCAL_DB/${APP}.cfg" "$CFG_FILE"
    else
        # 2. Fetch from official Mackup database
        if ! curl -sSL -f -o "$CFG_FILE" "https://raw.githubusercontent.com/lra/mackup/master/mackup/applications/${APP}.cfg"; then
            echo ":: Error: App '$APP' not found in Mackup database. ::"
            echo ":: Use 'ft store-custom $APP <path1> <path2>' to create a local config. ::"
            exit 1
        fi
    fi

    # Pass the config file to the processor
    just --justfile "{{justfile()}}" _process_cfg "$APP" "$CFG_FILE"

# Scans the entire system for unmanaged configurations
_store_all:
    #!/usr/bin/env bash
    set -euo pipefail

    REPO="${FT_REPO_PATH:-$HOME/git/ft-home}"
    LOCAL_DB="$REPO/mackup-local"
    TMP_DIR=$(mktemp -d)
    trap 'rm -rf "$TMP_DIR"' EXIT

    echo ":: Downloading official Mackup database for bulk scan (this takes a few seconds)... ::"
    curl -sSL https://github.com/lra/mackup/archive/master.tar.gz | tar -xz -C "$TMP_DIR"
    
    mkdir -p "$TMP_DIR/merged_db"
    
    # Copy upstream configs first
    if [ -d "$TMP_DIR/mackup-master/mackup/applications" ]; then
        cp "$TMP_DIR/mackup-master/mackup/applications/"*.cfg "$TMP_DIR/merged_db/" 2>/dev/null || true
    fi
    
    # Overwrite with local custom configs
    if [ -d "$LOCAL_DB" ]; then
        cp "$LOCAL_DB/"*.cfg "$TMP_DIR/merged_db/" 2>/dev/null || true
    fi

    echo ":: Scanning home directory against $(ls -1 "$TMP_DIR/merged_db"/*.cfg | wc -l) app profiles... ::"
    
    APPS_PROCESSED=0

    for CFG_FILE in "$TMP_DIR/merged_db"/*.cfg; do
        [ -e "$CFG_FILE" ] || continue
        APP=$(basename "$CFG_FILE" .cfg)
        APP_NEEDS_SYNC=false
        
        # Fast-pass check: Do any files exist and lack symlinks?
        SECTION=""
        while IFS= read -r line || [[ -n "$line" ]]; do
            line="${line%$'\r'}"
            if [[ -z "$line" ]]; then continue; fi
            if [[ "$line" =~ ^\[(.*)\]$ ]]; then SECTION="${BASH_REMATCH[1]}"; continue; fi

            if [[ "$SECTION" == "configuration_files" ]]; then
                SRC="$HOME/$line"
            elif [[ "$SECTION" == "xdg_configuration_files" ]]; then
                SRC="${XDG_CONFIG_HOME:-$HOME/.config}/$line"
            else
                continue
            fi

            # If the file exists AND is not a symlink, flag it for processing
            if [ -e "$SRC" ] && [ ! -L "$SRC" ]; then
                APP_NEEDS_SYNC=true
                break 
            fi
        done < "$CFG_FILE"

        # If flagged, hand it off to the processor
        if [ "$APP_NEEDS_SYNC" = true ]; then
            APPS_PROCESSED=$((APPS_PROCESSED + 1))
            just --justfile "{{justfile()}}" _process_cfg "$APP" "$CFG_FILE"
        fi
    done

    if [ "$APPS_PROCESSED" -eq 0 ]; then
        echo ":: All known application configs are already managed by Nix! ::"
    else
        echo ":: Successfully processed $APPS_PROCESSED apps. Run 'ft switch' to lock in the symlinks via Nix. ::"
    fi

# The engine that actually moves files and creates temp symlinks
_process_cfg APP CFG_FILE:
    #!/usr/bin/env bash
    set -euo pipefail

    APP="{{APP}}"
    CFG_FILE="{{CFG_FILE}}"
    REPO="${FT_REPO_PATH:-$HOME/git/ft-home}"
    DOTFILES="$REPO/homes/$USER/dotfiles"
    
    echo ":: Storing $APP into $DOTFILES ::"

    SECTION=""
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%$'\r'}"
        if [[ -z "$line" ]]; then continue; fi

        if [[ "$line" =~ ^\[(.*)\]$ ]]; then
            SECTION="${BASH_REMATCH[1]}"
            continue
        fi

        if [[ "$SECTION" == "configuration_files" ]]; then
            SRC="$HOME/$line"
            DEST="$DOTFILES/$line"
        elif [[ "$SECTION" == "xdg_configuration_files" ]]; then
            SRC="${XDG_CONFIG_HOME:-$HOME/.config}/$line"
            DEST="$DOTFILES/.config/$line"
        else
            continue
        fi

        if [ -e "$SRC" ] && [ ! -L "$SRC" ]; then
            echo "  [MOVE] ~/${SRC#$HOME/} -> $DEST"
            mkdir -p "$(dirname "$DEST")"
            mv "$SRC" "$DEST"
            ln -sf "$DEST" "$SRC"
        elif [ -L "$SRC" ]; then
            # Supress output for already symlinked files during bulk scans to keep logs clean
            true
        fi

    done < "$CFG_FILE"