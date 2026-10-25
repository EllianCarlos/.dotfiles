{ config, pkgs, ... }:
let
  lib = pkgs.lib;
  pins = import ../../pins.nix;
  hermesFlake = builtins.getFlake "github:${pins.hermes-agent.owner}/${pins.hermes-agent.repo}/${pins.hermes-agent.rev}";
  custom = import ../../pkgs { inherit pkgs; };

  mcpFile = (import ./mcp.nix { inherit pkgs; }).claude;
  claudeMcp =
    (builtins.fromJSON (builtins.unsafeDiscardStringContext (builtins.readFile mcpFile))).mcpServers;
  mcpServers = lib.mapAttrs (
    _: s:
    lib.filterAttrs (_: v: v != null) {
      command = s.command or null;
      args = s.args or [ ];
      env = s.env or { };
      url = s.url or null;
      headers = s.headers or { };
    }
  ) claudeMcp;

  recallPath = lib.makeBinPath [
    pkgs.jq
    custom.mnemon
    pkgs.coreutils
  ];
  mnemonRecall = pkgs.writeShellScript "hermes-mnemon-recall.sh" ''
    export PATH=${recallPath}:$PATH
    prompt="$(jq -r '.extra.user_message // empty')"
    [ -n "$prompt" ] || exit 0
    out="$(jq -n --arg p "$prompt" '{prompt: $p}' | ${pkgs.bash}/bin/bash ${../../files/mnemon/hooks/user_prompt.sh})"
    [ -n "$out" ] || exit 0
    jq -n --arg c "$out" '{context: $c}'
  '';

  cheapModel = "gemini-3.6-flash";
in
{
  imports = [ hermesFlake.homeManagerModules.default ];

  programs.hermes-agent.enable = true;

  home.extraDependencies = [ mcpFile ];

  services.hermes-agent = {
    enable = true;
    inherit mcpServers;

    hermesHomeFiles."SOUL.md" = ../../files/hermes/SOUL.md;

    settings = {
      model = {
        provider = "gemini";
        default = cheapModel;
      };

      delegation = {
        provider = "gemini";
        model = cheapModel;
        fallback_providers = map (m: {
          provider = "gemini";
          model = m;
        }) (lib.remove cheapModel config.ai.shunt.chain);
      };

      skills = {
        external_dirs = [ "~/.claude/skills" ];
        write_approval = true;
      };

      hooks_auto_accept = true;
      hooks = {
        pre_tool_call = [
          {
            matcher = "read_file|terminal";
            command = config.ai.shunt.hermesHookCommand;
            timeout = 10;
          }
        ];
        pre_llm_call = [
          {
            command = "${mnemonRecall}";
            timeout = 30;
          }
        ];
      };
    };
  };
}
