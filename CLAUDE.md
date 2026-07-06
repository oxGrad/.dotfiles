# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Dotfiles Manager

This repo uses [**knot**](github.com/oxGrad/knot) (dotfiles manager) configured via `Knotfile`. Each top-level directory is a package that gets symlinked to its `target` path.

```
knot tie --all       # symlink all packages
knot tie <package>   # symlink a single package
knot status          # preview what would change
```

Some packages are OS-conditional (e.g. `sway`, `waybar`, `wlogout`, `wofi`, `swaync` are Linux-only; `yabai` is macOS-only).

## Package Installation

```
make all             # update + upgrade + install base packages
make install-fonts   # copy fonts from assets/fonts/ to /usr/local/share/fonts/
make clean-nvim      # wipe neovim state/cache (useful when plugins break)
```

## Architecture

Each directory maps to a tool's config and is symlinked by knot:

| Directory   | Target              | Notes                                 |
| ----------- | ------------------- | ------------------------------------- |
| `nvim/`     | `~/.config/nvim`    | LazyVim-based config                  |
| `zsh/`      | `~/`                | `.zshrc`, `.zsh_aliases`, `.zsh_path` |
| `tmux/`     | `~/`                | `.tmux.conf`                          |
| `starship/` | `~/.config`         | `starship.toml`                       |
| `kitty/`    | `~/.config/kitty`   | terminal config                       |
| `ghostty/`  | `~/.config/ghostty` | terminal config                       |
| `k9s/`      | `~/.config/k9s`     | Kubernetes TUI                        |
| `sway/`     | `~/.config/sway`    | Linux WM (Wayland)                    |
| `waybar/`   | `~/.config/waybar`  | status bar for sway                   |
| `swaync/`   | `~/.config/swaync`  | notification center                   |

## Theme & Design System

Everything is themed **Monokai** (dark base `#272822`, text `bonewhite #faf9f6`):

- `waybar/colors.css` — canonical palette. Monokai hex values under Catppuccin-style names (`base`, `surface0-2`, `overlay0-2`, plus accents like `green #a6e22e`, `pink/red #f92672`, `sky #66d9ef`, `mauve #ae81ff`, `yellow #e2e22e`). Change colors here, not in `style.css`.
- `waybar/style.css` — "floating islands" bar: transparent window, rounded pill modules on `alpha(@base, 0.92)`. Design rule: **neutral `bonewhite` text everywhere; accent color only signals state** (charging, warning, critical, muted, disconnected).
- `starship/starship.toml` — capsule/powerline prompt built to visually match waybar; palette duplicated in `[palettes.monokai]` (keep in sync with `waybar/colors.css`).
- `swaync/style.css` — imports `waybar/colors.css`; control center follows the same island style (13px radius, `alpha(@base, 0.92)`, neutral text, color = state).
- `nvim/lua/plugins/monokai.lua` — `monokai-pro.nvim` with transparent background.
- `tmux/.tmux.conf` — `tmux-monokai-pro` plugin.

Font is JetBrains Mono / JetBrainsMono Nerd Font across terminals, waybar, and prompt.

## Zsh Config Split

The zsh config is split across three files that source each other in order:

- `.zsh_path` — all PATH management (sourced first from `.zshrc`)
- `.zshrc` — Oh My Zsh setup, exports, OS-specific aliases
- `.zsh_aliases` — all aliases (sourced last from `.zshrc`)

## Neovim Structure

Built on [LazyVim](https://lazyvim.github.io). Custom plugins live in `nvim/lua/plugins/`. Several AI plugins (`avante.lua`, `code-companion.lua`) are currently **disabled** with `if true then return {} end` at the top — remove that guard to enable them.

Formatters are configured in `nvim/lua/config/conform.lua`. LSP servers are managed via Mason (`nvim/lua/plugins/mason.lua`).

## Pre-commit Hooks

`gitleaks` runs on every commit to detect secrets. Install hooks before committing:

```
pip install pre-commit
pre-commit install
```

## Hardcoded Paths

Avoid absolute paths that embed usernames. Use `~` or `$HOME` instead. The only place this matters in practice is tmux-resurrect's `@resurrect-dir`.
