"""shunt gate core, shared by the Claude Code, Kiro CLI, Codex, opencode and pi gates.

Reads one PreToolUse payload on stdin, works out how many lines the call would
put into the agent's context, and blocks it when that exceeds the threshold.
Each harness has its own block contract, selected with --harness:
claude and codex print a deny JSON on stdout; kiro, opencode and pi exit 2 with
the reason on stderr (the opencode and pi JS adapters turn that into a throw or
a { block, reason } result).
Any error fails open: a broken gate must never block every tool call.
"""
import json
import os
import re
import shlex
import sys

CLAUDE_READ_WINDOW = 2000
DUMPERS = {"cat", "nl", "bat", "batcat", "less", "more", "tac"}
WRAPPERS = {"sudo", "command", "time", "nice", "env"}
SEPARATORS = {";", "&&", "||", "&", "\n"}


def load_conf():
    home = os.path.expanduser("~")
    conf = {}
    for path, required in ((f"{home}/.config/shunt/config.env", True), (f"{home}/.config/shunt/state", False)):
        try:
            with open(path) as fh:
                for line in fh:
                    m = re.match(r"^([A-Z_]+)=(.*)$", line.strip())
                    if m:
                        conf[m.group(1)] = m.group(2).strip().strip("\"'")
        except OSError:
            if required:
                return None
    return conf


def line_count(path):
    try:
        if not os.path.isfile(path):
            return None
        with open(path, "rb") as fh:
            head = fh.read(8192)
            if b"\0" in head:
                return None
            n = head.count(b"\n")
            for chunk in iter(lambda: fh.read(1 << 20), b""):
                n += chunk.count(b"\n")
        return n
    except OSError:
        return None


def resolve(path, cwd):
    path = os.path.expanduser(path)
    return path if os.path.isabs(path) else os.path.join(cwd, path)


def window(total, start, length):
    """Lines emitted when reading `length` lines from 1-based `start`."""
    if total is None:
        return 0
    start = max(start, 1)
    rest = max(0, total - start + 1)
    return rest if length is None else min(rest, max(length, 0))


def to_int(value):
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


# --- shell analysis -------------------------------------------------------


def tokenize(cmd):
    lexer = shlex.shlex(cmd.replace("\n", " ; "), posix=True, punctuation_chars=";&|<>()")
    lexer.whitespace_split = True
    lexer.commenters = ""
    return list(lexer)


def split_segments(tokens):
    """Yield (pipeline_stages, redirected) for each ;/&&/|| separated segment."""
    segment = []
    for tok in tokens + [";"]:
        if tok in SEPARATORS:
            if segment:
                stages, cur = [], []
                for t in segment:
                    if t == "|":
                        stages.append(cur)
                        cur = []
                    else:
                        cur.append(t)
                stages.append(cur)
                redirected = any(t.startswith(">") or t in (">", ">>") for t in segment)
                yield [s for s in stages if s], redirected
            segment = []
        elif tok in ("(", ")"):
            continue
        else:
            segment.append(tok)


def strip_wrappers(argv):
    while argv and (argv[0] in WRAPPERS or re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", argv[0])):
        argv = argv[1:]
    return argv


def operands(argv, takes_value=()):
    out, skip = [], False
    for a in argv:
        if skip:
            skip = False
            continue
        if a in takes_value:
            skip = True
            continue
        if a.startswith("-") and a != "-":
            continue
        out.append(a)
    return out


def head_tail_count(name, argv, cwd):
    n, from_start, args = 10, False, []
    i = 0
    while i < len(argv):
        a = argv[i]
        val = None
        if a in ("-n", "--lines") and i + 1 < len(argv):
            val, i = argv[i + 1], i + 1
        elif a.startswith("--lines="):
            val = a.split("=", 1)[1]
        elif re.match(r"^-n.+", a):
            val = a[2:]
        elif re.match(r"^-\d+$", a):
            val = a[1:]
        elif a in ("-c", "--bytes") or a.startswith("-c") or a.startswith("--bytes"):
            return 0
        elif a in ("-f", "-F", "--follow"):
            return 0
        elif not a.startswith("-") or a == "-":
            args.append(a)
        if val is not None:
            if val.startswith("+"):
                from_start, n = True, to_int(val[1:]) or 1
            elif val.startswith("-") and name == "head":
                n = -(to_int(val[1:]) or 0)
            else:
                n = to_int(val) or 0
        i += 1
    total = 0
    for f in args:
        lines = line_count(resolve(f, cwd))
        if lines is None:
            continue
        if name == "tail" and from_start:
            total += window(lines, n, None)
        elif n < 0:
            total += max(0, lines + n)
        else:
            total += min(lines, n)
    return total


def sed_ranges(script, lines):
    total = 0
    for part in script.split(";"):
        m = re.match(r"^\s*(\d+|\$)\s*(?:,\s*(\d+|\$|\+\d+))?\s*p\s*$", part)
        if not m:
            continue
        start = lines if m.group(1) == "$" else int(m.group(1))
        end_s = m.group(2)
        if end_s is None:
            end = start
        elif end_s == "$":
            end = lines
        elif end_s.startswith("+"):
            end = start + int(end_s[1:])
        else:
            end = int(end_s)
        total += window(lines, start, end - start + 1)
    return total


def sed_count(argv, cwd):
    quiet = any(a in ("-n", "--quiet", "--silent") or re.match(r"^-[a-zA-Z]*n[a-zA-Z]*$", a) for a in argv)
    if any(a == "-i" or a.startswith("-i") or a.startswith("--in-place") for a in argv):
        return 0
    scripts, files, i = [], [], 0
    while i < len(argv):
        a = argv[i]
        if a in ("-e", "--expression") and i + 1 < len(argv):
            scripts.append(argv[i + 1])
            i += 2
            continue
        if not a.startswith("-") or a == "-":
            files.append(a)
        i += 1
    if not scripts and files:
        scripts.append(files.pop(0))
    total = 0
    for f in files:
        lines = line_count(resolve(f, cwd))
        if lines is None:
            continue
        if quiet:
            total += sum(sed_ranges(s, lines) for s in scripts)
        else:
            total += lines
    return total


def awk_count(argv, cwd):
    prog = next((a for a in argv if not a.startswith("-")), "")
    lo = re.search(r"NR\s*>=?\s*(\d+)", prog)
    hi = re.search(r"NR\s*<=?\s*(\d+)", prog)
    if not hi:
        return 0
    files = operands(argv[argv.index(prog) + 1:], ("-F", "-v", "-f")) if prog in argv else []
    start, end = (int(lo.group(1)) if lo else 1), int(hi.group(1))
    return sum(window(line_count(resolve(f, cwd)), start, end - start + 1) for f in files)


def command_lines(argv, cwd):
    argv = strip_wrappers(argv)
    if not argv:
        return 0
    name = os.path.basename(argv[0])
    rest = argv[1:]
    if name in DUMPERS:
        return sum(line_count(resolve(f, cwd)) or 0 for f in operands(rest, ("-r", "--line-range", "-l", "--language")))
    if name in ("head", "tail"):
        return head_tail_count(name, rest, cwd)
    if name == "sed":
        return sed_count(rest, cwd)
    if name in ("awk", "gawk"):
        return awk_count(rest, cwd)
    return 0


def shell_lines(cmd, cwd):
    """(total lines dumped to stdout, [(file-ish label, lines)])."""
    total, parts, files = 0, [], []
    for stages, redirected in split_segments(tokenize(cmd)):
        first = strip_wrappers(stages[0])
        if first and first[0] == "cd":
            target = first[1] if len(first) > 1 else "~"
            cwd = resolve(target, cwd)
            continue
        # A pipeline is filtering its input; a redirect sends output to a file.
        if len(stages) > 1 or redirected:
            continue
        n = command_lines(stages[0], cwd)
        if n:
            total += n
            parts.append((" ".join(stages[0])[:80], n))
            files += [resolve(a, cwd) for a in stages[0][1:] if os.path.isfile(resolve(a, cwd))]
    return total, parts, files


# --- per-tool analysis ----------------------------------------------------


def read_lines(tool_input, cwd):
    """Claude Read, Kiro read (operations[]) and Kiro fs_read."""
    ops = tool_input.get("operations")
    if not isinstance(ops, list):
        ops = [tool_input]
    total, files = 0, []
    for op in ops:
        if not isinstance(op, dict) or op.get("mode", "Line") != "Line":
            continue
        path = op.get("file_path") or op.get("path") or op.get("filePath")
        if not path:
            continue
        lines = line_count(resolve(path, cwd))
        if lines is None:
            continue
        if "start_line" in op or "end_line" in op:
            start = to_int(op.get("start_line")) or 1
            end = to_int(op.get("end_line"))
            if start < 0:
                start = lines + start + 1
            if end is None or end < 0:
                end = lines if end is None else lines + end + 1
            n = window(lines, start, end - start + 1)
        elif "operations" in tool_input:
            # Kiro `read`: offset is a 0-based line skip, no limit means the rest.
            n = window(lines, (to_int(op.get("offset")) or 0) + 1, to_int(op.get("limit")))
        else:
            # Claude Read: offset is the 1-based start line, default window 2000.
            n = window(lines, to_int(op.get("offset")) or 1, to_int(op.get("limit")) or CLAUDE_READ_WINDOW)
        total += n
        files.append((resolve(path, cwd), lines))
    return total, files


def analyse(payload, harness):
    tool = str(payload.get("tool_name") or payload.get("toolName") or "")
    tool_input = payload.get("tool_input") or payload.get("input") or {}
    if isinstance(tool_input, str):
        tool_input = json.loads(tool_input)
    cwd = payload.get("cwd") or os.getcwd()
    if tool in ("Read", "read", "fs_read", "view", "mcp__fs__read"):
        total, files = read_lines(tool_input, cwd)
        return total, [f"{p} ({n} lines)" for p, n in files], "read", [p for p, _ in files]
    if tool in ("Bash", "bash", "shell", "execute_bash"):
        cmd = tool_input.get("command", "")
        if isinstance(cmd, list):
            cmd = shlex.join(str(c) for c in cmd)
        if not isinstance(cmd, str) or not cmd.strip():
            return 0, [], "shell", []
        total, parts, files = shell_lines(cmd, cwd)
        return total, [f"`{c}` ({n} lines)" for c, n in parts], "shell", files
    return 0, [], "", []


def reason(total, threshold, what, kind, before=0, small=80):
    slice_hint = (
        "a bounded Read (offset/limit)" if kind == "read" else "a narrower range (sed -n 'A,Bp', head -n N) or grep"
    )
    so_far = f" ({before} already read this session)" if before else ""
    return (
        f"SHUNT: this {kind} would bring {total} lines of these files into your context{so_far}, "
        f"threshold {threshold}: {', '.join(what)}. "
        "Do not split the file into smaller slices to get around this. "
        "Delegate the reading to the cheap worker instead:\n"
        f'  bulk-read --question "<exactly what you need>" --paths <file> [<file> ...]\n'
        f"It returns only the answer, with path:line citations. For boilerplate that follows an "
        f'existing file use: code-write --spec "<what>" --reference <file> --target <new file>. '
        f"If you must see exact text to edit or debug it, use {slice_hint} of at most {small} lines."
    )


def session_budget(payload, total, what_files, threshold, small):
    """Return lines this session already pulled from these files, recording the new read.

    Stops the model from sidestepping the gate with many slices under the threshold.
    A read of at most `small` lines is an edit-sized look and is never counted.
    """
    sid = str(payload.get("session_id") or payload.get("sessionId") or "")
    if not sid or total <= small or not what_files:
        return 0
    base = os.environ.get("XDG_RUNTIME_DIR") or os.path.expanduser("~/.cache")
    path = os.path.join(base, "shunt", re.sub(r"[^A-Za-z0-9_.-]", "_", sid) + ".json")
    try:
        with open(path) as fh:
            seen = json.load(fh)
    except (OSError, ValueError):
        seen = {}
    before = max((seen.get(f, 0) for f in what_files), default=0)
    if before + total <= threshold:
        for f in what_files:
            seen[f] = seen.get(f, 0) + total
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as fh:
            json.dump(seen, fh)
    return before


def main():
    harness = "claude"
    if "--harness" in sys.argv:
        harness = sys.argv[sys.argv.index("--harness") + 1]
    conf = load_conf()
    if conf is None:
        return 0
    enabled = conf.get("SHUNT_ENABLED", conf.get("SHUNT_DEFAULT_ENABLED", "0"))
    if enabled != "1":
        return 0
    threshold = to_int(os.environ.get("SHUNT_MIN_LINES")) or to_int(conf.get("SHUNT_THRESHOLD")) or 350
    small = to_int(conf.get("SHUNT_SMALL_READ")) or 80
    payload = json.load(sys.stdin)
    total, what, kind, files = analyse(payload, harness)
    before = 0
    if total <= threshold:
        before = session_budget(payload, total, files, threshold, small)
        if before + total <= threshold:
            return 0
    msg = reason(before + total, threshold, what, kind, before, small)
    if harness in ("kiro", "opencode", "pi"):
        print(msg, file=sys.stderr)
        return 2
    print(
        json.dumps(
            {
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": "deny",
                    "permissionDecisionReason": msg,
                }
            }
        )
    )
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception:  # fail open
        sys.exit(0)
