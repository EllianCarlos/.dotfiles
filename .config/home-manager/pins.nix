# Single source of truth for every pinned upstream commit this config
# fetches directly (fetchTarball / builtins.getFlake), replacing formerly
# unpinned main/master-tracking fetches in mcp.nix, home.nix, and
# skills.nix. Consumed two ways:
#   - mcp.nix / home.nix / skills.nix `import` this to build the pinned
#     fetch URL / flake-ref -- so there is exactly one place that says
#     "this is the commit we're on" per dependency.
#   - pin-check.nix's check-nix-pins script reads this via
#     `nix eval --json --file`, so it never has to parse Nix source with
#     grep/regex -- it evaluates the real data through the real evaluator.
#
# To bump a pin: update `rev` here to the new upstream commit SHA. Nothing
# else needs to change.
{
  mcp-servers-nix = {
    owner = "natsukium";
    repo = "mcp-servers-nix";
    rev = "1cba7df106cb8ddf92f73c09ea725283bd470675"; # upstream HEAD -- repo
    # cuts no tags.
  };
  claude-code-nix = {
    owner = "sadjow";
    repo = "claude-code-nix";
    rev = "c932f70402686f018d829534d71f9e8ba7859cfb"; # v2.1.303 -- latest tag (= upstream HEAD)
  };
  agent-skills-nix = {
    owner = "Kyure-A";
    repo = "agent-skills-nix";
    rev = "2948865044b2af55c8c4e4eb2abda7de79d60f0e"; # upstream HEAD -- repo
    # cuts no tags.
  };
  hermes-agent = {
    owner = "NousResearch";
    repo = "hermes-agent";
    rev = "f97608f178d1ffeca59860195ab7da295f7c8e5f"; # v2026.9.24 -- latest tag
  };
  opencode-nixpkgs-pin = {
    owner = "NixOS";
    repo = "nixpkgs";
    rev = "0d927ee3b4dfd77e453f28d6289e58d55136975b"; # opencode 1.19.0
  };
  # zotero 10.0.4 (nixpkgs bae6f80, 2026-10-01) fails to build: its omni.ja
  # patch can't find AboutTranslations in ActorManagerParent.sys.mjs. Last
  # nixpkgs commit with a working zotero is 10.0.2. Unfreeze (drop `frozen`
  # and the zoteroPinned override in modules/packages.nix) once fixed upstream.
  zotero-nixpkgs-pin = {
    owner = "NixOS";
    repo = "nixpkgs";
    rev = "363fdbe57ed052c76e816e6270206b0cb348e53a"; # zotero 10.0.2
    frozen = true;
  };
  # fcitx5-mozc 2.30.5544.102 on current nixpkgs fails to build: Qt's uic
  # rejects "::mozc::gui::DictionaryContentTableWidget" in dictionary_tool.ui.
  # nixpkgs 363fdbe still has a cached, working build. Unfreeze (drop `frozen`
  # and the mozcPinned override in modules/desktop/input-method.nix) once fixed.
  mozc-nixpkgs-pin = {
    owner = "NixOS";
    repo = "nixpkgs";
    rev = "363fdbe57ed052c76e816e6270206b0cb348e53a"; # fcitx5-mozc 2.30.5544.102
    frozen = true;
  };
  loop-engineering = {
    owner = "cobusgreyling";
    repo = "loop-engineering";
    rev = "86ca6e2786cb8dc7478bdbb6fad9963a7d3d4486"; # upstream HEAD -- this
    # repo's tags (loop-worktree-vX, readiness-core-vX, vX) are per-subtool,
    # not one release line for the whole repo, so there's no single "latest
    # tag" to prefer over HEAD here; see project-pin-bump-prefer-tagged-release.
  };
  superpowers = {
    owner = "obra";
    repo = "superpowers";
    rev = "bb92a77741419a4ab5f06e711a283343f1ada0c3"; # v7.0.0
  };
  mattpocock-skills = {
    owner = "mattpocock";
    repo = "skills";
    rev = "24fe0ef7737efae15c87225755e9f6f5965e4888"; # v1.3.1 -- latest tag; upstream HEAD is past it
  };
  mattpocock-skills-personal = {
    owner = "mattpocock";
    repo = "skills";
    rev = "ed37663cc5fbef691ddfecd080dff42f7e7e350d";
    frozen = true;
  };
  resurrect-wezterm = {
    owner = "MLFlexer";
    repo = "resurrect.wezterm";
    rev = "65cbbbf6d2c76f3e36af7610a356fc190fcb6147";
  };
  wb-headset = {
    owner = "Henriklmao";
    repo = "waybar-headsetcontrol";
    rev = "4a92e6fc420af8603796c08d7369b0226221caa2"; # upstream HEAD, not the
    # v0.1.5 tag (977a1a8) -- still no release cut since; HEAD is where
    # "Add Cargo.lock" (what buildRustPackage's cargoLock.lockFile needs)
    # lives. See project-pin-bump-prefer-tagged-release for why tag is
    # normally preferred -- this is the documented exception.
  };
  watermarks-remover = {
    owner = "guillaumemeyer";
    repo = "watermarks-remover";
    rev = "321d93d2efd6a8b26915c5eb5193d9d1701e2c4b"; # v0.7.0 -- upstream HEAD
    # (c5297e9e as of 2026-10-10) is further
    # commits past this tag with no new release cut yet; see
    # project-pin-bump-prefer-tagged-release.
  };
  academic-research-skills = {
    owner = "Imbad0202";
    repo = "academic-research-skills";
    rev = "4c5449017f46eb64d112a301d4817d22c7c9f3d9"; # v3.23.1 -- latest tag; upstream HEAD is past it
  };
  openlogi = {
    owner = "AprilNEA";
    repo = "OpenLogi";
    rev = "c542cd7e7df16d6c992d4ccc6ed3e65e5c4f222f"; # v0.8.14 -- latest tag; upstream HEAD
    # (a006f5d6 as of 2026-10-10) is further
    # commits past this tag with no new release cut yet; see
    # project-pin-bump-prefer-tagged-release.
  };
  zen-browser = {
    owner = "0xc000022070";
    repo = "zen-browser-flake";
    rev = "e1b9b3578ebb388b56012cd9ddd80e19681d2d39"; # HEAD -- upstream's
    # tags are named "twilight-<hash>" per Zen Browser build, not per
    # flake release, so they track a different thing than this pin does.
    # HEAD is the flake's own moving pin to the latest Zen build.
  };
}
