# Neomutt cheatsheet

`vimKeys = true` (set in `home.nix`) only layers a handful of vi-style
navigation keys on top of neomutt's own keymap — it's not a full modal
editor. Here's what's actually bound.

## From vim-keys (movement only)

| Key | Does |
|---|---|
| `j` / `k` | down / up (in the pager) |
| `gg` / `G` | first / last message |
| `Ctrl-f` / `Ctrl-b` | page down / up |
| `Ctrl-d` / `Ctrl-u` | half-page down / up |
| `dd` | delete message (note: single `d` alone now does nothing — vim-keys rebinds it to wait for a second key) |
| `za` / `zA` | collapse thread / collapse all |

## Neomutt's own defaults (unchanged, day-to-day essentials)

| Key | Does |
|---|---|
| `Enter` | open the selected message |
| `q` | back out / quit |
| `r` | reply |
| `m` | compose new message |
| `c` | change mailbox/folder |
| `s` | save/move message to another folder |
| `u` | undelete (if you `dd`'d by mistake) |
| `/` | search |
| `?` | full keybinding list — the real reference, shows everything currently bound |

## Practical loop

Open neomutt → `j`/`k` to browse → `Enter` to read → `r` to reply (opens
`$EDITOR`, write below the quote, save+quit to send) → `q` back to index.
`?` any time you're stuck.

## Selecting and bulk-deleting

| Key | Does |
|---|---|
| `t` | tag/untag the message under the cursor |
| `T` | tag by pattern (prompts for a query, e.g. `~F` flagged, `.` matches all in view) |
| `Ctrl-t` | untag by pattern |
| `Esc t` | tag the whole thread |
| `;` | tag-prefix — next action applies to all tagged messages |

To bulk-delete: tag what you want (`t`/`T`), then `;dd` — the vim-keys
`dd` binding still resolves normally after the `;` tag-prefix flag is
set.

## Sort order

`set sort = "reverse-last-date-received"` (in `home.nix`'s
`programs.neomutt.extraConfig`) puts the newest message at index `1`,
oldest at the bottom. Live in-session: `o` opens the sort menu, `O`
opens it reversed.

## Gotchas

- **`set delete = ask-yes`** (in `home.nix`'s `programs.neomutt.extraConfig`)
  prompts for confirmation before purging deleted messages when you
  leave a mailbox or `mail_check` (60s) fires — still confirm promptly,
  since `u` only undeletes *before* the purge is confirmed.
- Pressing a single `d` under vim-keys does nothing (it's waiting for a
  second key). If `u` "isn't working," it's often because nothing was
  actually deleted in the first place — use `dd`, not `d`.
