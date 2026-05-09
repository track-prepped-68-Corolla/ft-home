# ~/.config/nixos/justfile

# Suppress all command echoing globally for a cleaner terminal
set quiet := true


import "./mullet.just"
import "./store.just"

default:
    just --list

alias r  := switch
alias t  := test
alias c  := check
alias cl := clean
alias s  := sync

# --- 1. Maintenance & Checks ---

fmt:
    echo ":: Formatting ::"
    find . -name "*.nix" -exec nixfmt {} +

check: fmt
    echo ":: Scanning for leaked secrets ::"
    trufflehog git file://. --since-commit HEAD --fail 2>/dev/null

clean:
    echo ":: Cleaning Nix Store ::"
    nh clean all --keep 5

# --- 2. Testing ---

test: check
    #!/usr/bin/env bash
    just _check-reqs
    echo ":: Staging & Diffs ::"
    just _stage
    just _diff-src
    
    echo ":: Running Test ::"
    nh os test . --ask
    echo ":: Test complete. Reboot to revert. ::"

# --- 3. Core Workflow ---

switch: check
    #!/usr/bin/env bash
    set -e
    just _check-reqs

    echo ":: Previewing Build ::"
    just _stage
    nh os test . --dry
    
    echo ":: Source Code Changes ::"
    just _diff-src
    
    read -p "Apply and commit? [y/N]: " choice
    if [[ "$choice" =~ ^[yY]$ ]]; then
      # Capture current generation BEFORE building
      OLD_GEN=$(just _current-gen)
      
      # Build and switch
      nh os switch .
      
      # Extract new generation and diff packages
      GEN=$(just _current-gen)
      NVD_DIFF=$(nvd --color never diff $(just _last-two-gens))
      
      # Handle Git Commits (Triggers on ANY text change)
      if ! git diff --cached --quiet; then
          echo ""
          read -p "Commit message: " msg
          git commit -m "$msg" -m "Generation: $GEN" -m "$NVD_DIFF"
      else
          echo ":: No source changes detected. Skipping git commit. ::"
      fi
      
      # Handle Generation Cleanup (Triggers ONLY if Nix built a new system)
      if [ "$GEN" -gt "$OLD_GEN" ]; then
          just clean
      else
          echo ":: System generation did not change. Skipping cleanup. ::"
      fi
      
      echo ":: Update Complete! Now running Generation $GEN ::"
    else
      echo "Cancelled."
      exit 1
    fi

# --- 4. Remote Syncing ---

pull:
    echo ":: Pulling Updates ::"
    git pull --rebase --autostash
    
    echo ":: Incoming Source Changes ::"
    git diff HEAD@{1}..HEAD | delta --side-by-side
    
    echo ":: Building and Switching ::"
    nh os switch . --ask
    
    echo ":: System Package Changes ::"
    nvd diff $(just _last-two-gens)

push:
    #!/usr/bin/env bash
    if [[ -n $(git status --porcelain) ]]; then
      echo ":: Error: Uncommitted changes. Run 'just switch' or commit manually first. ::"
      exit 1
    fi
    echo ":: Pushing to Remote ::"
    git push

# --- 5. Full Sync ---

sync: pull push

# --- 6. Emergency Recovery ---

# Rollback to the immediate previous generation
rollback:
    #!/usr/bin/env bash
    echo ":: Current Generation ::"
    just _current-gen
    
    echo ":: Rolling back to previous generation ::"
    sudo nix-env --profile /nix/var/nix/profiles/system --rollback
    
    echo ":: Activating rolled-back system ::"
    sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch
    
    echo ":: Rollback Complete! ::"
    echo ":: Note: Your Git repo is still ahead. You may want to 'git reset' or fix the code. ::"

# --- 7. Internal Helpers (DRY) ---

_check-reqs:
    #!/usr/bin/env bash
    for cmd in nh nvd delta; do
      if ! command -v $cmd &> /dev/null; then echo "Error: $cmd is not installed."; exit 1; fi
    done

_stage:
    git add .

_diff-src:
    git diff --cached | delta --side-by-side

_current-gen:
    @readlink /nix/var/nix/profiles/system | cut -d'-' -f2

_last-two-gens:
    @ls -d1v /nix/var/nix/profiles/system-*-link | tail -n 2