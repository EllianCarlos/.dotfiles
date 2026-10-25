# Installs herdr's session-identity hook for Claude Code. Without this hook,
# herdr cannot read a pane's Claude Code session id. Collie then shows no
# History icon for that pane, because Collie gates it on `hasSession`
# (bridge/types.ts in AltanS/collie, keyed on herdr's agent_session report).
#
# Runs after claudeSettings on purpose, not before. Herdr's own installer
# merges its SessionStart hook entry into settings.json without touching
# other entries. The claudeSettings jq merge above replaces the whole
# hooks.SessionStart array instead of merging it (jq's `*` does not
# concatenate arrays), so if this ran first, the next `home-manager switch`
# would wipe herdr's entry straight back out.
#
# `herdr integration install claude` is safe to re-run: it writes the same
# hook file and settings entry every time and exits 0.
#
# Antigravity CLI gets the same treatment. It drops a standalone hook file
# (~/.gemini/config/hooks/) instead of writing into a settings.json this repo
# also manages, so it needs no entryAfter guard against antigravitySettings.
#
# Hermes runs after hermesAgentSetup, the Hermes module's own config.yaml
# merge, so that merge never rewrites what herdr installs.
#
# opencode is left out. Its installer refuses to run until
# ~/.config/opencode already exists (opencode itself creates that on first
# launch), so it is guarded rather than unconditional -- an unguarded call
# would fail `home-manager switch` on a machine that has never run opencode.
{ config, pkgs, ... }:
{
  home.activation.herdrClaudeIntegration = config.lib.dag.entryAfter [ "claudeSettings" ] ''
    ${pkgs.herdr}/bin/herdr integration install claude
  '';

  home.activation.herdrAntigravityIntegration = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.herdr}/bin/herdr integration install antigravity-cli
  '';

  home.activation.herdrHermesIntegration = config.lib.dag.entryAfter [ "hermesAgentSetup" ] ''
    ${pkgs.herdr}/bin/herdr integration install hermes
  '';

  home.activation.herdrOpencodeIntegration = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    if [ -d "$HOME/.config/opencode" ]; then
      ${pkgs.herdr}/bin/herdr integration install opencode
    fi
  '';
}
