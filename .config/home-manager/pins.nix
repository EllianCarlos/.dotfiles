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
    rev = "47945d9392b28359ff15abc4837f669306afbdca"; # upstream HEAD -- repo
    # cuts no tags.
  };
  claude-code-nix = {
    owner = "sadjow";
    repo = "claude-code-nix";
    rev = "2c0782ecf4d07e4395cb56b33555fa4eb30f6784"; # upstream HEAD (= floating "latest"/"v2" tags; past v2.1.319)
  };
  agent-skills-nix = {
    owner = "Kyure-A";
    repo = "agent-skills-nix";
    rev = "93a02cb60eda167de8c5baa085e4a2bcfc71b885"; # upstream HEAD -- repo
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
    rev = "9266f07ab66c60f48ae19d8dda60536839ad7d1e"; # opencode (nixpkgs HEAD as of 2026-11-09)
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
    rev = "260e575bf5fa6f0636ab3fdd7122b430f8b2d1f9"; # upstream HEAD -- this
    # repo's tags (loop-worktree-vX, readiness-core-vX, vX) are per-subtool,
    # not one release line for the whole repo, so there's no single "latest
    # tag" to prefer over HEAD here; see project-pin-bump-prefer-tagged-release.
  };
  superpowers = {
    owner = "obra";
    repo = "superpowers";
    rev = "22f0b463e7a5e579904dd6211a520321035526f7"; # v7.0.2 -- latest tag (= upstream HEAD)
  };
  mattpocock-skills = {
    owner = "mattpocock";
    repo = "skills";
    rev = "d1478fcb140db0b93c0c8df17bcfd311844749d0"; # v1.3.2 -- latest tag; upstream HEAD is past it
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
    rev = "8e73f057d54a58486a7589b9cce5a91e5ea85c83"; # upstream HEAD, not the
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
    rev = "36b22af2ff7b463e5f616f1d616a8f0cb7f43c35"; # v3.24.3 -- latest tag; upstream HEAD
    # (6d938867 as of 2026-11-09) is past it; see project-pin-bump-prefer-tagged-release.
  };
  zen-browser = {
    owner = "0xc000022070";
    repo = "zen-browser-flake";
    rev = "cb44a9fc1faa18c55dde38a8338f6d46fa2bc6de"; # HEAD -- upstream's
    # tags are named "twilight-<hash>" per Zen Browser build, not per
    # flake release, so they track a different thing than this pin does.
    # HEAD is the flake's own moving pin to the latest Zen build.
  };
}
