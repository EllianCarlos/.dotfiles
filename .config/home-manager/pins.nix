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
    rev = "de243d9cb267e96502b90630012c12e4bdeda090"; # upstream HEAD -- repo
    # cuts no tags.
  };
  claude-code-nix = {
    owner = "sadjow";
    repo = "claude-code-nix";
    rev = "b17e42820330bd34ab890632c2f6f80daf4e517f"; # v2.1.289, also upstream HEAD
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
    rev = "1421a6439836357c6dd685a99760c259b9935fdd"; # opencode 1.18.34
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
  loop-engineering = {
    owner = "cobusgreyling";
    repo = "loop-engineering";
    rev = "9588274f3facf6013b98c38f336212be2bb75d6d"; # upstream HEAD -- this
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
    rev = "24fe0ef7737efae15c87225755e9f6f5965e4888"; # v1.3.1, also upstream HEAD
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
    # (1181fd4e8cc581931a5ee672697a646721e92c78 as of 2026-10-05) is further
    # commits past this tag with no new release cut yet; see
    # project-pin-bump-prefer-tagged-release.
  };
  academic-research-skills = {
    owner = "Imbad0202";
    repo = "academic-research-skills";
    rev = "6ab4b03bf70a118a1b3ee7f3263ed9f19031061b"; # v3.23.0, also upstream HEAD
  };
  openlogi = {
    owner = "AprilNEA";
    repo = "OpenLogi";
    rev = "7a9d092a7dda0cb3b7ec18ada4424d681fca65ca"; # v0.8.11 -- upstream HEAD
    # (4863a45e256d80404b95232b513793cbccb5d6d6 as of 2026-10-05) is further
    # commits past this tag with no new release cut yet; see
    # project-pin-bump-prefer-tagged-release.
  };
  zen-browser = {
    owner = "0xc000022070";
    repo = "zen-browser-flake";
    rev = "e56900732d1fa6f360db502451a457ffe3ca1e6e"; # HEAD -- upstream's
    # tags are named "twilight-<hash>" per Zen Browser build, not per
    # flake release, so they track a different thing than this pin does.
    # HEAD is the flake's own moving pin to the latest Zen build.
  };
}
