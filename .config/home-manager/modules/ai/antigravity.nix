# Antigravity CLI (`agy`) configuration.
#
# Pins auth to the API key path (GEMINI_API_KEY, exported from `pass` in
# programs.zsh.initExtra) so `agy` never drops into the interactive
# browser/keyring login flow. Antigravity CLI splits its config across two
# files (unlike Claude Code / the old Gemini CLI, which keep mcpServers
# inside the main settings file):
#   - ~/.gemini/antigravity-cli/settings.json -- modelProvider, deep-merged
#     over whatever's on disk so unmanaged state survives.
#   - ~/.gemini/config/mcp_config.json -- mcpServers, wholesale-replaced
#     rather than deep-merged, same reasoning as the .claude.json fix
#     above: a deep merge would let a server removed from mcp.nix survive
#     forever as a stale leftover key.
{ config, pkgs, ... }:
let
  antigravityMcpFile = (import ./mcp.nix { inherit pkgs; }).antigravity;
  antigravitySettingsFile = pkgs.writeText "antigravity-cli-settings.json" (
    builtins.toJSON {
      modelProvider = "gemini";
    }
  );
in
{
  home.activation.antigravitySettings = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "$HOME/.gemini/antigravity-cli" "$HOME/.gemini/config"

    # --- settings.json (auth/model provider) ---
    [ -f "$HOME/.gemini/antigravity-cli/settings.json" ] || echo '{}' > "$HOME/.gemini/antigravity-cli/settings.json"

    ${pkgs.jq}/bin/jq -s '.[0] * .[1]' \
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
