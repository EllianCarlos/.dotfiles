# Japanese input (fcitx5 + Mozc).
#
# Toggle with SUPER+I (hyprland.conf, via `fcitx5-remote -t`) or by
# clicking the language module in waybar. fcitx5's own TriggerKeys are
# cleared below so it never grabs a hotkey on its own -- this is what
# keeps Ctrl+Space free for nvim's completion menu.
{ pkgs, ... }:
{
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      # Registers fcitx5 as a Wayland input-method (input-method-v2), so
      # Wayland-native apps (wezterm, GTK4/Qt6 apps) get IME support without
      # relying on the GTK_IM_MODULE/QT_IM_MODULE env vars below.
      waylandFrontend = true;
      addons = with pkgs; [
        fcitx5-mozc
        fcitx5-gtk
      ];
      settings = {
        globalOptions."Hotkey" = {
          TriggerKeys = "";
          AltTriggerKeys = "";
          EnumerateWithTriggerKeys = "False";
        };
        inputMethod = {
          "Groups/0" = {
            Name = "Default";
            "Default Layout" = "us";
            DefaultIM = "keyboard-us";
          };
          # Blank Layout inherits kb_layout/kb_variant from hyprland.conf
          # (us intl), so normal typing is unaffected when Mozc is off.
          "Groups/0/Items/0" = {
            Name = "keyboard-us";
            Layout = "";
          };
          "Groups/0/Items/1" = {
            Name = "mozc";
            Layout = "";
          };
          GroupOrder."0" = "Default";
        };
      };
    };
  };

  # --- Compose-key accents (replaces the old GTK "cedilla" module) ---
  # "%L" pulls in the system's default Compose table for the current
  # locale, which already defines ç, é, ã, õ, ü, etc. The Menu key is set
  # as the Compose key in hyprland.conf (kb_options = compose:menu).
  home.file.".XCompose".text = ''
    include "%L"
  '';

  # --- Session variables ------------------------------------------------------
  # GTK_IM_MODULE / QT_IM_MODULE / XMODIFIERS / SDL_IM_MODULE are no longer
  # set here: i18n.inputMethod.fcitx5.sessionVariables (above) sets them to
  # "fcitx" itself. Cedilla/accent input moved from the old GTK-only
  # "cedilla" module to a Compose key (see kb_options in hyprland.conf and
  # ~/.XCompose above).
}
