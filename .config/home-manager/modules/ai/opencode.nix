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

    # .model picks the default model on launch (google/* auth comes from
    # GOOGLE_GENERATIVE_AI_API_KEY, exported from `pass show gemini` in
    # programs.zsh.initContent -- see antigravity.nix). Only set when
    # missing, so a model picked by hand in the TUI survives a rebuild.
    # "ollama" provider talks to the local ollama.service (127.0.0.1:11434,
    # see nixos/modules/services/ollama.nix) over its OpenAI-compatible API.
    # Add more entries to `models` here as you pull more models locally.
    # Two agents pin the two on-device models (nixos/modules/services/
    # ollama.nix's loadModels) and both strip every tool but read/grep/glob
    # -- each disabled tool's schema is removed from the system prompt
    # entirely (not just blocked), which matters since the context budget
    # is small. Select in opencode with Tab or /agent local[-coder].
    #   - "local": deepseek-r1:7b, a reasoning model -- its <think> tokens
    #     eat into the output budget on every turn, so it gets more context
    #     headroom relative to output.
    #   - "local-coder": qwen2.5-coder:7b, non-reasoning -- no <think> tax,
    #     so more of the window is available for actual output per turn.
    # Both limits assume OLLAMA_CONTEXT_LENGTH=24576 with
    # OLLAMA_KV_CACHE_TYPE=q8_0 (see ollama.nix) -- keep these in sync with
    # that file if the context length or KV quant changes.
    #
    # tools was previously an allowlist-by-exception (only the 8 built-ins
    # were set to false), which left every MCP server's tools -- ~20
    # servers' worth of tool schemas -- included by default. That alone
    # blew past the (then 12288-token) budget before any actual
    # conversation, so the model was stuck immediately autocompacting every
    # turn. `"*": false` denies everything (built-in and MCP alike; last
    # matching glob rule wins), then read/grep/glob are re-allowed
    # explicitly.
    ${pkgs.jq}/bin/jq \
      --argjson plugins ${pkgs.lib.escapeShellArg (builtins.toJSON pluginUrls)} \
      --arg ragCmd ${pkgs.lib.escapeShellArg "${custom.rag-mcp}/bin/rag-mcp"} \
      '.plugin = ((.plugin // []) + $plugins | unique)
       | .provider = ((.provider // {}) * {
           "claude-code": { "name": "Claude Code" },
           "ollama": {
             "npm": "@ai-sdk/openai-compatible",
             "name": "Ollama (local)",
             "options": { "baseURL": "http://127.0.0.1:11434/v1" },
             "models": {
               "deepseek-r1:7b": {
                 "name": "DeepSeek R1 7B (local)",
                 "limit": { "context": 24576, "output": 6144 }
               },
               "qwen2.5-coder:7b": {
                 "name": "Qwen2.5 Coder 7B (local)",
                 "limit": { "context": 24576, "output": 8192 }
               }
             }
           }
         })
       | .agent = ((.agent // {}) * {
           "local": {
             "description": "Minimal agent pinned to the on-device ollama reasoning model (deepseek-r1:7b), read/grep/glob only, kept small to fit its context budget.",
             "mode": "primary",
             "model": "ollama/deepseek-r1:7b",
             "tools": {
               "*": false,
               "read": true,
               "grep": true,
               "glob": true
             }
           },
           "local-coder": {
             "description": "Minimal agent pinned to the on-device ollama coding model (qwen2.5-coder:7b, non-reasoning), read/grep/glob only, kept small to fit its context budget.",
             "mode": "primary",
             "model": "ollama/qwen2.5-coder:7b",
             "tools": {
               "*": false,
               "read": true,
               "grep": true,
               "glob": true
             }
           }
         })
       | .mcp = ((.mcp // {}) * {
           "rag": { "type": "local", "command": [$ragCmd], "enabled": true }
         })
       | .model = (.model // "google/gemini-3.6-flash")' \
      "$HOME/.config/opencode/opencode.jsonc" > "$HOME/.config/opencode/opencode.jsonc.tmp"
    mv "$HOME/.config/opencode/opencode.jsonc.tmp" "$HOME/.config/opencode/opencode.jsonc"
  '';
}
