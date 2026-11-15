-- Hyprland 0.57+ only reads a Lua config (hyprland.lua); the old hyprlang
-- hyprland.conf is no longer loaded. This is a 1:1 port of hyprland.conf with
-- tty-theme.conf (the "TTY design system" overrides) already merged in.
-- See https://wiki.hyprland.org/Configuring/ for the full option list.

-- ---------------------------------------------------------------------------
-- Palette (tty-colors.conf)
-- ---------------------------------------------------------------------------
local c = {
  root      = "rgb(0A0A09)",
  panel     = "rgb(121211)",
  raised    = "rgb(1A1A18)",
  border    = "rgb(33332F)",
  text      = "rgb(E8E8E3)",
  void      = "rgb(000000)",
  yellow    = "rgb(FFD400)",
}

local mainMod = "SUPER"

-- Wallpaper command (desktop). Laptop variant:
--   hyprctl hyprpaper wallpaper ",~/.config/wallpapers/1.png"
local w1 = 'hyprctl hyprpaper wallpaper "DP-1,~/.config/wallpapers/1.png" && '
        .. 'hyprctl hyprpaper wallpaper "HDMI-A-1,~/.config/wallpapers/1.png"'

-- ---------------------------------------------------------------------------
-- Monitors (desktop). Laptop: hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
-- ---------------------------------------------------------------------------
hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@144", position = "0x0",    scale = 1 })
hl.monitor({ output = "DP-1",     mode = "1920x1080@144", position = "1920x0", scale = 1 })

-- ---------------------------------------------------------------------------
-- Environment
-- ---------------------------------------------------------------------------
-- Fcitx5 (Japanese IME / Mozc). Kept in sync with
-- i18n.inputMethod.fcitx5.sessionVariables in home.nix.
hl.env("GTK_IM_MODULE", "fcitx")
hl.env("QT_IM_MODULE", "fcitx")
hl.env("XMODIFIERS", "@im=fcitx")
hl.env("SDL_IM_MODULE", "fcitx")

-- ---------------------------------------------------------------------------
-- Autostart
-- ---------------------------------------------------------------------------
hl.on("hyprland.start", function()
  hl.exec_cmd("waybar")
  hl.exec_cmd("hyprshell run")
  hl.exec_cmd("wezterm")
  hl.exec_cmd("firefox")
  hl.exec_cmd("hypridle")
  hl.exec_cmd("hyprpaper")
  hl.exec_cmd("mako")
  hl.exec_cmd("fcitx5")
  hl.exec_cmd(w1)
  hl.exec_cmd("hyprctl setcursor Bibata-Modern-Classic 24")
  hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=Hyprland")
end)

-- ---------------------------------------------------------------------------
-- Look and feel
-- ---------------------------------------------------------------------------
hl.config({
  input = {
    kb_layout = "us",
    kb_variant = "intl",
    kb_model = "",
    -- compose:menu assigns the Menu key as the Compose key, so accented
    -- letters (Compose , c -> ç, Compose ' e -> é) work through the system's
    -- default XCompose table (~/.XCompose, see home.nix).
    kb_options = "compose:menu",
    kb_rules = "",
    follow_mouse = 1,
    touchpad = { natural_scroll = false },
    sensitivity = -0.3,
    accel_profile = "flat",
    force_no_accel = true,
  },

  general = {
    gaps_in = 2,
    gaps_out = 8,
    border_size = 1, -- 1px rules; yellow = focus, nothing else
    col = {
      active_border = c.yellow,
      inactive_border = c.border,
      nogroup_border = c.border,
      nogroup_border_active = c.yellow,
    },
    layout = "dwindle",
  },

  decoration = {
    rounding = 0, -- square corners
    active_opacity = 1.0,
    inactive_opacity = 1.0,
    blur = { enabled = false },
    shadow = { -- hard offset block, no soft shadow
      enabled = true,
      range = 0,
      render_power = 1,
      offset = "3 3",
      sharp = true,
      color = c.void,
      color_inactive = c.void,
    },
  },

  group = {
    col = { border_active = c.yellow, border_inactive = c.border },
    groupbar = {
      font_family = "JetBrains Mono",
      font_size = 11,
      height = 18,
      gradients = false,
      text_color = c.text,
      col = { active = c.yellow, inactive = c.raised },
    },
  },

  animations = { enabled = true },

  xwayland = { force_zero_scaling = true },
  dwindle = { preserve_split = true },
  master = { new_status = "master" },

  misc = {
    background_color = c.root, -- fallback behind the wallpaper
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
    font_family = "JetBrains Mono",
  },

  binds = {
    -- Moving a window or focus over a monitor edge goes to the next monitor.
    window_direction_monitor_fallback = true,
  },
})

-- Stepped, not eased: linear curves, short durations, slide styles only.
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.animation({ leaf = "windows",          enabled = true,  speed = 2, bezier = "linear", style = "slide" })
hl.animation({ leaf = "windowsOut",       enabled = true,  speed = 1, bezier = "linear", style = "slide" })
hl.animation({ leaf = "border",           enabled = true,  speed = 1, bezier = "linear" })
hl.animation({ leaf = "borderangle",      enabled = false })
hl.animation({ leaf = "fade",             enabled = true,  speed = 1, bezier = "linear" })
hl.animation({ leaf = "workspaces",       enabled = true,  speed = 3, bezier = "linear", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true,  speed = 2, bezier = "linear", style = "slidevert" })
hl.animation({ leaf = "layers",           enabled = true,  speed = 1, bezier = "linear", style = "slide" })

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- ---------------------------------------------------------------------------
-- Keybinds
-- ---------------------------------------------------------------------------
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd("wezterm"))
-- text-only launcher (TTY theme: no app icons)
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd('wofi --show drun --insensitive --prompt "run"'))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd("firefox"))
hl.bind(mainMod .. " + S", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd("wezterm start -- nvim"))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo()) -- dwindle
hl.bind(mainMod .. " + V", hl.dsp.layout("togglesplit")) -- dwindle
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("grim - | wl-copy"))
hl.bind(mainMod .. " + SHIFT + B", hl.dsp.exec_cmd('grim -g "$(slurp -d)" - | wl-copy'))
hl.bind("Print", hl.dsp.exec_cmd("grim - | wl-copy"))

-- Toggle Japanese IME (fcitx5 / Mozc). Unmapped elsewhere (hyprland, nvim,
-- wezterm) -- Ctrl+Space collides with nvim's completion menu.
hl.bind(mainMod .. " + I", hl.dsp.exec_cmd("fcitx5-remote -t"))

-- Focus
hl.bind(mainMod .. " + H", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + L", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + K", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + J", hl.dsp.focus({ direction = "down" }))

-- Workspaces with mouse buttons / scroll
hl.bind(mainMod .. " + mouse:276", hl.dsp.focus({ workspace = "e-1" })) -- Back button
hl.bind(mainMod .. " + mouse:275", hl.dsp.focus({ workspace = "e+1" })) -- Forward button
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Resize submap: SUPER + O enters, escape leaves.
hl.bind(mainMod .. " + O", hl.dsp.submap("resize"))
hl.define_submap("resize", "escape", function()
  hl.bind("l", hl.dsp.window.resize({ x = 10, y = 0, relative = true }), { repeating = true })
  hl.bind("h", hl.dsp.window.resize({ x = -10, y = 0, relative = true }), { repeating = true })
  hl.bind("k", hl.dsp.window.resize({ x = 0, y = -10, relative = true }), { repeating = true })
  hl.bind("j", hl.dsp.window.resize({ x = 0, y = 10, relative = true }), { repeating = true })
end)

hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + C", hl.dsp.window.center())

-- Volume
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("pamixer -i 5"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("pamixer -d 5"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("pamixer -t"), { locked = true })

-- Brightness
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"), { locked = true, repeating = true })

-- Media
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

-- Monitors: focus / move window
hl.bind(mainMod .. " + left", hl.dsp.focus({ monitor = "l" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ monitor = "r" }))
hl.bind(mainMod .. " + SHIFT + left", hl.dsp.window.move({ monitor = "l" }))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({ monitor = "r" }))
hl.bind(mainMod .. " + CTRL + H", hl.dsp.focus({ monitor = "l" }))
hl.bind(mainMod .. " + CTRL + L", hl.dsp.focus({ monitor = "r" }))
hl.bind(mainMod .. " + CTRL + K", hl.dsp.focus({ monitor = "u" }))
hl.bind(mainMod .. " + CTRL + J", hl.dsp.focus({ monitor = "d" }))
hl.bind(mainMod .. " + SHIFT + CTRL + H", hl.dsp.window.move({ monitor = "l" }))
hl.bind(mainMod .. " + SHIFT + CTRL + L", hl.dsp.window.move({ monitor = "r" }))
hl.bind(mainMod .. " + SHIFT + CTRL + K", hl.dsp.window.move({ monitor = "u" }))
hl.bind(mainMod .. " + SHIFT + CTRL + J", hl.dsp.window.move({ monitor = "d" }))

-- Move windows within a monitor
hl.bind(mainMod .. " + SHIFT + H", hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.window.move({ direction = "right" }))
hl.bind(mainMod .. " + SHIFT + K", hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + J", hl.dsp.window.move({ direction = "down" }))

-- Workspaces 1-10 (workspaces are not bound to monitors)
for i = 1, 10 do
  local key = i % 10
  hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
  hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Scratchpad
hl.bind(mainMod .. " + T", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + T", hl.dsp.window.move({ workspace = "special:magic" }))

-- Minimize
hl.bind(mainMod .. " + M", hl.dsp.window.move({ workspace = "special:minimized", follow = false }))
hl.bind(mainMod .. " + SHIFT + U", hl.dsp.workspace.toggle_special("minimized"))

-- App interactions
hl.bind(mainMod .. " + CTRL + L", hl.dsp.exec_cmd("hyprlock"))
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd(w1))
hl.bind(mainMod .. " + X", hl.dsp.exec_cmd("~/.config/hypr/scripts/powermenu.sh"))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("pkill -SIGUSR1 waybar")) -- toggle waybar

hl.bind(mainMod .. " + SHIFT + M", hl.dsp.exit())

-- Move/resize windows with mainMod + LMB/RMB
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
