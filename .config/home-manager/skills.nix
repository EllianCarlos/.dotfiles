{ pkgs, ... }:
let
  pins = import ./pins.nix;
  mattpocockSrc = builtins.fetchTarball "https://github.com/${pins.mattpocock-skills.owner}/${pins.mattpocock-skills.repo}/archive/${pins.mattpocock-skills.rev}.tar.gz";
  watermarks-remover = builtins.fetchTarball "https://github.com/${pins.watermarks-remover.owner}/${pins.watermarks-remover.repo}/archive/${pins.watermarks-remover.rev}.tar.gz";
in
{
  # Claude Code's skills-dir loader only looks for SKILL.md directly inside
  # ~/.claude/skills/<name>/, or one level inside <name>/*/  -- it does NOT
  # recurse further. idPrefix (grouping skills under a source-name directory)
  # combined with a source that already nests skills under its own category
  # folders (mattpocock's skills/<category>/<skill>/SKILL.md) produces a
  # third nesting level that the loader never reaches, so those skills never
  # show up. Fix: no idPrefix anywhere, and each mattpocock category pointed
  # at directly via `subdir` so every skill lands as its own flat top-level
  # ~/.claude/skills/<skill-name>/SKILL.md -- structurally identical to how
  # the working `mnemon` skill (home.nix's home.file entry) is laid out.
  programs.agent-skills = {
    enable = true;

    sources = {
      loop-engineering = {
        path = builtins.fetchTarball "https://github.com/${pins.loop-engineering.owner}/${pins.loop-engineering.repo}/archive/${pins.loop-engineering.rev}.tar.gz";
        subdir = "skills";
      };
      superpowers = {
        path = builtins.fetchTarball "https://github.com/${pins.superpowers.owner}/${pins.superpowers.repo}/archive/${pins.superpowers.rev}.tar.gz";
        subdir = "skills";
      };
      # Only stable categories -- "deprecated" and "in-progress" are simply
      # never pointed at, rather than filtered out after the fact.
      mattpocock-engineering = {
        path = mattpocockSrc;
        subdir = "skills/engineering";
      };
      mattpocock-personal = {
        path = mattpocockSrc;
        subdir = "skills/personal";
      };
      mattpocock-productivity = {
        path = mattpocockSrc;
        subdir = "skills/productivity";
      };
      mattpocock-misc = {
        path = mattpocockSrc;
        subdir = "skills/misc";
      };
      remove-ai-marks = {
        path = watermarks-remover;
        subdir = "skills/remove-ai-marks";
      };
    };

    skills.enableAll = true;

    targets.claude.enable = true;

    # Default is only ["/.system"] -- setting this option replaces rather
    # than merges the module's default, so both must be listed explicitly.
    # "/mnemon" and "/nixapply" protect the hand-managed skills (home.nix's
    # home.file entries) from the rsync --delete this module runs on every
    # activation.
    excludePatterns = [ "/.system" "/mnemon" "/nixapply" ];
  };
}
