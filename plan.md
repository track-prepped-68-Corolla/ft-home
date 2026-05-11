Context — Branch cleanup before merge to main
Three tasks to complete on claude/module-integration before merging both repos to main:
Delete all .bak files (dead weight from the reconciliation pass)
Move kernel.nix (CachyOS) from nixos-config → ft-home (it's generic — no hardcodes)
Add a default wallpaper path to ft.theme.wallpaper in ft-home's stylix.nix
.bak files to delete — nixos-config claude/module-integration
modules/nixos/system/cosmic.nix.bak
modules/nixos/system/rclone.nix.bak
modules/nixos/system/stylix.nix.bak
modules/nixos/hardware/gpu.nix.bak
kernel.nix — move to ft-home
Create modules/nixos/system/kernel.nix in ft-home with the existing content from nixos-config (verbatim — no changes needed). inputs.nix-cachyos is already declared in ft-home's flake.nix so the reference resolves correctly.
Delete modules/nixos/system/kernel.nix from nixos-config.
stylix.nix — add wallpaper default
In ft-home modules/home/stylix.nix, change the wallpaper option from no-default (required) to:
Nix
ft.dotfiles.path evaluates to ${ft.repoPath}/homes/${username}/dotfiles, so ../wallpapers/default.jpg resolves to homes/<user>/wallpapers/default.jpg in the consumer's repo. Consumers who set ft.theme.wallpaper explicitly (like joe does) are unaffected.
Wallpaper asset — relocate pixel-planet.png
modules/home/pixel-planet.png needs to move to homes/joe/wallpapers/default.jpg in nixos-config, establishing the convention the new default path expects.
Steps:
Read modules/home/pixel-planet.png (binary, base64 via GitHub API)
Create homes/joe/wallpapers/default.png with that content
Delete modules/home/pixel-planet.png
In homes/joe/default.nix, remove the explicit ft.theme.wallpaper line — the stylix default will resolve to the new location
Critical files
ft-home: modules/nixos/system/kernel.nix (new), modules/home/stylix.nix (wallpaper default)
nixos-config: 4 .bak deletions, modules/nixos/system/kernel.nix deletion, modules/home/pixel-planet.png deletion, homes/joe/wallpapers/default.jpg (new), homes/joe/default.nix (remove explicit wallpaper override)
After this
Merge both claude/module-integration branches to main, then open new branches for docs/formatting/linting/quality pipeline.