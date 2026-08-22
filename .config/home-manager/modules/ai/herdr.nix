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
{ config, pkgs, ... }:
let
  custom = import ../../pkgs { inherit pkgs; };
in
{
  home.activation.herdrClaudeIntegration = config.lib.dag.entryAfter [ "claudeSettings" ] ''
    ${custom.herdr}/bin/herdr integration install claude
  '';
}
