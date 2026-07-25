{ pkgs, ... }:
{
  programs.agent-skills = {
    enable = true;

    sources = {
      loop-engineering = {
        path = builtins.fetchTarball "https://github.com/cobusgreyling/loop-engineering/archive/refs/heads/main.tar.gz";
        subdir = "skills";
        idPrefix = "loop";
      };
      superpowers = {
        path = builtins.fetchTarball "https://github.com/obra/superpowers/archive/refs/heads/main.tar.gz";
        subdir = "skills";
        idPrefix = "superpowers";
      };
      mattpocock = {
        path = builtins.fetchTarball "https://github.com/mattpocock/skills/archive/refs/heads/main.tar.gz";
        subdir = "skills";
        idPrefix = "mattpocock";
        # Only stable categories -- skip "deprecated" and "in-progress".
        filter.nameRegex = "(engineering|personal|productivity|misc)/.*";
      };
    };

    skills.enableAll = true;

    targets.claude.enable = true;

    # Default is only ["/.system"] -- setting this option replaces rather
    # than merges the module's default, so both must be listed explicitly.
    # "/mnemon" protects the hand-managed mnemon skill (home.nix's home.file
    # entry) from the rsync --delete this module runs on every activation.
    excludePatterns = [ "/.system" "/mnemon" ];
  };
}
