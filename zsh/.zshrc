# Path to Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# environment / PATH
[[ -f ~/.zsh_path ]] && source ~/.zsh_path


export EDITOR=nvim

if [[ "$(uname)" == "Linux" ]]; then
    export XDG_DATA_DIRS=/var/lib/snapd/desktop/:$XDG_DATA_DIRS
fi

export VAGRANT_DEFAULT_PROVIDER=virtualbox
# export VAGRANT_DEFAULT_PROVIDER=libvirt
# export DOCKER_HOST=unix:///var/run/docker.sock

export KUBECONFIG=~/.kube/config

# tmux
export ZSH_TMUX_AUTOSTART=true

export CROSS_CONTAINER_ENGINE=podman

if [[ "$(uname)" == "Linux" ]]; then
    export LIBVIRT_DEFAULT_URI=qemu:///system
fi

ZSH_THEME="agnoster"
zstyle ':omz:update' mode auto

plugins=(git tmux colorize podman)

source $ZSH/oh-my-zsh.sh

# starship
eval "$(starship init zsh)"

# NVM (lazy-loaded for faster startup)
export NVM_DIR="$HOME/.nvm"
nvm() {
    unset -f nvm node npm npx
    [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && source "$NVM_DIR/bash_completion"
    nvm "$@"
}
node() { nvm; node "$@"; }
npm()  { nvm; npm  "$@"; }
npx()  { nvm; npx  "$@"; }

# increase node.js max memory
export NODE_OPTIONS=--max_old_space_size=4096

# Nix profile (special handling - keep separate)
if [ -e $HOME/.nix-profile/etc/profile.d/nix.sh ]; then . $HOME/.nix-profile/etc/profile.d/nix.sh; fi # added by Nix installer

# User aliases
[[ -f ~/.zsh_aliases ]] && source ~/.zsh_aliases
