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
      set sort_aux = "date-received"
      bind index zc collapse-thread
      bind index zC collapse-all
      set delete = ask-yes;
      set allow_ansi = yes
      set display_filter = "${pkgs.delta}/bin/delta --color-only --paging=never --true-color=never --syntax-theme=none --minus-style 'red' --plus-style 'green' --minus-emph-style 'bold red' --plus-emph-style 'bold green' --zero-style normal"
      color body brightwhite default "^(diff|---|\\+\\+\\+|@@).*"
      color body green default "^\\+.*"
      color body red default "^-.*"
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
