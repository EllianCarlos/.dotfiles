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
    rev = "c30be6c96fceae9a91ac3b145862b507466a625d"; # upstream HEAD -- repo
    # cuts no tags.
  };
  claude-code-nix = {
    owner = "sadjow";
    repo = "claude-code-nix";
    rev = "a652fdf13cf7ac39be23fafbca3e1d6290eff001"; # v2.1.241, also upstream HEAD
  };
  agent-skills-nix = {
    owner = "Kyure-A";
    repo = "agent-skills-nix";
    rev = "1594ba479be81a7cb6dd19faabefcb1ed5b3f964";
  };
  loop-engineering = {
    owner = "cobusgreyling";
    repo = "loop-engineering";
    rev = "1485cd64e9a87f6222eebef420e6f9a29ffdb397"; # upstream HEAD -- this
    # repo's tags (loop-worktree-vX, readiness-core-vX, vX) are per-subtool,
    # not one release line for the whole repo, so there's no single "latest
    # tag" to prefer over HEAD here; see project-pin-bump-prefer-tagged-release.
  };
  superpowers = {
    owner = "obra";
    repo = "superpowers";
    rev = "b36e0829c6d0140e93cfef2ca599b1b07d4a7797"; # v6.3.0
  };
  mattpocock-skills = {
    owner = "mattpocock";
    repo = "skills";
    rev = "6acc160e4e0cd062dbbbd7a1b26ae92855edf07e"; # v1.2.3 -- still the
    # latest tag; upstream HEAD (5b15a47f2d7150f545fbcacbfe381787fc0230dc) is
    # a few commits past it with no new release cut yet; see
    # project-pin-bump-prefer-tagged-release.
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
    rev = "523ebf9e440167b3206b0b36632095c1cee9810c"; # upstream HEAD, not the
    # v0.1.5 tag (977a1a8) -- HEAD is 5 commits past that tag, and one of
    # those commits ("Add Cargo.lock") is what buildRustPackage's
    # cargoLock.lockFile needs; the tagged release predates it. See
    # project-pin-bump-prefer-tagged-release for why tag is normally
    # preferred -- this is the documented exception.
  };
  watermarks-remover = {
    owner = "guillaumemeyer";
    repo = "watermarks-remover";
    rev = "dc0ff78f39bedfe0a1986eef54efb297645372ba"; # v0.5.0 -- upstream HEAD
    # (0148d764794b30623edebf3215e1d14272460e7d) is further commits past
    # this tag with no new release cut yet; see
    # project-pin-bump-prefer-tagged-release.
  };
  academic-research-skills = {
    owner = "Imbad0202";
    repo = "academic-research-skills";
    rev = "37704469a1cdc09f7a1c05d22b0f91d11a1705bf"; # v3.21.0 -- upstream
    # HEAD (385bc064e19ac1ddab3438025946dd049f490fcd) is past this tag with
    # no new release cut yet; see project-pin-bump-prefer-tagged-release.
  };
  zen-browser = {
    owner = "0xc000022070";
    repo = "zen-browser-flake";
    rev = "b49e5b7b3f925b78b2af9ca21e81e8c0d1a4711e"; # HEAD -- upstream's
    # tags are named "twilight-<hash>" per Zen Browser build, not per
    # flake release, so they track a different thing than this pin does.
    # HEAD is the flake's own moving pin to the latest Zen build.
  };
}
