repo-dir := "/etc/nixos"

bootstrap-user username:
    #!/usr/bin/env bash
    set -e
    
    echo "Setting up Home Manager for {{username}}..."
    
    # 1. Run the passwordless root wrapper
    # This handles the template copy, git add, and chown safely
    sudo hm-template-wrapper "{{username}}"
    
    # 2. Run the Home Manager switch as the normal user
    echo "Starting Home Manager switch..."
    cd "$HOME" && nix run home-manager/master -- switch --flake "{{repo-dir}}#{{username}}"
    
    # 3. Deactivate the autostart trigger
    echo "Deactivating autostart trigger..."
    mkdir -p "$HOME/.config/autostart"
    echo -e "[Desktop Entry]\nHidden=true" > "$HOME/.config/autostart/hm-bootstrap.desktop"
    
    echo "Done! Your home environment is ready."
    read -p "Press Enter to close this window..."
    