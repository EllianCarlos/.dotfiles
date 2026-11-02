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
    rev = "deffe043ca9d2b344875802f0dcff6abc07d3dc9"; # upstream HEAD -- repo
    # cuts no tags.
  };
  claude-code-nix = {
    owner = "sadjow";
    repo = "claude-code-nix";
    rev = "b89e273e45ef0ea122e3410f55dd7a102e71f453"; # v2.1.316 -- latest tag (= upstream HEAD)
  };
  agent-skills-nix = {
    owner = "Kyure-A";
    repo = "agent-skills-nix";
    rev = "f48aa227f3d157ae3abda12cd9c4ab867f400419"; # upstream HEAD -- repo
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
    rev = "6f0277a4d511a434576503077c6846e76389cda1"; # opencode (nixpkgs HEAD as of 2026-11-02)
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
    rev = "b2540bdd4ef3a8df67b44c4f3ad7d363ac30d1ff"; # upstream HEAD -- this
    # repo's tags (loop-worktree-vX, readiness-core-vX, vX) are per-subtool,
    # not one release line for the whole repo, so there's no single "latest
    # tag" to prefer over HEAD here; see project-pin-bump-prefer-tagged-release.
  };
  superpowers = {
    owner = "obra";
    repo = "superpowers";
    rev = "2ce8aa15d05bd57213e6f746f953aafb7ded7a8b"; # v7.0.1
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
    rev = "bcbcac39e874744cda98d6ddaaf765cfd00b0e40"; # v3.24.1 -- latest tag (= upstream HEAD)
  };
  openlogi = {
    owner = "AprilNEA";
    repo = "OpenLogi";
    rev = "c542cd7e7df16d6c992d4ccc6ed3e65e5c4f222f"; # v0.8.14 -- frozen: v0.8.18's flake.nix
    # calls builtins.warn, which the installed Nix lacks ("attribute 'warn'
    # missing"). Unfreeze once Nix has builtins.warn. Upstream HEAD
    # (a1c7241d as of 2026-10-27) is further along.
    frozen = true;
  };
  zen-browser = {
    owner = "0xc000022070";
    repo = "zen-browser-flake";
    rev = "536b03dea1ab7460afd44565e81f0a72c371c70f"; # HEAD -- upstream's
    # tags are named "twilight-<hash>" per Zen Browser build, not per
    # flake release, so they track a different thing than this pin does.
    # HEAD is the flake's own moving pin to the latest Zen build.
  };
}
