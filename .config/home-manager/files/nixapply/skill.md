---
name: nixapply
description: Apply and verify a NixOS/home-manager config change in ~/Projects/.dotfiles
---

This system's home-manager runs as a NixOS module (not standalone), so the
one rebuild command applies both NixOS and home-manager config, including
everything under `.config/home-manager/` (Claude Code settings, MCP servers,
skills, hooks). Never edit `~/.claude/settings.json`, `~/.claude.json`, or
`~/.claude/skills/**` directly — they are generated/symlinked from this repo
and get overwritten on the next rebuild.

Follow every step. Do not skip to "done" without the command output proving it.

1. Run `git -C ~/Projects/.dotfiles diff` (and `git status`) and summarize
   what changed and why.
2. Validate every changed `.nix` file with `nix-instantiate --parse <file>`
   and every changed `.json`/`.jsonc` file with `jq . <file>`. Fix any
   failure before continuing.
3. Rebuild: `sudo cp -r ~/Projects/.dotfiles/nixos/* /etc/nixos/ && sudo nixos-rebuild switch`.
   This needs sudo — if it can't be run non-interactively, stop and print the
   exact command for the user to run themselves, then wait for them to
   confirm it succeeded (and paste the output if it failed).
4. Verify the GENERATED file actually changed, not just the source — e.g.
   `cat ~/.claude/settings.json`, `cat ~/.claude.json`, `ls ~/.claude/skills/`,
   `readlink -f ~/.claude/hooks/<name>`. A clean rebuild with no diff in the
   generated output means the change didn't actually land.
5. Reload whatever runtime service the change affects: `hyprctl reload` for
   Hyprland config, restart waybar via its Hyprland exec-once dispatch (not
   `killall -SIGUSR2 waybar`) for waybar config, or `/mcp restart` / a fresh
   Claude Code session for MCP server / hook / skill changes.
6. Report PASS/FAIL per step above, each backed by the command output you
   actually saw. Anything unverified goes in its own "UNVERIFIED" line — do
   not fold it into a success claim.
