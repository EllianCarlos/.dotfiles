"""bulk-read / code-write: send I/O-heavy work to a cheap worker model.

The caller's context only ever sees the answer (bulk-read) or a one-line
receipt (code-write). The file contents go to the worker, never to the caller.
Installed twice by modules/ai/shunt.nix; the command name picks the mode.
Token usage and cost are reported on stderr.
"""
import argparse
import json
import os
import re
import subprocess
import sys
import time

MAX_BYTES = 600_000
TIMEOUT = 240

BULK_READER = (
    "You are a precise code analyst. Read the provided files and answer the question concisely. "
    "Output structured bullets only. No greetings, no prose, no preambles. Lead every bullet with "
    "the exact name, type, or line number. Every file line is prefixed with its line number; cite "
    "claims as path:line. Use nested bullets for details. Skip anything the caller did not ask for. "
    "If the answer is not in the files, say so in one line."
)

CODE_WRITER = (
    "You generate code files based on a spec and reference files. Match the existing patterns, "
    "conventions, naming, and style exactly. Output only the code - no explanations, no markdown "
    "fences. If the spec is ambiguous, make reasonable choices that match the reference code's patterns."
)


def conf_value(key, default):
    if os.environ.get(key):
        return os.environ[key]
    try:
        with open(os.path.expanduser("~/.config/shunt/config.env")) as fh:
            for line in fh:
                m = re.match(rf"^{key}=(.*)$", line.strip())
                if m:
                    return m.group(1)
    except OSError:
        pass
    return default


def corpus(paths, numbered):
    parts, size = [], 0
    for p in paths:
        with open(p, encoding="utf-8", errors="replace") as fh:
            text = fh.read()
        size += len(text)
        if size > MAX_BYTES:
            sys.exit(f"shunt: corpus exceeds {MAX_BYTES} bytes at {p}; split the paths across calls")
        lines = text.splitlines()
        body = "\n".join(f"{i}\t{l}" for i, l in enumerate(lines, 1)) if numbered else text
        parts.append(f'<file path="{p}" lines="{len(lines)}">\n{body}\n</file>')
    return "\n".join(parts), size


def run_claude(system, prompt, model):
    base = ["claude", "-p", "--model", model, "--system-prompt", system, "--tools", "",
            "--no-session-persistence", "--output-format", "json"]
    # --bare drops hooks, CLAUDE.md and tool schemas (~60 tokens of overhead instead of ~16k),
    # but it cannot use OAuth logins. Fall back to a hook-free normal session for those.
    attempts = [base + ["--bare"],
                base + ["--settings", '{"disableAllHooks":true}', "--strict-mcp-config", "--disable-slash-commands"]]
    err = ""
    for argv in attempts:
        try:
            # One-shot call: a cache write costs 1.25x input and is rarely read back.
            env = dict(os.environ, DISABLE_PROMPT_CACHING="1")
            proc = subprocess.run(argv, input=prompt, capture_output=True, text=True, timeout=TIMEOUT, env=env)
        except subprocess.TimeoutExpired:
            sys.exit(f"shunt: worker timed out after {TIMEOUT}s; split the request")
        try:
            out = json.loads(proc.stdout)
        except json.JSONDecodeError:
            err = (proc.stderr or proc.stdout).strip()[-500:]
            continue
        if proc.returncode == 0 and not out.get("is_error"):
            return out
        err = str(out.get("result") or proc.stderr)[-500:]
    sys.exit(f"shunt: worker failed: {err}")


def run_agy(agy, system, question, paths):
    """Gemini through the agy fallback chain. agy reads the files itself, in its sandbox."""
    root = os.path.commonpath([os.path.dirname(os.path.abspath(p)) for p in paths])
    listing = "\n".join(os.path.abspath(p) for p in paths)
    prompt = f"{system}\n\nFILES:\n{listing}\n\n{question}"
    start = time.time()
    try:
        proc = subprocess.run([agy, prompt, "--add-dir", root, "--sandbox", "--dangerously-skip-permissions"],
                              capture_output=True, text=True, timeout=TIMEOUT)
    except (OSError, subprocess.TimeoutExpired):
        return None
    if proc.returncode != 0 or not proc.stdout.strip():
        print(f"shunt: agy chain failed, falling back to claude: {proc.stderr.strip()[-200:]}", file=sys.stderr)
        return None
    print(f"shunt: worker=agy {time.time() - start:.1f}s", file=sys.stderr)
    return proc.stdout


def run_worker(system, prompt, question=None, paths=None):
    agy = os.path.expanduser(conf_value("SHUNT_AGY", ""))
    if agy and paths and os.access(agy, os.X_OK):
        answer = run_agy(agy, system, question, paths)
        if answer is not None:
            return answer
    model = conf_value("SHUNT_DELEGATE", "sonnet")
    custom = os.environ.get("SHUNT_WORKER")
    start = time.time()
    if custom:
        # Any command that reads the prompt on stdin and prints the answer.
        proc = subprocess.run(custom, shell=True, input=f"{system}\n\n{prompt}", capture_output=True,
                              text=True, timeout=TIMEOUT)
        if proc.returncode != 0:
            sys.exit(f"shunt: SHUNT_WORKER failed: {proc.stderr.strip()[-500:]}")
        print(f"shunt: worker={custom!r} {time.time() - start:.1f}s", file=sys.stderr)
        return proc.stdout
    out = run_claude(system, prompt, model)
    usage = {}
    for m, u in (out.get("modelUsage") or {}).items():
        usage = u
        model = m
    tokens_in = sum(usage.get(k, 0) for k in ("inputTokens", "cacheReadInputTokens", "cacheCreationInputTokens"))
    print(f"shunt: worker={model} in={tokens_in} out={usage.get('outputTokens', 0)} "
          f"cost=${out.get('total_cost_usd', 0):.4f} {time.time() - start:.1f}s", file=sys.stderr)
    return out.get("result", "")


def strip_fences(text):
    m = re.match(r"^\s*```[^\n]*\n(.*?)\n```\s*$", text, re.S)
    return m.group(1) if m else text


def bulk_read(argv):
    ap = argparse.ArgumentParser(prog="bulk-read", description="Answer a question about files on a cheap model.")
    ap.add_argument("--question", "-q", required=True)
    ap.add_argument("--paths", "-p", nargs="+", required=True)
    a = ap.parse_args(argv)
    body, size = corpus(a.paths, numbered=True)
    answer = run_worker(BULK_READER, f"{body}\n\nQUESTION: {a.question}", f"QUESTION: {a.question}", a.paths)
    print(f"shunt: kept ~{size // 4} tokens of file content out of the caller's context", file=sys.stderr)
    print(answer.strip())


def code_write(argv):
    ap = argparse.ArgumentParser(prog="code-write", description="Generate a file from a spec and reference files.")
    ap.add_argument("--spec", "-s", required=True)
    ap.add_argument("--reference", "-r", nargs="+", required=True)
    ap.add_argument("--target", "-t")
    ap.add_argument("--force", action="store_true", help="overwrite an existing target")
    a = ap.parse_args(argv)
    if a.target and os.path.exists(a.target) and not a.force:
        sys.exit(f"shunt: {a.target} exists; pass --force to overwrite")
    body, _ = corpus(a.reference, numbered=False)
    target = f"\nTARGET FILE: {a.target}" if a.target else ""
    code = strip_fences(run_worker(CODE_WRITER, f"REFERENCE FILES:\n{body}\n\nSPEC: {a.spec}{target}",
                                    f"The FILES are the reference files.\nSPEC: {a.spec}{target}", a.reference))
    if not a.target:
        print(code)
        return
    os.makedirs(os.path.dirname(os.path.abspath(a.target)), exist_ok=True)
    with open(a.target, "w") as fh:
        fh.write(code if code.endswith("\n") else code + "\n")
    print(f"code-write: wrote {a.target} ({code.count(chr(10)) + 1} lines). Review it with a bounded read or a test run.")


if __name__ == "__main__":
    mode = os.path.basename(sys.argv[0])
    (code_write if mode == "code-write" else bulk_read)(sys.argv[1:])
