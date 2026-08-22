# Registers opencode-claude (../../pkgs/opencode-claude.nix) and the rest
# of ../../pkgs/opencode-extensions.nix with opencode. Unlike pi's npm/
# directory, ~/.config/opencode/node_modules is shared with opencode's own
# runtime deps, so this does not symlink over it -- instead each built
# plugin is placed at a stable location outside opencode's own
# directories, and opencode.jsonc's `plugin` array points at each one's
# built entry file directly via a file:// URL (verified working for
# opencode-claude: this makes claude-code/* show up in `opencode models`).
{ config, pkgs, ... }:
let
  custom = import ../../pkgs { inherit pkgs; };

  # Real absolute paths (not shell $HOME) -- these strings are embedded
  # verbatim into a single-quoted --argjson value below, where the shell
  # would never expand $HOME.
  claudeLink = "${config.home.homeDirectory}/.local/share/opencode-claude-vendor";
  extLink = "${config.home.homeDirectory}/.local/share/opencode-extensions-vendor";

  # Each entry file below is that package's own `main` (or `exports["."]`)
  # field, read from the built tree -- see opencode-extensions.nix for
  # what each package does.
  extensionEntries = [
    "${extLink}/node_modules/oh-my-opencode/dist/index.js"
    "${extLink}/node_modules/opencode-pty/dist/index.js"
    "${extLink}/node_modules/opencode-websearch/dist/index.js"
    "${extLink}/node_modules/opencode-plugin-inspector/dist/main.js"
    "${extLink}/node_modules/opencode-vibeguard/src/index.js"
    "${extLink}/node_modules/opencode-wakatime/dist/index.js"
    "${extLink}/node_modules/opencode-notification/dist/index.js"
    "${extLink}/node_modules/@plannotator/opencode/dist/index.js"
    "${extLink}/node_modules/@nick-vi/opencode-type-inject/.opencode/plugin/type-inject.ts"
    "${extLink}/node_modules/@tarquinen/opencode-dcp/dist/index.js"
  ];

  pluginUrls = builtins.map (p: "file://${p}") (
    [ "${claudeLink}/node_modules/@openchamber/opencode-claude/opencode-claude.js" ] ++ extensionEntries
  );
in
{
  home.file.".local/share/opencode-claude-vendor".source = custom.opencode-claude;
  home.file.".local/share/opencode-extensions-vendor".source = custom.opencode-extensions;

  # entryAfter writeBoundary: needs the home.file symlinks above in place
  # first for the file:// paths it writes to resolve.
  home.activation.opencodePlugins = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "$HOME/.config/opencode"
    [ -f "$HOME/.config/opencode/opencode.jsonc" ] \
      || echo '{"$schema": "https://opencode.ai/config.json"}' > "$HOME/.config/opencode/opencode.jsonc"

    ${pkgs.jq}/bin/jq \
      --argjson plugins ${pkgs.lib.escapeShellArg (builtins.toJSON pluginUrls)} \
      '.plugin = ((.plugin // []) + $plugins | unique)
       | .provider = ((.provider // {}) * { "claude-code": { "name": "Claude Code" } })' \
      "$HOME/.config/opencode/opencode.jsonc" > "$HOME/.config/opencode/opencode.jsonc.tmp"
    mv "$HOME/.config/opencode/opencode.jsonc.tmp" "$HOME/.config/opencode/opencode.jsonc"
  '';
}
