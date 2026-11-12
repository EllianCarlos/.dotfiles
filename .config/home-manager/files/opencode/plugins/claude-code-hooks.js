// claude-code-hooks.js -- ports the Claude Code PostToolUse hooks that have
// no OpenCode equivalent: format-on-write.sh (matcher Edit|MultiEdit|Write)
// and validate-config.sh (matcher Edit|Write). Both scripts read the Claude
// hook payload from stdin and use .tool_input.file_path, so the OpenCode
// edit/write input is translated to that shape. Anything a script prints to
// stderr is appended to the tool result so the model can self-correct -- the
// same contract as Claude Code's exit-2 feedback.
//
// Deliberately NOT ported:
//   - mnemon Stop blocking-capture gate: no OpenCode 2 equivalent of a Stop
//     hook; engram's proactive mem_save / session-summary flow covers
//     capture on this side.
//   - mnemon/mem_metrics.sh: token-cost logging for mcp__engram__* calls.
//   - shunt-gate (PreToolUse Read/Bash): lives in its own generated plugin,
//     see modules/ai/shunt.nix.
//
// mnemon (global cross-project memory) IS ported here:
//   - prime.sh  (Claude SessionStart) -> injected into every model call's
//     system context. V2 rebuilds system per call, so injecting each time is
//     the faithful equivalent of a once-per-session append; the script output
//     is cached and only the injection repeats.
//   - user_prompt.sh (Claude UserPromptSubmit) -> runs `mnemon recall` per
//     admitted user prompt and appends the recall block to the prompt text.
//     Both scripts fail open, so prompt submission is never blocked.

import { spawnSync } from "node:child_process";
import { homedir } from "node:os";

const HOOKS_DIR = `${homedir()}/.claude/hooks`;

function runHook(name, payload) {
  try {
    return spawnSync("bash", [`${HOOKS_DIR}/${name}`], {
      input: JSON.stringify(payload),
      encoding: "utf8",
      timeout: 60_000,
    });
  } catch {
    return null;
  }
}

let primeText;
function mnemonPrime() {
  if (primeText === undefined) {
    const r = runHook("mnemon/prime.sh", {});
    primeText = ((r && (r.stdout || r.stderr)) || "").trim();
  }
  return primeText;
}

export default {
  id: "claude-code-hooks",
  setup(ctx) {
    ctx.tool.hook("execute.after", (event) => {
      const tool = event && event.tool;
      // OpenCode folds Claude's Edit/MultiEdit/Write into edit/write/patch.
      if (tool !== "edit" && tool !== "write" && tool !== "patch") return;
      const input = (event && event.input) || {};
      const filePath = input.filePath || input.file_path;
      if (!filePath) return;

      const payload = { tool_name: tool, tool_input: { file_path: filePath } };
      const feedback = [];
      for (const name of ["format-on-write.sh", "validate-config.sh"]) {
        const r = runHook(name, payload);
        const out = ((r && (r.stderr || r.stdout)) || "").trim();
        if (out) feedback.push(`[${name}] ${out}`);
      }
      if (feedback.length > 0) {
        event.result = {
          ...(event.result || {}),
          content: [
            ...(((event.result || {}).content) || []),
            { type: "text", text: feedback.join("\n") },
          ],
        };
      }
    });

    // mnemon prime (SessionStart equivalent) -> system context.
    ctx.session.hook("context", (event) => {
      const prime = mnemonPrime();
      if (prime) event.system.push({ type: "text", text: prime });
    });

    // mnemon automatic recall (UserPromptSubmit equivalent) -> the script
    // embeds its own [mnemon:recall] framing and prints nothing on a miss.
    ctx.session.hook("prompt", (event) => {
      const r = runHook("mnemon/user_prompt.sh", { prompt: event.prompt.text });
      const out = ((r && r.stdout) || "").trim();
      if (out) event.prompt.text = `${event.prompt.text}\n\n${out}`;
    });
  },
};
