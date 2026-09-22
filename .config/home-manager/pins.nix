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
    rev = "9de4bccf471171621f8a294c1a812d4cc88c78e3"; # upstream HEAD -- repo
    # cuts no tags.
  };
  claude-code-nix = {
    owner = "sadjow";
    repo = "claude-code-nix";
    rev = "736ada361161f0a3e69844e3918b6e9bc69ed035"; # v2.1.278, also upstream HEAD
  };
  agent-skills-nix = {
    owner = "Kyure-A";
    repo = "agent-skills-nix";
    rev = "5133c874553c6c295654d8de4e3f62c95736b9c6";
  };
  opencode-nixpkgs-pin = {
    owner = "NixOS";
    repo = "nixpkgs";
    rev = "c27cdad491a991b11ed731760aa2ef8db0cb0410";
  };
  loop-engineering = {
    owner = "cobusgreyling";
    repo = "loop-engineering";
    rev = "64ab3ab795117b5fb74358e1de22cc565cdc6054"; # upstream HEAD -- this
    # repo's tags (loop-worktree-vX, readiness-core-vX, vX) are per-subtool,
    # not one release line for the whole repo, so there's no single "latest
    # tag" to prefer over HEAD here; see project-pin-bump-prefer-tagged-release.
  };
  superpowers = {
    owner = "obra";
    repo = "superpowers";
    rev = "5bf4e78011075bcfc0dc295f0724994cd123ee71"; # v6.4.1
  };
  mattpocock-skills = {
    owner = "mattpocock";
    repo = "skills";
    rev = "6acc160e4e0cd062dbbbd7a1b26ae92855edf07e"; # v1.2.3 -- still the
    # latest tag; upstream HEAD (74ca5fe077456a0b3b2f5310cf9430999fd0b5fd as of
    # 2026-09-17) is further commits past it with no new release cut yet; see
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
    # (e4d2bd49c4cb84c5fddb50f5361618cfb3b75def as of 2026-09-17) is further
    # commits past this tag with no new release cut yet; see
    # project-pin-bump-prefer-tagged-release.
  };
  academic-research-skills = {
    owner = "Imbad0202";
    repo = "academic-research-skills";
    rev = "3c546bc08c56f79e0068f1ea4f0acedf5bf69b5e"; # v3.22.0, also upstream
    # HEAD.
  };
  openlogi = {
    owner = "AprilNEA";
    repo = "OpenLogi";
    rev = "a92aa43bed3732be5f7fde7aed2fc12cc48ba001"; # v0.8.6
  };
  zen-browser = {
    owner = "0xc000022070";
    repo = "zen-browser-flake";
    rev = "1c3a1fcacf97eb3792e9292e3afc0edbfcfa01d4"; # HEAD -- upstream's
    # tags are named "twilight-<hash>" per Zen Browser build, not per
    # flake release, so they track a different thing than this pin does.
    # HEAD is the flake's own moving pin to the latest Zen build.
  };
}
