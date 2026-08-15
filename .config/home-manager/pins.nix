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
    rev = "4c03cc7e3088420b8b84d8d0937036abe13bf7a7";
  };
  claude-code-nix = {
    owner = "sadjow";
    repo = "claude-code-nix";
    rev = "0d3cd1d6260b6f0ed232224c274c565407446fa1";
  };
  agent-skills-nix = {
    owner = "Kyure-A";
    repo = "agent-skills-nix";
    rev = "1594ba479be81a7cb6dd19faabefcb1ed5b3f964";
  };
  loop-engineering = {
    owner = "cobusgreyling";
    repo = "loop-engineering";
    rev = "16c52e4b1ffe9f59f61117a660a6f6272b5e9c8e";
  };
  superpowers = {
    owner = "obra";
    repo = "superpowers";
    rev = "b36e0829c6d0140e93cfef2ca599b1b07d4a7797"; # v6.3.0
  };
  mattpocock-skills = {
    owner = "mattpocock";
    repo = "skills";
    rev = "8b78b531ab965735c5dc74f6f7a219e1e37326df";
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
  watermarks-remover = {
    owner = "guillaumemeyer";
    repo = "watermarks-remover";
    rev = "a3c5859a61e37e0e8d401f3b78e424185b849fde"; # v0.4.0
  };
  # Closed-source binary release (see antigravity-cli.nix), not a git repo --
  # no owner/repo/rev for check-nix-pins to git-ls-remote against, so this
  # is frozen. To bump: fetch
  # https://antigravity-cli-auto-updater-974169037036.us-central1.run.app/manifests/linux_amd64.json
  # (this is what upstream's install.sh itself queries) and copy its
  # version/url/sha512 here together.
  antigravity-cli = {
    version = "1.1.13";
    url = "https://storage.googleapis.com/antigravity-public/antigravity-cli/1.1.13-6057583128215552/linux-x64/cli_linux_x64.tar.gz";
    sha512 = "89c6881b6c1999cb8236e7181c2192ae8f372b0413396c0f7bcff83d27ac9c0cc1202795cc0d629ec1ecbf4937d1c294cf4f5e4f9f8e05b1e972e27198313442";
    frozen = true;
  };
}
