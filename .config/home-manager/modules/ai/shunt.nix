# Spotify portal-ai-plugins "shunt" replication (see
# https://github.com/spotify/portal-ai-plugins, plugins/shunt): mechanically
# gate I/O-heavy reads so the main model never loads big files into context.
#
# The dotfiles already had the other two shunt layers -- delegation targets
# (Claude `reader` / opencode `reader` / pi `scout`, all on cheap Gemini) and
# the prompt-level read-delegation policy. What was missing is shunt's HARD
# GATE: a mechanical tool-call block, because prompt rules get forgotten and
# hard gates don't. This module generates and installs that gate everywhere:
#
#   - Claude Code : ~/.claude/hooks/shunt-gate.sh wired as a PreToolUse hook
#                   (matcher Read|Bash) by modules/ai/claude-code.nix. Same
#                   decision/reason wire format as upstream's check-file-size
#                   and check-bash-read hooks.
#   - opencode    : ~/.local/share/opencode-shunt-vendor/shunt-gate.js, a
#                   single-file ES-module plugin registered in opencode.jsonc
#                   `plugin` via a file:// URL (same loading mechanism as
#                   every other plugin in modules/ai/opencode.nix). Blocking =
#                   throwing from `tool.execute.before`.
#   - pi          : ~/.local/share/pi-shunt-vendor/node_modules/pi-shunt-gate,
#                   an extension whose default export calls
#                   pi.on("tool_call") and returns { block, reason } (the same
#                   API @narumitw/pi-plan-mode uses). modules/ai/pi.nix
#                   registers its path as a local-path package.
#
# Shared knobs live here so the threshold and the fallback model chain stay
# in one place. The chain is ordered by TPM economics (user requirement):
# flash-latest has the highest peak TPM and serves the bulk reads; the live
# preview models accept far less (~65k TPM) but only ever see the small
# extract question, never the file; the local ollama models are the terminal
# fallback handled per harness, not by agy (which can't reach ollama).
#
# This module does NOT touch engram/mnemon themselves: both are local CLIs
# (no model, no API cost). The only model spend around them is composing the
# save text, which the policy files route through the same cheap delegate.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.ai.shunt;

  # --- Claude Code: PreToolUse gate -------------------------------------
  # The logic lives in files/shunt/shunt-check.py: it counts the lines a call
  # would really emit (a Read window, head/tail -n N, sed -n 'A,Bp' ranges,
  # awk NR ranges, the sum over a && chain, and a per-session budget per file),
  # so the model cannot route around the gate with chained sed ranges or many
  # small slices. It answers with hookSpecificOutput permissionDecision=deny.
  pyBin = name: src: pkgs.writeScriptBin name ("#!${pkgs.python3}/bin/python3\n" + builtins.readFile src);
  shuntCheck = pyBin "shunt-check" ../../files/shunt/shunt-check.py;
  # Spotify shunt's two worker scripts. One source; the command name picks the
  # mode. bulk-read / code-write try the agy Gemini chain first (agy reads the
  # files in its sandbox), then `claude -p` on SHUNT_DELEGATE with no tools.
  bulkRead = pyBin "bulk-read" ../../files/shunt/shunt-worker.py;
  codeWrite = pyBin "code-write" ../../files/shunt/shunt-worker.py;

  claudeGate = pkgs.writeShellScript "shunt-gate.sh" ''
    exec ${shuntCheck}/bin/shunt-check --harness claude
  '';

  # Read by shunt-check and the worker scripts.
  shuntEnv = pkgs.writeText "shunt-config.env" ''
    SHUNT_DEFAULT_ENABLED=1
    SHUNT_THRESHOLD=${toString cfg.thresholdLines}
    SHUNT_DELEGATE=haiku
    SHUNT_AGY=${config.home.homeDirectory}/.claude/hooks/agy-shunt
  '';

  # --- Claude Code: the shunt "worker" ----------------------------------
  # Spotify's bulk-read sends the file to a cheap worker model; here the
  # file never leaves the agy sandbox and only the extract question walks
  # the fallback chain. First model that answers without a quota/rate-limit
  # signature wins; exit 1 = chain exhausted (caller reads the file itself
  # as the terminal fallback, per files/claude/agents/reader.md).
  agyShunt = pkgs.writeShellScript "agy-shunt" ''
    # shunt fallback-chain worker (see modules/ai/shunt.nix). Nix-managed.
    set -u
    GREP="${pkgs.gnugrep}/bin/grep"
    [ $# -ge 1 ] || {
      echo "usage: agy-shunt <prompt> [extra agy args...]" >&2
      exit 2
    }
    PROMPT=$1
    shift
    if ! command -v agy >/dev/null 2>&1; then
      echo "agy-shunt: agy not on PATH" >&2
      exit 1
    fi
    CHAIN=(${lib.concatStringsSep " " (map lib.escapeShellArg cfg.chain)})
    LAST=""
    for M in ''${CHAIN[@]}; do
      LAST=$(agy -p "$PROMPT" --model "$M" "$@" 2>&1)
      RC=$?
      if [ "$RC" -eq 0 ] && ! printf '%s' "$LAST" | $GREP -qiE 'RESOURCE_EXHAUSTED|rate[ _-]?limit|quota|429|overloaded|unavailable'; then
        printf '%s\n' "$LAST"
        exit 0
      fi
    done
    printf 'agy-shunt: every fallback model failed (last error below):\n%s\n' "$LAST" >&2
    exit 1
  '';

  # --- opencode and pi: shared JS adapter --------------------------------
  # Both JS gates are thin adapters over shunt-check, like the shell hooks: they
  # forward the tool call and let the shared core count the lines and keep the
  # per-session budget, so slicing and sed/awk chains are caught here too. The
  # binary is pinned by store path, so no PATH lookup can miss it.
  jsCheck = harness: ''
    import { spawnSync } from "node:child_process";

    const SHUNT_CHECK = "${shuntCheck}/bin/shunt-check";

    // Returns the block reason, or null to let the call through. Anything that
    // goes wrong (missing binary, timeout, bad output) fails open.
    function shuntReason(tool, input, sessionId, cwd) {
      try {
        const r = spawnSync(SHUNT_CHECK, ["--harness", "${harness}"], {
          input: JSON.stringify({
            tool_name: String(tool || ""),
            tool_input: input || {},
            session_id: String(sessionId || ""),
            cwd: cwd || process.cwd(),
          }),
          encoding: "utf8",
          timeout: 5000,
        });
        if (r.status === 2) return (r.stderr || "").trim() || "SHUNT: read blocked";
      } catch {}
      return null;
    }
  '';

  # --- opencode: single-file ES-module plugin ----------------------------
  # Loaded from opencode.jsonc's `plugin` array via file:// URL (same
  # mechanism as modules/ai/opencode.nix). Blocking = throwing; anything
  # returned (including false) lets the call proceed.
  # A default export only: a second named export of the same factory would
  # register the hook twice, and the second run would count every read against
  # the session budget again.
  ocPlugin = pkgs.writeText "shunt-gate.js" (
    ''
      // shunt hard gate for opencode. Generated by modules/ai/shunt.nix.
    ''
    + jsCheck "opencode"
    + ''

      // opencode's read takes { filePath, offset (1-indexed), limit }, the
      // same window shunt-check applies to a Claude Read.
      export default async function shuntGate({ directory } = {}) {
        return {
          "tool.execute.before": async (input, output) => {
            const tool = input && input.tool;
            if (tool !== "read" && tool !== "bash") return;
            const args = (output && output.args) || {};
            const reason = shuntReason(tool, args, input.sessionID, directory);
            if (reason) throw new Error(reason);
          },
        };
      }
    ''
  );

  # --- pi: gate extension ------------------------------------------------
  # pi extension contract (verified against the vendored
  # @narumitw/pi-plan-mode): package.json's `pi.extensions` lists the entry
  # module; the module default-exports a factory receiving the extension
  # API; pi.on("tool_call") handlers return { block, reason } to block.
  piGatePkgJson = pkgs.writeText "pi-shunt-gate-package.json" (
    builtins.toJSON {
      name = "pi-shunt-gate";
      version = "0.1.0";
      description = "shunt hard gate: blocks bulk reads, points at bulk-read";
      type = "module";
      pi.extensions = [ "./index.js" ];
    }
  );
  piGateIndex = pkgs.writeText "pi-shunt-gate-index.js" (
    ''
      // shunt hard gate for pi. Generated by modules/ai/shunt.nix.
    ''
    + jsCheck "pi"
    + ''

      // pi's read takes { path, offset (1-indexed), limit }, the same window
      // shunt-check applies to a Claude Read. pi has no built-in subagent, so
      // the block reason's bulk-read command is the delegation path.
      export default function shuntGate(pi) {
        pi.on("tool_call", async (event, ctx) => {
          const tool = event && event.toolName ? String(event.toolName) : "";
          if (tool !== "read" && tool !== "bash") return;
          let sid = "";
          try {
            sid = ctx.sessionManager.getSessionId();
          } catch {}
          const reason = shuntReason(tool, event.input || {}, sid, ctx && ctx.cwd);
          if (reason) return { block: true, reason };
        });
      }
    ''
  );
  piGate = pkgs.runCommand "pi-shunt-gate" { } ''
    mkdir -p $out/node_modules/pi-shunt-gate
    cp ${piGatePkgJson} $out/node_modules/pi-shunt-gate/package.json
    cp ${piGateIndex} $out/node_modules/pi-shunt-gate/index.js
  '';
in
{
  options.ai.shunt = {
    thresholdLines = lib.mkOption {
      type = lib.types.int;
      default = 350;
      description = ''
        Bulk-read threshold shared by every shunt gate (matches Spotify's
        SHUNT_MIN_LINES default). Reads at or below it stay allowed.
      '';
    };
    chain = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "gemini-flash-latest"
        "gemini-3.8-flash"
        "gemini-3.6-flash"
        "gemini-3.1-flash-live-preview"
      ];
      description = ''
        Fallback model chain for delegated reads, ordered by TPM economics:
        flash-latest has the highest peak TPM and serves bulk extraction;
        the live-preview tier is the low-TPM (~65k) floor that only ever
        sees the small extract question, never the file. The terminal
        fallback (chain fully exhausted) is harness-specific: the reader
        subagent reads the file itself on Claude Code, local-qwen/local-lfm
        on opencode, scout's own read on pi.
      '';
    };
    opencodePluginUrl = lib.mkOption {
      type = lib.types.str;
      internal = true;
      description = "file:// URL of the opencode gate plugin (consumed by modules/ai/opencode.nix).";
    };
    piExtensionPath = lib.mkOption {
      type = lib.types.str;
      internal = true;
      description = "Absolute path of the pi gate extension package (consumed by modules/ai/pi.nix).";
    };
  };

  config = {
    home.packages = [
      shuntCheck
      bulkRead
      codeWrite
    ];

    ai.shunt.opencodePluginUrl = "file://${config.home.homeDirectory}/.local/share/opencode-shunt-vendor/shunt-gate.js";
    ai.shunt.piExtensionPath = "${config.home.homeDirectory}/.local/share/pi-shunt-vendor/node_modules/pi-shunt-gate";

    home.file = {
      ".claude/hooks/shunt-gate.sh".source = claudeGate;
      ".claude/hooks/agy-shunt".source = agyShunt;
      ".config/shunt/config.env".source = shuntEnv;
      ".local/share/opencode-shunt-vendor/shunt-gate.js".source = ocPlugin;
      ".local/share/pi-shunt-vendor".source = piGate;
    };
  };
}
