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
  ) ++ [ config.ai.shunt.opencodePluginUrl ]
  # opencode-goal-plugin manages its own install/cache under
  # ~/.cache/opencode/packages -- OpenCode resolves plain npm specs in
  # `plugin` itself, unlike the file://-vendored packages above, and an
  # unpinned entry sticks to whichever version it first resolved forever,
  # so this must stay version-pinned and bumped by hand.
  ++ [ "opencode-goal-plugin@0.10.0" ];
in
{
  home.file.".local/share/opencode-claude-vendor".source = custom.opencode-claude;
  home.file.".local/share/opencode-extensions-vendor".source = custom.opencode-extensions;

  # Global instructions, including the Read delegation policy that routes to
  # the "reader" agent defined below. Auto-loaded by opencode itself and, per
  # oh-my-opencode's hephaestus-agents-md-injector hook, injected into its
  # dynamic personas (Sisyphus, Hephaestus, Ultraworker, etc.) too.
  home.file.".config/opencode/AGENTS.md".source = ../../files/opencode/AGENTS.md;

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
    # One agent per on-device model (nixos/modules/services/ollama.nix's
    # loadModels); all strip every tool but read/grep/glob -- each disabled
    # tool's schema is removed from the system prompt entirely (not just
    # blocked), which matters since the context budget is small. Select in
    # opencode with Tab or /agent local-suffix.
    #   - "default": generic primary agent -- pins no model (so it follows
    #     .model, whatever is picked in the TUI) and restricts no tools, i.e.
    #     the unrestricted counterpart to the two local-* agents. Exists so
    #     there is an explicit thing to switch back to after using a local
    #     agent; it is NOT auto-selected (that would need the separate
    #     top-level `default_agent` key, which is deliberately left unset so
    #     opencode keeps falling back to its built-in `build` agent).
    #   - "local-qwen": qwen3.5:4b, newer-gen Qwen, thinking+tool-use
    #     capable, small (4B) -- moderate output headroom since it can burn
    #     some of its budget on thinking.
    #   - "local-lfm": lfm2.5:8b, MoE (~1B active params) purpose-built for
    #     tool calling on consumer hardware, non-reasoning.
    # Both limits assume OLLAMA_CONTEXT_LENGTH=24576 with
    # OLLAMA_KV_CACHE_TYPE=q8_0 (see ollama.nix) -- keep these in sync with
    # that file if the context length or KV quant changes.
    #
    # deepseek-r1:7b, qwen2.5-coder:7b, phi4-mini:3.8b (and their "local"/
    # "local-coder"/"local-phi" agents) were tried and dropped in favor of
    # the two above. Since this merges (`*`) into whatever's already on
    # disk rather than replacing it, dropping a model/agent from the jq
    # filter alone would NOT remove it from an opencode.jsonc a previous
    # activation already wrote it to -- hence the explicit `del()` calls
    # below. Extend that del() list (not just the merge objects above) when
    # retiring another model/agent in the future.
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
      --argjson engramCmd ${pkgs.lib.escapeShellArg (builtins.toJSON [ "${custom.engram}/bin/engram" "mcp" "--tools=agent" ])} \
      --argjson goalCommand ${pkgs.lib.escapeShellArg (
        builtins.toJSON {
          goal = {
            description = "Set a session-scoped goal and auto-continue until complete (opencode-goal-plugin).";
            template = "$ARGUMENTS";
            agent = "build";
          };
        }
      )} \
      '.plugin = ((.plugin // []) + $plugins | unique)
       | .command = ((.command // {}) * $goalCommand)
       | .provider = ((.provider // {}) * {
           "claude-code": { "name": "Claude Code" },
           "ollama": {
             "npm": "@ai-sdk/openai-compatible",
             "name": "Ollama (local)",
             "options": { "baseURL": "http://127.0.0.1:11434/v1" },
             "models": {
               "qwen3.5:4b": {
                 "name": "Qwen3.5 4B (local)",
                 "limit": { "context": 24576, "output": 6144 }
               },
               "lfm2.5:8b": {
                 "name": "LFM2.5 8B MoE (local)",
                 "limit": { "context": 24576, "output": 8192 }
               }
             }
           }
         })
       | .provider.ollama.models |= (. // {} | del(.["deepseek-r1:7b"], .["qwen2.5-coder:7b"], .["phi4-mini:3.8b"]))
        | .agent = ((.agent // {}) * {
            "default": {
              "description": "Generic general-purpose agent: full tool access and no model pin, so it follows whatever .model is set to. The unrestricted counterpart to the tool-stripped local-* agents.",
              "mode": "primary"
            },
            "local-qwen": {
             "description": "Minimal agent pinned to the on-device ollama model qwen3.5:4b (newer-gen, thinking+tool-use capable, 4B), read/grep/glob only, kept small to fit its context budget.",
             "mode": "primary",
             "model": "ollama/qwen3.5:4b",
             "tools": {
               "*": false,
               "read": true,
               "grep": true,
               "glob": true
             }
           },
           "local-lfm": {
             "description": "Minimal agent pinned to the on-device ollama model lfm2.5:8b (MoE, ~1B active params, purpose-built for tool calling on consumer hardware), read/grep/glob only, kept small to fit its context budget.",
             "mode": "primary",
             "model": "ollama/lfm2.5:8b",
             "tools": {
               "*": false,
               "read": true,
               "grep": true,
               "glob": true
             }
           },
            "reader": {
              "description": "Shunt delegate for reads/summaries -- see the Read delegation policy in AGENTS.md. Pinned to gemini-3.6-flash (cheap/fast) rather than following whatever model the caller is on; read/grep/glob/list only. If its calls fail on quota/TPM errors, the caller retries via local-qwen (local, no TPM ceiling) -- see the fallback order in AGENTS.md.",
              "mode": "subagent",
              "model": "google/gemini-3.6-flash",
              "tools": {
                "*": false,
                "read": true,
                "grep": true,
                "glob": true,
                "list": true
              }
            },
            "memory-scribe": {
              "description": "Specialized delegate for composing and executing memory saves -- mnemon remember (global/user facts) or engram save (project-scoped facts). The caller hands it the save intent; the scribe drafts the payload (extracting from big files via the shunt plugin cheap path if needed), runs the local memory CLI itself, and reports store/IDs back. Never used for general reads -- use `reader` for those.",
              "mode": "subagent",
              "model": "google/gemini-3.6-flash",
              "tools": {
                "*": false,
                "read": true,
                "grep": true,
                "glob": true,
                "list": true,
                "bash": true
              }
            }
         })
       | .agent |= (. // {} | del(.local, .["local-coder"], .["local-phi"]))
       | .mcp = ((.mcp // {}) * {
           "rag": { "type": "local", "command": [$ragCmd], "enabled": true },
           "engram": { "type": "local", "command": $engramCmd, "enabled": true }
         })
        | .model = (.model // "google/gemini-3.6-flash")
        # small_model (titles, background summarization): tiny/frequent calls
        # that never need flash-latest peak TPM -- pin the lowest-TPM
        # flash-line model per the shunt fallback rationale (shunt.nix).
        | .small_model = (.small_model // "google/gemini-flash-lite-latest")' \
      "$HOME/.config/opencode/opencode.jsonc" > "$HOME/.config/opencode/opencode.jsonc.tmp"
    mv "$HOME/.config/opencode/opencode.jsonc.tmp" "$HOME/.config/opencode/opencode.jsonc"
  '';
}
