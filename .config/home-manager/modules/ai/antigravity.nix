# Antigravity CLI (`agy`) configuration.
#
# Auth: uses the DEFAULT backend -- the user's Google (Antigravity) login,
# which carries Gemini Pro quota -- by NOT setting modelProvider. Setting
# modelProvider = "gemini" would force API-key auth and demand GEMINI_API_KEY
# (free-tier limits) in every environment, including non-interactive shunt
# workers. GEMINI_API_KEY stays exported in zsh only for opencode's google
# provider; agy does not read it anymore. Antigravity CLI splits its config
# across two files (unlike Claude Code / the old Gemini CLI, which keep
# mcpServers inside the main settings file):
#   - ~/.gemini/antigravity-cli/settings.json -- permissions, deep-merged
#     over whatever's on disk so unmanaged state survives. permissions.allow
#     is the union of hand-added rules and those translated from
#     permissions.nix; permissions.deny is replaced wholesale. modelProvider
#     is explicitly deleted: the deep merge would otherwise let a stale
#     "gemini" value linger on disk forever and silently pin agy back to
#     API-key auth.
#   - ~/.gemini/config/mcp_config.json -- mcpServers, wholesale-replaced
#     rather than deep-merged, same reasoning as the .claude.json fix
#     above: a deep merge would let a server removed from mcp.nix survive
#     forever as a stale leftover key.
{ config, pkgs, ... }:
let
  antigravityMcpFile = (import ./mcp.nix { inherit pkgs; }).antigravity;
  translated = (import ./permissions-translate.nix { inherit (pkgs) lib; }).agy;
  antigravitySettingsFile = pkgs.writeText "antigravity-cli-settings.json" (
    builtins.toJSON {
      permissions = translated;
    }
  );
in
{
  home.activation.antigravitySettings = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "$HOME/.gemini/antigravity-cli" "$HOME/.gemini/config"

    # --- settings.json (auth/model provider) ---
    [ -f "$HOME/.gemini/antigravity-cli/settings.json" ] || echo '{}' > "$HOME/.gemini/antigravity-cli/settings.json"

    ${pkgs.jq}/bin/jq -s '.[0] as $old | .[1] as $new | ($old * $new)
        | del(.modelProvider)
        | .permissions = {
            allow: ((($old.permissions.allow // []) + $new.permissions.allow) | unique),
            deny: $new.permissions.deny
          }' \
      "$HOME/.gemini/antigravity-cli/settings.json" ${antigravitySettingsFile} \
      > "$HOME/.gemini/antigravity-cli/settings.json.tmp"
    mv "$HOME/.gemini/antigravity-cli/settings.json.tmp" "$HOME/.gemini/antigravity-cli/settings.json"
    chmod 644 "$HOME/.gemini/antigravity-cli/settings.json"

    # --- mcp_config.json (mcpServers) ---
    [ -f "$HOME/.gemini/config/mcp_config.json" ] || echo '{}' > "$HOME/.gemini/config/mcp_config.json"

    ${pkgs.jq}/bin/jq -s '.[0] as $old | .[1] as $new | ($old * $new) | .mcpServers = $new.mcpServers' \
      "$HOME/.gemini/config/mcp_config.json" ${antigravityMcpFile} \
      > "$HOME/.gemini/config/mcp_config.json.tmp"
    mv "$HOME/.gemini/config/mcp_config.json.tmp" "$HOME/.gemini/config/mcp_config.json"
    chmod 644 "$HOME/.gemini/config/mcp_config.json"
  '';
}
