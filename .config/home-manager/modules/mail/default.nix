# neomutt + mbsync, and the gpg agent that unlocks the account password.
# Account details live in accounts.nix, which is gitignored -- copy
# accounts.nix.example to accounts.nix on a new machine.
{ pkgs, ... }:
{
  programs.neomutt = {
    enable = true;
    vimKeys = true;
    sort = "threads";
    extraConfig = ''
      set timeout = 3;
      set mail_check = 60;
      set collapse_all = yes;
      set use_threads = yes;
      set sort = "reverse-last-date-received";
      set delete = ask-yes;
    '';
  };

  accounts.email.accounts = import ./accounts.nix { inherit pkgs; };

  programs.mbsync.enable = true;

  programs.gpg.enable = true;

  services.gpg-agent = {
    enable = true;
    pinentry.package = pkgs.pinentry-curses;
  };
}
