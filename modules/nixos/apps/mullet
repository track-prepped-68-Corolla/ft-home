MULLET_FILE := "nixos/modules/apps/mullet.txt"

@search query:
    #!/usr/bin/env bash
    echo ":: Searching Nix-Index for binary '{{query}}' ::"
    RESULTS=$(nix-locate --top-level --minimal --at-root "/bin/{{query}}")
    
    if [ -n "$RESULTS" ]; then
      echo "$RESULTS"
    else
      echo ":: No exact binary match in Nix-Index. ::"
      echo ":: Searching Nixpkgs descriptions... ::"
      nix search nixpkgs "{{query}}" | head -n 15
    fi

@add pkg:
    #!/usr/bin/env bash
    set -e
    
    # 1. Check if it's already in the file
    if grep -q "^[[:space:]]*{{pkg}}[[:space:]]*$" "{{MULLET_FILE}}"; then
      echo ":: '{{pkg}}' is already in The Mullet. ::"
      exit 0
    fi

    echo ":: Verifying '{{pkg}}' exists... ::"
    
    # 2. Fast validation (supports unfree packages)
    if ! NIXPKGS_ALLOW_UNFREE=1 nix eval --impure "nixpkgs#{{pkg}}" --apply "p: p.outPath or p.pname or p.name" &>/dev/null; then
      echo ":: Error: '{{pkg}}' is not a valid package path. ::"
      
      # 3. INTERACTIVE INLINE FUZZY MENU
      if command -v fzf &> /dev/null; then
        echo ":: Launching fuzzy finder... ::"
        
        # Added --height 40% to make it inline, and --layout=reverse to put the prompt on top
        SELECTED=$(nix-locate --minimal --regex "^/bin/" \
          | sed 's/\.[^.]*$//' \
          | sort -u \
          | fzf --height 40% --layout=reverse --prompt="Pick a package > " -q "{{pkg}}")
        
        if [ -n "$SELECTED" ]; then
          echo ":: You selected: $SELECTED ::"
          
          # Check if the new selection is already in the file
          if grep -q "^[[:space:]]*$SELECTED[[:space:]]*$" "{{MULLET_FILE}}"; then
            echo ":: '$SELECTED' is already in The Mullet. ::"
            exit 0
          fi
          
          # Append the selected package instead of the original typo
          echo "$SELECTED" >> "{{MULLET_FILE}}"
          echo ":: Added $SELECTED. Run 'ft switch' to apply. ::"
          exit 0
        else
          echo ":: Selection cancelled. ::"
          exit 1
        fi
      else
        echo ":: (Install 'fzf' for the interactive selection menu!) ::"
        echo ":: Searching Nix-Index for '{{pkg}}' (Regex Match) ::"
        echo ""
        nix-locate --minimal --regex "/bin/.*{{pkg}}.*" | head -n 10
        
        echo ""
        echo ":: (Fallback) Searching Nixpkgs descriptions... ::"
        SEARCH_RESULTS=$(nix search nixpkgs "{{pkg}}" 2>/dev/null | head -n 10)
        
        if [ -z "$SEARCH_RESULTS" ]; then
          echo "  No exact description results found."
        else
          echo "$SEARCH_RESULTS"
        fi
        exit 1
      fi
    fi

    # 4. Append to the flat file (if they spelled it correctly the first time)
    echo "{{pkg}}" >> "{{MULLET_FILE}}"
    echo ":: Added {{pkg}}. Run 'ft switch' to apply. ::"

@rm pkg:
    #!/usr/bin/env bash
    set -e
    
    # 1. Check for an exact match first
    if grep -q "^[[:space:]]*{{pkg}}[[:space:]]*$" "{{MULLET_FILE}}"; then
      sed -i "/^[[:space:]]*{{pkg}}[[:space:]]*$/d" "{{MULLET_FILE}}"
      echo ":: Removed {{pkg}}. Run 'ft switch' to apply. ::"
      exit 0
    fi

    # 2. If no exact match, launch interactive fuzzy menu (if fzf is installed and file isn't empty)
    if command -v fzf &> /dev/null && [ -s "{{MULLET_FILE}}" ]; then
      echo ":: '{{pkg}}' not found. Launching fuzzy finder... ::"
      
      # Feeds your installed Mullet packages directly into fzf
      SELECTED=$(cat "{{MULLET_FILE}}" | fzf --height 40% --layout=reverse --prompt="Remove > " -q "{{pkg}}")
      
      if [ -n "$SELECTED" ]; then
        sed -i "/^[[:space:]]*$SELECTED[[:space:]]*$/d" "{{MULLET_FILE}}"
        echo ":: Removed $SELECTED. Run 'ft switch' to apply. ::"
      else
        echo ":: Removal cancelled. ::"
        exit 1
      fi
    else
      echo ":: Error: '{{pkg}}' not found in The Mullet. ::"
      exit 1
    fi

@lst:
    echo ":: Imperative Packages (The Mullet) ::"
    cat "{{MULLET_FILE}}" || echo "  (Empty)"

@haircut:
    #!/usr/bin/env bash
    read -p "This removes all imperative packages. Continue? [y/N]: " choice
    if [[ "$choice" =~ ^[yY]$ ]]; then
      > "{{MULLET_FILE}}"
      echo ":: Haircut complete. Run 'ft switch' to apply the clean slate. ::"
    else
      echo "Cancelled."
    fi