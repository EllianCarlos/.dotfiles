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
  # stdin: hook JSON ({ tool_name, tool_input, ... }); stdout: shunt's
  # {"decision":"block","reason":...}; exit 0 always (non-blocking exit
  # codes would feed stderr to the model instead).
  claudeGate = pkgs.writeShellScript "shunt-gate.sh" ''
    # shunt hard gate (see modules/ai/shunt.nix): block bulk reads, point at
    # the reader subagent. Installed by Nix -- edits are overwritten.
    set -uo pipefail
    JQ="${pkgs.jq}/bin/jq"
    GREP="${pkgs.gnugrep}/bin/grep"
    WC="${pkgs.coreutils}/bin/wc"
    TR="${pkgs.coreutils}/bin/tr"
    THRESHOLD=${toString cfg.thresholdLines}

    INPUT=$(cat)
    TOOL=$($JQ -r '.tool_name // ""' <<<"$INPUT")

    blocked() {
      $JQ -nc --arg r "$1" '{decision:"block",reason:$r}'
      exit 0
    }

    file_lines() { # -> line count on stdout, failure -> empty
      [ -f "$1" ] || return 1
      $WC -l < "$1" 2>/dev/null || return 1
    }

    case "$TOOL" in
      Read)
        FILE=$($JQ -r '.tool_input.file_path // ""' <<<"$INPUT")
        [ -n "$FILE" ] || exit 0
        # Bounded slice = the shunt escape hatch (parity with upstream).
        OFF=$($JQ -r '.tool_input.offset // 0' <<<"$INPUT")
        LIM=$($JQ -r '.tool_input.limit // 0' <<<"$INPUT")
        [ "$OFF" != "0" ] || [ "$LIM" != "0" ] && exit 0
        LINES=$(file_lines "$FILE") || exit 0
        [ -n "$LINES" ] || exit 0
        [ "$LINES" -gt "$THRESHOLD" ] && blocked "File is $LINES lines (threshold: $THRESHOLD). Delegate this read to the reader subagent instead (Agent tool, subagent_type=\"reader\") -- it extracts only what you need through the fallback model chain. A bounded slice (offset/limit within the threshold) is still allowed."
        exit 0
        ;;
      Bash)
        CMD=$($JQ -r '.tool_input.command // ""' <<<"$INPUT")
        [ -n "$CMD" ] || exit 0
        # Only pure dump commands: anything piped or redirected stays allowed
        # (parity with upstream check-bash-read).
        printf '%s' "$CMD" | $GREP -qE '[|>]' && exit 0
        printf '%s' "$CMD" | $GREP -qE '(^|[[:space:];&(])(sudo[[:space:]]+)?(cat|head|tail|less|more|nl|bat)([[:space:]]|$)' || exit 0
        for F in $(printf '%s' "$CMD" | $GREP -oE '[^[:space:];|&]+\.[A-Za-z0-9]{1,8}'); do
          F=$(printf '%s' "$F" | $TR -d "\"'")
          LINES=$(file_lines "$F") || continue
          [ -n "$LINES" ] || continue
          [ "$LINES" -gt "$THRESHOLD" ] && blocked "'$F' is $LINES lines (threshold: $THRESHOLD). Delegate to the reader subagent (Agent tool, subagent_type=\"reader\") instead of dumping the file into context."
        done
        exit 0
        ;;
    esac
    exit 0
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

  # --- opencode: single-file ES-module plugin ----------------------------
  # Loaded from opencode.jsonc's `plugin` array via file:// URL (same
  # mechanism as modules/ai/opencode.nix). Blocking = throwing; anything
  # returned (including false) lets the call proceed.
  ocPlugin = pkgs.writeText "shunt-gate.js" ''
    // shunt hard gate for opencode (see modules/ai/shunt.nix). Nix-managed.
    import { readFileSync } from "node:fs";

    const THRESHOLD = ${toString cfg.thresholdLines};
    const DUMP_RE = /\b(?:cat|head|tail|less|more|nl|bat)\b/;

    function lineCount(path) {
      try {
        return readFileSync(path, "utf8").split("\n").length;
      } catch {
        return null;
      }
    }

    export const shuntGate = async () => ({
      "tool.execute.before": async (input, output) => {
        const tool = input && input.tool;
        const args = (output && output.args) || {};
        if (tool === "read") {
          if (args.offset !== undefined || args.limit !== undefined) return;
          const file = args.filePath || args.file || args.path;
          if (!file) return;
          const lines = lineCount(file);
          if (lines !== null && lines > THRESHOLD) {
            throw new Error(
              "SHUNT: File is " + lines + " lines (threshold: " + THRESHOLD + "). " +
                "Delegate this read to the 'reader' agent via the task tool -- it " +
                "extracts only what you need. A bounded slice (offset/limit) is still allowed.",
            );
          }
          return;
        }
        if (tool === "bash") {
          const cmd = String(args.command || "");
          if (!cmd || cmd.includes("|") || cmd.includes(">")) return;
          if (!DUMP_RE.test(cmd)) return;
          const files = cmd.match(/[^\s;|&]+\.[A-Za-z0-9]{1,8}/g) || [];
          for (const file of files) {
            const lines = lineCount(file);
            if (lines !== null && lines > THRESHOLD) {
              throw new Error(
                "SHUNT: '" + file + "' is " + lines + " lines (threshold: " + THRESHOLD + "). " +
                  "Use the 'reader' agent via the task tool instead of dumping the file.",
              );
            }
          }
        }
      },
    });

    export default shuntGate;
  '';

  # --- pi: gate extension ------------------------------------------------
  # pi extension contract (verified against the vendored
  # @narumitw/pi-plan-mode): package.json's `pi.extensions` lists the entry
  # module; the module default-exports a factory receiving the extension
  # API; pi.on("tool_call") handlers return { block, reason } to block.
  # pi's read-tool argument names are not pinned by any vendored source, so
  # the gate probes the common spellings defensively and lets anything it
  # can't interpret through.
  piGatePkgJson = pkgs.writeText "pi-shunt-gate-package.json" (
    builtins.toJSON {
      name = "pi-shunt-gate";
      version = "0.1.0";
      description = "shunt hard gate: blocks bulk reads, points at the scout subagent";
      type = "module";
      pi.extensions = [ "./index.js" ];
    }
  );
  piGateIndex = pkgs.writeText "pi-shunt-gate-index.js" ''
    // shunt hard gate for pi (see modules/ai/shunt.nix). Nix-managed.
    import { readFileSync } from "node:fs";

    const THRESHOLD = ${toString cfg.thresholdLines};
    const READ_TOOLS = new Set(["read", "Read"]);
    const DUMP_RE = /\b(?:cat|head|tail|less|more|nl|bat)\b/;

    function lineCount(path) {
      try {
        return readFileSync(path, "utf8").split("\n").length;
      } catch {
        return null;
      }
    }

    function bounded(input) {
      return input.offset !== undefined || input.limit !== undefined;
    }

    function readPath(input) {
      return input.path || input.file_path || input.filePath || input.file || null;
    }

    function dumpPaths(cmd) {
      return cmd.match(/[^\s;|&]+\.[A-Za-z0-9]{1,8}/g) || [];
    }

    const READ_REASON =
      "SHUNT: file has more than " + THRESHOLD + " lines. Delegate this read to the " +
      "'scout' subagent (subagent tool) -- it extracts only what you need. " +
      "A bounded slice (offset/limit) is still allowed.";

    export default function shuntGate(pi) {
      pi.on("tool_call", async (event) => {
        const tool = event && event.toolName ? String(event.toolName) : "";
        const input = (event && event.input) || {};
        if (READ_TOOLS.has(tool)) {
          if (bounded(input)) return;
          const file = readPath(input);
          if (!file) return;
          const lines = lineCount(file);
          if (lines !== null && lines > THRESHOLD) {
            return { block: true, reason: READ_REASON };
          }
          return;
        }
        if (tool === "bash") {
          const cmd = typeof input.command === "string" ? input.command : "";
          if (!cmd || cmd.includes("|") || cmd.includes(">")) return;
          if (!DUMP_RE.test(cmd)) return;
          for (const file of dumpPaths(cmd)) {
            const lines = lineCount(file);
            if (lines !== null && lines > THRESHOLD) {
              return {
                block: true,
                reason:
                  "SHUNT: '" + file + "' has more than " + THRESHOLD + " lines. Use the " +
                  "'scout' subagent instead of dumping the file into context.",
              };
            }
          }
        }
      });
    }
  '';
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
    ai.shunt.opencodePluginUrl = "file://${config.home.homeDirectory}/.local/share/opencode-shunt-vendor/shunt-gate.js";
    ai.shunt.piExtensionPath = "${config.home.homeDirectory}/.local/share/pi-shunt-vendor/node_modules/pi-shunt-gate";

    home.file = {
      ".claude/hooks/shunt-gate.sh".source = claudeGate;
      ".claude/hooks/agy-shunt".source = agyShunt;
      ".local/share/opencode-shunt-vendor/shunt-gate.js".source = ocPlugin;
      ".local/share/pi-shunt-vendor".source = piGate;
    };
  };
}
