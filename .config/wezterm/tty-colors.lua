-- TTY design system — wezterm palette.
-- In wezterm.lua:
--   config.color_schemes = { TTY = require("tty-colors") }
--   config.color_scheme = "TTY"
--   config.font = wezterm.font("JetBrains Mono")   -- or "JetBrainsMono Nerd Font" for p10k glyphs
--   config.window_background_opacity = 1.0          -- TTY never uses transparency on surfaces
--   config.default_cursor_style = "BlinkingBlock"
--   config.cursor_blink_rate = 530
--   config.cursor_blink_ease_in = "Constant"        -- stepped blink, no fade
--   config.cursor_blink_ease_out = "Constant"
-- and set the right-status foreground to "#8C8C84".
-- Note: TTY has no blue. ANSI blue maps to cyan so ls/git output stays legible.

return {
  foreground = "#E8E8E3",
  background = "#0A0A09",
  cursor_bg = "#FFD400",
  cursor_fg = "#000000",
  cursor_border = "#FFD400",
  selection_bg = "#FFD400",
  selection_fg = "#000000",
  scrollbar_thumb = "#33332F",
  split = "#33332F",
  compose_cursor = "#FF6AC1",

  ansi = {
    "#1A1A18", -- black
    "#FF5C57", -- red
    "#5AF78E", -- green
    "#FFD400", -- yellow
    "#5EDFFF", -- blue  → cyan
    "#FF6AC1", -- magenta
    "#5EDFFF", -- cyan
    "#B4B4AC", -- white
  },
  brights = {
    "#5E5E58",
    "#FF5C57",
    "#5AF78E",
    "#FFE566",
    "#5EDFFF",
    "#FF6AC1",
    "#5EDFFF",
    "#E8E8E3",
  },

  tab_bar = {
    background = "#0A0A09",
    active_tab = { bg_color = "#FFD400", fg_color = "#000000" },
    inactive_tab = { bg_color = "#0A0A09", fg_color = "#8C8C84" },
    inactive_tab_hover = { bg_color = "#242422", fg_color = "#E8E8E3" },
    new_tab = { bg_color = "#0A0A09", fg_color = "#5E5E58" },
    new_tab_hover = { bg_color = "#242422", fg_color = "#E8E8E3" },
  },
}
