# opencode-claude (@openchamber/opencode-claude) -- lets opencode run
# Claude models by spawning the real, locally-authenticated `claude` CLI
# through Anthropic's own Agent SDK, proxied as an OpenAI-compatible
# provider. Not in nixpkgs. Same architecture and same rationale as
# pi-claude-bridge.nix (a Claude Pro/Max subscription authenticating the
# real Claude Code binary, not a token extracted and replayed by a
# third-party client -- see https://code.claude.com/docs/en/legal-and-compliance,
# "Authentication and credential use": this plugin explicitly documents
# that it never reads, copies, or sends Claude Code's credentials itself.
#
# vendor/opencode-claude/{package.json,package-lock.json} pin a throwaway
# npm project whose only dependency is @openchamber/opencode-claude, the
# same shape `opencode plugin @openchamber/opencode-claude` builds for
# itself. Unlike pi, opencode does not vendor its plugins into a
# dedicated npm project directory under a name Nix can safely symlink
# over wholesale -- ~/.config/opencode/node_modules is opencode's own,
# shared with its other runtime deps. modules/ai/opencode.nix instead
# points opencode.jsonc's `plugin` array at this derivation's built
# opencode-claude.js directly via a file:// URL (verified working: doing
# so makes claude-code/* show up in `opencode models`), leaving
# opencode's own node_modules untouched.
{ pkgs, ... }:
pkgs.buildNpmPackage {
  pname = "opencode-claude-vendor";
  version = "0.14.0";
  src = ./vendor/opencode-claude;
  npmDepsHash = "sha256-OXwNpMGZ5J5UTix2SoaqiLaxc88bEiGNu0PQf3DgLDk=";
  dontNpmBuild = true;
  installPhase = ''
    mkdir -p $out
    cp -r node_modules $out/node_modules
  '';
}
