# Registers every package built by ../../pkgs/pi-extensions.nix with pi,
# using pi's "local path" package source (see the packages.md link in
# pi-extensions.nix): a local-path entry in ~/.pi/agent/settings.json is
# used directly from where it sits, no npm install and no copy. This is
# deliberately not the ~/.pi/agent/npm/ mechanism a real
# `pi install npm:<pkg>` uses (and this module used to use for
# pi-claude-bridge alone) -- that directory is shared with whatever the
# user installs by hand later, and symlinking over it wholesale would
# fight a manual `pi install` on every `home-manager switch`. A local-path
# entry touches nothing else pi owns.
{ config, pkgs, ... }:
let
  custom = import ../../pkgs { inherit pkgs; };

  # Every node_modules/<name> subdirectory built by pi-extensions.nix,
  # matching the package list documented there. Order matters: pi-vim's own
  # README requires it load before any other editor-wrapping extension
  # ("Supported extension order: pi-vim first"), so it comes first here and
  # the activation script below preserves this order rather than appending.
  packageNames = [
    "pi-vim"
    "pi-claude-bridge"
    "pi-subagents"
    "pi-mcp-adapter"
    "pi-web-access"
    "context-mode"
    "pi-background-tasks"
    "@companion-ai/feynman"
    "@plannotator/pi-extension"
    "@dietrichgebert/ponytail"
    "pi-lens"
    "@ff-labs/pi-fff"
    "pi-goal-x"
    "@narumitw/pi-plan-mode"
    "@mjasnikovs/pi-task"
  ];

  # A real absolute path (not a shell $HOME) -- this string is embedded
  # verbatim into a single-quoted --argjson value below, where the shell
  # would never expand $HOME.
  vendorLink = "${config.home.homeDirectory}/.local/share/pi-extensions-vendor";
  localPaths = builtins.map (name: "${vendorLink}/node_modules/${name}") packageNames;
in
{
  home.file.".local/share/pi-extensions-vendor".source = custom.pi-extensions;

  # entryAfter writeBoundary: the home.file symlink above must exist first
  # for these paths to resolve.
  #
  # Nix-managed paths go first, in the exact order declared above (pi-vim
  # first) -- a plain unique-append would put pi-vim wherever it happened
  # to land relative to whatever pi wrote before, which breaks its load
  # order requirement. Anything already in settings.json that isn't one of
  # our paths (a manual `pi install`, or an npm: source) is kept, appended
  # after, so this stays additive rather than a wholesale replace.
  home.activation.piExtensionsSettings = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "$HOME/.pi/agent"
    [ -f "$HOME/.pi/agent/settings.json" ] || echo '{}' > "$HOME/.pi/agent/settings.json"

    # defaultProvider/defaultModel pin auth to GEMINI_API_KEY (exported from
    # `pass show gemini` in programs.zsh.initContent -- see antigravity.nix),
    # so pi never drops into an interactive login flow. Only set when
    # missing, so a provider/model picked by hand survives a rebuild.
    ${pkgs.jq}/bin/jq \
      --argjson paths ${pkgs.lib.escapeShellArg (builtins.toJSON localPaths)} \
      '.packages = ($paths + ((.packages // []) - $paths))
       | .defaultProvider = (.defaultProvider // "google")
       | .defaultModel = (.defaultModel // "gemini-3.6-flash")' \
      "$HOME/.pi/agent/settings.json" > "$HOME/.pi/agent/settings.json.tmp"
    mv "$HOME/.pi/agent/settings.json.tmp" "$HOME/.pi/agent/settings.json"
  '';
}
