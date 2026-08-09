# WezTerm cheatsheet

Config lives in `.config/wezterm/wezterm.lua`. Two key layers:

- **`Ctrl+Shift`** — the bindings carried over from kitty, so old muscle memory still works.
- **`Ctrl+a`** (LEADER) — tmux-style prefix for everything multiplexer-related.

Press LEADER, release, then the next key. One second timeout.
`Ctrl+a` `Ctrl+a` sends a literal `Ctrl+a` (beginning-of-line in zsh).

## Panes

| Key | Does |
|---|---|
| `LEADER %` | split left/right |
| `LEADER "` | split top/bottom |
| `LEADER h/j/k/l` | focus pane left/down/up/right |
| `LEADER H/J/K/L` | resize pane by 5 |
| `LEADER z` | zoom / unzoom current pane |
| `LEADER x` | close pane (asks first) |
| `LEADER Space` | pane picker — type the label to jump |
| `Ctrl+Shift+Enter` | split left/right |
| `Ctrl+Shift+w` | close pane |
| `Ctrl+Shift+[` / `]` | previous / next pane |
| `Ctrl+Shift+f` / `b` | rotate panes clockwise / counter-clockwise |

## Tabs

| Key | Does |
|---|---|
| `LEADER c` | new tab |
| `LEADER n` / `p` | next / previous tab |
| `LEADER 1`–`9` | jump to tab 1–9 |
| `LEADER ,` | rename tab |
| `Ctrl+Shift+t` | new tab |
| `Ctrl+Shift+q` | close tab (asks first) |
| `Ctrl+Shift+←` / `→` | previous / next tab |

The tab bar is hidden while there is only one tab. With two or more you get a
slim bar showing the tab list, with the active workspace name on the right.

## Workspaces

A workspace is a named set of tabs/panes — the thing sessions are saved from.

| Key | Does |
|---|---|
| `LEADER w` | fuzzy workspace switcher |
| `LEADER $` | rename current workspace |

## Sessions (resurrect)

State lives in `~/.local/state/wezterm/resurrect/`.

| Key | Does |
|---|---|
| `LEADER s` | save current workspace now |
| `LEADER r` | fuzzy-pick a saved workspace/window/tab and restore it |
| `LEADER d` | delete a saved state |

The active workspace is auto-saved every 5 minutes, and the last one is
restored automatically when WezTerm starts with no command. Launching with an
explicit command (`wezterm start -- nvim`, the Hyprland `SUPER+R` bind, the
waybar click handlers) runs that command instead of restoring.

Panes are restored with their scrollback text, but **not** the processes that
were running in them — a restored pane is a fresh shell in the right directory.

## Copy / select

| Key | Does |
|---|---|
| `LEADER [` | enter copy mode (vi-ish: `h/j/k/l`, `v` select, `y` yank, `q` exit) |
| `Ctrl+Shift+c` / `v` | copy / paste |
| `Ctrl+Shift+p` | quick select — labels every match on screen, type the label to copy |
| `Ctrl+Shift+o` | quick select, restricted to URLs, opens the one you pick |
| `Ctrl+Shift+u` | character / emoji picker |

## Font size

`Ctrl+Shift+=` bigger, `Ctrl+Shift+-` smaller, `Ctrl+Shift+Backspace` reset.

## Useful WezTerm defaults (not set by us, still available)

| Key | Does |
|---|---|
| `Ctrl+Shift+r` | reload config |
| `Ctrl+Shift+l` | debug overlay — where Lua errors and `wezterm.log_*` output show up |
| `Ctrl+Shift+k` | clear scrollback |
| `Ctrl+Shift+n` | new OS window |

## Maintenance notes

Changing the config does **not** affect an already-running WezTerm in every
case; after a rebuild, `pkill -x wezterm-gui` then relaunch.

To check a config edit before committing to it:

```sh
env -u WAYLAND_DISPLAY -u DISPLAY wezterm-gui start
```

It prints any `Configuration Error` and then exits on the missing display.
This matters because `wezterm show-keys` and `wezterm ls-fonts` both load the
config *without* rejecting invalid fields — and on a config error WezTerm
silently falls back to stock defaults, which looks like "my config was
ignored" (default tab bar reappears, transparency gone).
