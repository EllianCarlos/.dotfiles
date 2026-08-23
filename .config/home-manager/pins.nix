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
    rev = "c157da8e48b9b0756c436fd81abfaa337785198e";
  };
  claude-code-nix = {
    owner = "sadjow";
    repo = "claude-code-nix";
    rev = "fd727a3f341b079ba5387b770c5caef86bdae3e6";
  };
  agent-skills-nix = {
    owner = "Kyure-A";
    repo = "agent-skills-nix";
    rev = "1594ba479be81a7cb6dd19faabefcb1ed5b3f964";
  };
  loop-engineering = {
    owner = "cobusgreyling";
    repo = "loop-engineering";
    rev = "e4247dfa6e31598efb53a86995ce84171b5d5421";
  };
  superpowers = {
    owner = "obra";
    repo = "superpowers";
    rev = "b36e0829c6d0140e93cfef2ca599b1b07d4a7797"; # v6.3.0
  };
  mattpocock-skills = {
    owner = "mattpocock";
    repo = "skills";
    rev = "068b6e0c62393147daf03530149cdce209c93da8";
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
    # (c2ac8eeef3ff1a17aaab0cdb86889c7ad21675a7) is 3 commits past this tag
    # with no new release cut yet; see project-pin-bump-prefer-tagged-release.
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
