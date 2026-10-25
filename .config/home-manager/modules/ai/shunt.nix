# Spotify portal-ai-plugins "shunt" replication (see
# https://github.com/spotify/portal-ai-plugins, plugins/shunt): mechanically
# gate I/O-heavy reads so the main model never loads big files into context.
#
# The dotfiles already had the other two shunt layers -- delegation targets
# (Claude `reader` / opencode `reader` / Hermes delegate_task, all on cheap Gemini) and
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
#   - Hermes      : a pre_tool_call shell hook (matcher read_file|terminal)
#                   registered in config.yaml by modules/ai/hermes.nix.
#                   Blocking = exit 2 with the reason on stderr.
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
      # Some models (e.g. gemini-3.6-flash) are rejected without --effort;
      # extraction is cheap, so retry once at the lowest level.
      if [ "$RC" -ne 0 ] && printf '%s' "$LAST" | $GREP -q 'requires --effort'; then
        LAST=$(agy -p "$PROMPT" --model "$M" --effort low "$@" 2>&1)
        RC=$?
      fi
      if [ "$RC" -eq 0 ] && ! printf '%s' "$LAST" | $GREP -qiE 'RESOURCE_EXHAUSTED|rate[ _-]?limit|quota|429|overloaded|unavailable'; then
        printf '%s\n' "$LAST"
        exit 0
      fi
    done
    printf 'agy-shunt: every fallback model failed (last error below):\n%s\n' "$LAST" >&2
    exit 1
  '';

  # --- opencode: JS adapter ---------------------------------------------
  # The JS gate is a thin adapter over shunt-check, like the shell hooks: they
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

  hermesGate = pkgs.writeShellScript "hermes-shunt-gate.sh" ''
    exec ${shuntCheck}/bin/shunt-check --harness hermes
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
        on opencode, the delegate_task child's own read on Hermes.
      '';
    };
    opencodePluginUrl = lib.mkOption {
      type = lib.types.str;
      internal = true;
      description = "file:// URL of the opencode gate plugin (consumed by modules/ai/opencode.nix).";
    };
    hermesHookCommand = lib.mkOption {
      type = lib.types.str;
      internal = true;
      description = "Command of the Hermes pre_tool_call gate hook (consumed by modules/ai/hermes.nix).";
    };
  };

  config = {
    home.packages = [
      shuntCheck
      bulkRead
      codeWrite
    ];

    ai.shunt.opencodePluginUrl = "file://${config.home.homeDirectory}/.local/share/opencode-shunt-vendor/shunt-gate.js";
    ai.shunt.hermesHookCommand = "${hermesGate}";

    home.file = {
      ".claude/hooks/shunt-gate.sh".source = claudeGate;
      ".claude/hooks/agy-shunt".source = agyShunt;
      ".config/shunt/config.env".source = shuntEnv;
      ".local/share/opencode-shunt-vendor/shunt-gate.js".source = ocPlugin;
    };
  };
}
