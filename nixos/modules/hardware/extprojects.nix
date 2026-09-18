{ ... }:

{
  systemd.tmpfiles.rules = [
    "d /mnt/nixdata/Projects 0755 elliancarlos users -"
    "L /home/elliancarlos/ExtProjects - - - - /mnt/nixdata/Projects"
  ];
}
