# Translates the Claude Code permission rules in ./permissions.nix (the single
# source of truth) into the formats opencode and Antigravity (`agy`) read, so
# an allow/deny edit in permissions.nix reaches all three harnesses.
#
# opencode (V2) takes one ordered `permissions` array, last match wins:
#   { action, resource, effect } rules. With bypass-by-default requested, a
#   single allow-all rule comes first and only the deny rules from
#   permissions.nix are emitted after it -- the granular allowlist is
#   redundant under allow-by-default:
#   Bash(x)            -> { action: "shell", resource: x }
#   Read(x)/Grep(x)    -> { action: "read"/"grep", resource: x }
#   everything else    -> covered by the blanket allow rule
#   mcp__srv__tool     -> covered by the blanket allow rule
#   WebFetch(domain:d) -> covered by the blanket allow rule
# agy keeps its per-rule allowlist (it has no blanket-bypass flag), so its
# translation still maps allow and deny rules command-by-command.
{ lib }:
let
  rules = import ./permissions.nix;

  parse =
    r:
    let
      m = builtins.match "([A-Za-z0-9_]+)\\((.*)\\)" r;
    in
    if m == null then
      {
        tool = r;
        arg = null;
      }
    else
      {
        tool = builtins.elemAt m 0;
        arg = builtins.elemAt m 1;
      };

  isMcp = p: lib.hasPrefix "mcp__" p.tool && !(lib.hasPrefix "mcp__claude_ai_" p.tool);
  mcpParts =
    p:
    let
      parts = lib.splitString "__" p.tool;
    in
    {
      server = builtins.elemAt parts 1;
      name = lib.concatStringsSep "__" (lib.drop 2 parts);
    };

  # `Bash(run_in_backgroun:true)` is a Claude-side typo'd flag, not a command.
  isBashRule = p: p.tool == "Bash" && p.arg != null && !(lib.hasPrefix "run_in_backgroun" p.arg);

  allow = map parse rules.allow;
  deny = map parse rules.deny;

  # --- opencode ---------------------------------------------------------
  # V2 `permissions` array: blanket allow first (the --dangerously-skip-
  # permissions equivalent the user asked for), then every deny rule from
  # permissions.nix. Last match wins, so a deny always beats the blanket
  # allow, and secrets/.env/pass/gpg stay protected while nothing else
  # prompts.
  opencodeRules =
    [ { action = "*"; resource = "*"; effect = "allow"; } ]
    ++ map (p: { action = "shell"; resource = p.arg; effect = "deny"; }) (lib.filter isBashRule deny)
    ++ map (p: { action = "read"; resource = p.arg; effect = "deny"; }) (
      lib.filter (p: p.tool == "Read" && p.arg != null) deny
    )
    ++ map (p: { action = "grep"; resource = p.arg; effect = "deny"; }) (
      lib.filter (p: p.tool == "Grep" && p.arg != null) deny
    );

  opencode = {
    rules = opencodeRules;
  };

  # --- agy --------------------------------------------------------------
  agy = {
    allow =
      map (p: "command(${p.arg})") (lib.filter isBashRule allow)
      ++ map (
        p:
        let
          m = mcpParts p;
        in
        "mcp(${m.server}/${m.name})"
      ) (lib.filter isMcp allow);
    deny = map (p: "command(${p.arg})") (lib.filter isBashRule deny);
  };
in
{
  inherit opencode agy;
}
