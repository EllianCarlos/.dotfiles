# Claude Code: the generated ~/.claude/settings.json, the MCP server list in
# ~/.claude.json, and the vendored skill/hook/statusline payloads.
#
# settings.json and .claude.json are MERGED into rather than overwritten,
# because both files also hold unmanaged runtime state (OAuth tokens,
# per-project history) that Nix must not clobber. mcpServers is the one
# exception: it is replaced wholesale, because a deep merge lets a server
# removed from mcp.nix survive forever as a stale key.
{ config, pkgs, ... }:
let
  hooksDir = "${config.home.homeDirectory}/.claude/hooks/mnemon";
  claudeHooksDir = "${config.home.homeDirectory}/.claude/hooks";

  claudePermissions = import ./permissions.nix;

  claudeSettingsFile = pkgs.writeText "claude-settings.json" (
    builtins.toJSON {
      outputStyle = "ASD-STE100";
      permissions = claudePermissions;
      statusLine = {
        type = "command";
        command = "${config.home.homeDirectory}/.claude/statusline-command.sh";
      };
      # --- mnemon hooks ---
      hooks = {
        SessionStart = [
          {
            hooks = [
              {
                type = "command";
                command = "${hooksDir}/prime.sh";
              }
            ];
          }
        ];
        Stop = [
          {
            hooks = [
              {
                type = "command";
                command = "${hooksDir}/stop.sh";
              }
            ];
          }
        ];
        UserPromptSubmit = [
          {
            hooks = [
              {
                type = "command";
                command = "${hooksDir}/user_prompt.sh";
              }
            ];
          }
        ];
        PostToolUse = [
          {
            matcher = "Edit|Write";
            hooks = [
              {
                type = "command";
                command = "${claudeHooksDir}/validate-config.sh";
              }
            ];
          }
          {
            matcher = "Edit|MultiEdit|Write";
            hooks = [
              {
                type = "command";
                command = "${claudeHooksDir}/format-on-write.sh";
              }
            ];
          }
        ];
      };
    }
  );

  claudeMcpFile = (import ../../mcp.nix { inherit pkgs; }).claude;
in
{
  home.file = {
    # --- mnemon ---
    ".mnemon/prompt/guide.md".source = ../../files/mnemon/guide.md;
    ".mnemon/prompt/skill.md".source = ../../files/mnemon/skill.md;
    ".claude/skills/mnemon/SKILL.md".source = ../../files/mnemon/skill.md;
    ".claude/hooks/mnemon/prime.sh" = {
      source = ../../files/mnemon/hooks/prime.sh;
      executable = true;
    };
    ".claude/hooks/mnemon/stop.sh" = {
      source = ../../files/mnemon/hooks/stop.sh;
      executable = true;
    };
    ".claude/hooks/mnemon/user_prompt.sh" = {
      source = ../../files/mnemon/hooks/user_prompt.sh;
      executable = true;
    };

    # --- nixapply ---
    ".claude/skills/nixapply/SKILL.md".source = ../../files/nixapply/skill.md;

    # --- global Claude Code instructions ---
    ".claude/CLAUDE.md".source = ../../files/claude/CLAUDE.md;

    # --- output styles ---
    ".claude/output-styles/asd-ste100.md".source = ../../files/claude/output-styles/asd-ste100.md;

    # --- statusline ---
    ".claude/statusline-command.sh" = {
      source = ../../files/claude/statusline/command.sh;
      executable = true;
    };

    # --- Config validation hook ---
    ".claude/hooks/validate-config.sh" = {
      source = ../../files/claude/hooks/validate-config.sh;
      executable = true;
    };

    # --- watermarks-remover ---
    ".claude/hooks/format-on-write.sh" = {
      source = ../../files/claude/hooks/format-on-write.sh;
      executable = true;
    };
  };

  home.activation.claudeSettings = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "$HOME/.claude"

    # --- settings.json ---
    if [ -f "$HOME/.claude/settings.json" ]; then
      ${pkgs.jq}/bin/jq -s '.[0] * .[1]' "$HOME/.claude/settings.json" ${claudeSettingsFile} > "$HOME/.claude/settings.json.tmp"
      mv "$HOME/.claude/settings.json.tmp" "$HOME/.claude/settings.json"
    else
      cp ${claudeSettingsFile} "$HOME/.claude/settings.json"
    fi
    chmod 644 "$HOME/.claude/settings.json"

    # --- .claude.json ---
    if [ -f "$HOME/.claude.json" ]; then
      ${pkgs.jq}/bin/jq -s '.[0] as $old | .[1] as $new | ($old * $new) | .mcpServers = $new.mcpServers' "$HOME/.claude.json" ${claudeMcpFile} > "$HOME/.claude.json.tmp"
      mv "$HOME/.claude.json.tmp" "$HOME/.claude.json"
    else
      cp ${claudeMcpFile} "$HOME/.claude.json"
    fi
    chmod 644 "$HOME/.claude.json"
  '';
}
