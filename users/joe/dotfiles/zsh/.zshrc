fastfetch --logo nixos --structure Title:Separator:OS:Host:Kernel:Uptime:Packages:Shell:Display:DE:WM:Terminal:CPU:GPU:Memory:Break:Colors

# --- Aliases ---
alias ls='eza --icons --group-directories-first'
alias ll='eza --icons --group-directories-first -l'
alias la='eza --icons --group-directories-first -la'
alias lt='eza --icons --group-directories-first --tree'
alias cat='bat --paging=never'
alias top='btop'
alias du='dust'
alias grep='rg'
alias lg='lazygit'

# --- Keybinds ---
bindkey '^[[1;5C' forward-word   # ctrl+right
bindkey '^[[1;5D' backward-word  # ctrl+left
bindkey '^[[3~' delete-char      # delete
