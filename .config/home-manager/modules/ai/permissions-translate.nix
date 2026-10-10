# Translates the Claude Code permission rules in ./permissions.nix (the single
# source of truth) into the formats opencode and Antigravity (`agy`) read, so
# an allow/deny edit in permissions.nix reaches all three harnesses.
#
# Rules carry over by tool kind:
#   Bash(x)            -> opencode permission.bash["x"]   | agy command(x)
#   mcp__srv__tool     -> opencode permission["srv_tool"] | agy mcp(srv/tool)
#   Read/Grep/Glob/... -> the matching opencode permission key (agy has no
#                         equivalent rule kind, so those are dropped there)
#   WebFetch(domain:d) -> opencode permission.webfetch URL globs
# claude.ai connector MCP servers don't exist outside Claude, so they're skipped.
#
# opencode evaluates rule maps last-match-wins in config order, and Nix
# attrsets sort their keys, so `ordered` is emitted as [pattern action] pairs
# for the activation script's jq to fold into an object in that order.
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

  # Bare-tool allow rules -> opencode permission key.
  simpleKeys = {
    Skill = "skill";
    Agent = "task";
    LSP = "lsp";
    WebSearch = "websearch";
    Grep = "grep";
    Glob = "glob";
    Read = "read";
    Edit = "edit";
    Write = "edit";
    MultiEdit = "edit";
    TaskCreate = "todowrite";
    TaskUpdate = "todowrite";
  };

  # `Bash(run_in_backgroun:true)` is a Claude-side typo'd flag, not a command.
  isBashRule = p: p.tool == "Bash" && p.arg != null && !(lib.hasPrefix "run_in_backgroun" p.arg);

  allow = map parse rules.allow;
  deny = map parse rules.deny;

  # --- opencode ---------------------------------------------------------
  # Per tool, an ordered [pattern action] list: ask-by-default first, then
  # allows, then denies (last match wins, so deny beats a broader allow).
  bashPairs =
    [ [ "*" "ask" ] ]
    ++ map (p: [ p.arg "allow" ]) (lib.filter isBashRule allow)
    ++ map (p: [ p.arg "deny" ]) (lib.filter isBashRule deny);

  readPairs =
    lib.optional (lib.any (p: p.tool == "Read") allow) [ "*" "allow" ]
    ++ map (p: [ p.arg "deny" ]) (lib.filter (p: p.tool == "Read" && p.arg != null) deny);

  webfetchPairs = lib.concatMap (
    p:
    let
      d = lib.removePrefix "domain:" p.arg;
    in
    lib.optionals (p.tool == "WebFetch" && p.arg != null) [
      [ "*://${d}/*" "allow" ]
    ]
  ) allow;

  mcpAllows = lib.unique (
    map (
      p:
      let
        m = mcpParts p;
      in
      "${m.server}_${m.name}"
    ) (lib.filter isMcp allow)
  );

  # `read` is excluded: it goes through `ordered` so its deny rules apply.
  simpleAllows = lib.unique (
    lib.filter (k: k != "read") (
      map (p: simpleKeys.${p.tool}) (lib.filter (p: (p.arg == null || p.arg == "*") && simpleKeys ? ${p.tool}) allow)
    )
  );

  opencode = {
    ordered = {
      bash = bashPairs;
    }
    // lib.optionalAttrs (readPairs != [ ]) { read = readPairs; }
    // lib.optionalAttrs (webfetchPairs != [ ]) { webfetch = webfetchPairs; };
    # Keys that take a plain action (opencode MCP tools match by flat name).
    simple = lib.genAttrs (simpleAllows ++ mcpAllows) (_: "allow");
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
