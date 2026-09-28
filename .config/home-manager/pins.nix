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
    rev = "9b2a27cab506cbc8fe9b1cbe853c5c1eaad4d392"; # upstream HEAD -- repo
    # cuts no tags.
  };
  claude-code-nix = {
    owner = "sadjow";
    repo = "claude-code-nix";
    rev = "041321f576473e072ebe03d6d9a3e79a2aad9580"; # v2.1.284, also upstream HEAD
  };
  agent-skills-nix = {
    owner = "Kyure-A";
    repo = "agent-skills-nix";
    rev = "dc122af897ab9a685c20ae54c639021619dbbb52"; # upstream HEAD -- repo
    # cuts no tags.
  };
  opencode-nixpkgs-pin = {
    owner = "NixOS";
    repo = "nixpkgs";
    rev = "d71342c80129583070161e75dca16a24749472a9"; # opencode 1.18.31
  };
  loop-engineering = {
    owner = "cobusgreyling";
    repo = "loop-engineering";
    rev = "c16e99ce5d048edfa602f021fdb0f3087ec2b464"; # upstream HEAD -- this
    # repo's tags (loop-worktree-vX, readiness-core-vX, vX) are per-subtool,
    # not one release line for the whole repo, so there's no single "latest
    # tag" to prefer over HEAD here; see project-pin-bump-prefer-tagged-release.
  };
  superpowers = {
    owner = "obra";
    repo = "superpowers";
    rev = "8ca22dba9a94f28898bbce59f2537ff4d87c747d"; # v6.4.2
  };
  mattpocock-skills = {
    owner = "mattpocock";
    repo = "skills";
    rev = "6acc160e4e0cd062dbbbd7a1b26ae92855edf07e"; # v1.2.3 -- still the
    # latest tag; upstream HEAD (c55ee46073ed923f86ce59a5eb3b6d895095d1b7 as of
    # 2026-09-28) is further commits past it with no new release cut yet; see
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
    rev = "e50011df0e2c553898ae5fe55f16b602391143d6"; # upstream HEAD, not the
    # v0.1.5 tag (977a1a8) -- still no release cut since; HEAD is where
    # "Add Cargo.lock" (what buildRustPackage's cargoLock.lockFile needs)
    # lives. See project-pin-bump-prefer-tagged-release for why tag is
    # normally preferred -- this is the documented exception.
  };
  watermarks-remover = {
    owner = "guillaumemeyer";
    repo = "watermarks-remover";
    rev = "321d93d2efd6a8b26915c5eb5193d9d1701e2c4b"; # v0.7.0 -- upstream HEAD
    # (258cf20cdc2906e24398b3d6f3bc3cbcfd578245 as of 2026-09-28) is further
    # commits past this tag with no new release cut yet; see
    # project-pin-bump-prefer-tagged-release.
  };
  academic-research-skills = {
    owner = "Imbad0202";
    repo = "academic-research-skills";
    rev = "7de1c9dfb7af9c02a9b57750761323f35a743aa2"; # v3.22.2 -- upstream HEAD
    # (e79085d0d38609984ef8cfe0faf2d254aac9e0a9 as of 2026-09-28) is further
    # commits past this tag with no new release cut yet; see
    # project-pin-bump-prefer-tagged-release.
  };
  openlogi = {
    owner = "AprilNEA";
    repo = "OpenLogi";
    rev = "bc21025d7a96faa8bb0f8dfeb880664a2daa3c31"; # v0.8.9
  };
  zen-browser = {
    owner = "0xc000022070";
    repo = "zen-browser-flake";
    rev = "e50ed94ebf28bae95397e482dbb1c020f50c20c1"; # HEAD -- upstream's
    # tags are named "twilight-<hash>" per Zen Browser build, not per
    # flake release, so they track a different thing than this pin does.
    # HEAD is the flake's own moving pin to the latest Zen build.
  };
}
