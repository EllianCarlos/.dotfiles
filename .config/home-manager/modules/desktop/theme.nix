# Cursor, GTK theme (adw-gtk3-dark + TTY CSS) and icons.
{ pkgs, ... }:
{
  home.pointerCursor = {
    gtk.enable = true;
    # x11.enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Classic";
    size = 24;
  };

  gtk = {
    enable = true;
    theme = {
      package = pkgs.adw-gtk3;
      name = "adw-gtk3-dark";
    };
    # TTY palette overrides (square corners, yellow accent) on top of adw-gtk3-dark.
    gtk3.extraCss = builtins.readFile ../../files/gtk/tty.css;
    gtk4.extraCss = builtins.readFile ../../files/gtk/tty.css;
    gtk4.theme = null; # libadwaita apps take the palette from extraCss
    cursorTheme = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Classic";
    };
    iconTheme = {
      package = pkgs.papirus-icon-theme;
      name = "Papirus-Dark";
    };
  };
}
