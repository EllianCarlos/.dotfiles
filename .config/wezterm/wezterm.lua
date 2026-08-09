local wezterm = require("wezterm")
local act = wezterm.action
local config = wezterm.config_builder()

-- --- Appearance -------------------------------------------------------------

local font_family = "FiraCode Nerd Font"

config.font = wezterm.font(font_family)
config.font_size = 12.5

config.font_rules = {
  {
    intensity = "Bold",
    italic = false,
    -- Single-table form: harfbuzz_features is a FontAttributes field, not a
    -- TextStyleAttributes one, so wezterm.font(name, {...}) is rejected.
    font = wezterm.font({
      family = font_family,
      weight = "Bold",
      harfbuzz_features = { "zero" },
    }),
  },
}

config.color_scheme = "Catppuccin Mocha"

config.window_background_opacity = 0.7
config.window_padding = { left = 4, right = 4, top = 4, bottom = 4 }
-- "RESIZE" still leaves a client-side title strip on Hyprland.
config.window_decorations = "NONE"

config.use_fancy_tab_bar = false
config.hide_tab_bar_if_only_one_tab = true
config.tab_bar_at_bottom = false
config.tab_max_width = 32

config.scrollback_lines = 10000
config.enable_wayland = true

wezterm.on("update-right-status", function(window, _)
  window:set_right_status(wezterm.format({
    { Foreground = { Color = "#cba6f7" } },
    { Text = "  " .. window:active_workspace() .. "  " },
  }))
end)

-- --- Session recovery (resurrect.wezterm) ------------------------------------

local ok_paths, nix_paths = pcall(require, "nix-paths")

local resurrect = nil
if ok_paths and nix_paths.resurrect then
  package.path = package.path .. ";" .. nix_paths.resurrect .. "/plugin/?.lua"

  -- Bypasses resurrect's plugin/init.lua on purpose: it network-fetches
  -- dev.wezterm just to locate itself, and points its state dir at
  -- <plugin>/state, which is read-only in the nix store.
  resurrect = {
    state_manager = require("resurrect.state_manager"),
    workspace_state = require("resurrect.workspace_state"),
    window_state = require("resurrect.window_state"),
    tab_state = require("resurrect.tab_state"),
    fuzzy_loader = require("resurrect.fuzzy_loader"),
  }

  resurrect.save_state = resurrect.state_manager.save_state
  package.loaded["resurrect"] = resurrect

  resurrect.state_manager.change_state_save_dir(
    wezterm.home_dir .. "/.local/state/wezterm/resurrect/"
  )

  resurrect.state_manager.periodic_save({
    interval_seconds = 300,
    save_workspaces = true,
  })

  wezterm.on("resurrect.state_manager.periodic_save.finished", function()
    resurrect.state_manager.write_current_state(wezterm.mux.get_active_workspace(), "workspace")
  end)

  wezterm.on("resurrect.error", function(err)
    wezterm.log_error("resurrect: " .. tostring(err))
  end)
end

wezterm.on("gui-startup", function(cmd)
  -- `wezterm start -- <prog>` fires this too, so an explicit command must win
  -- over session restore or the Hyprland/waybar launchers get swallowed.
  if cmd then
    wezterm.mux.spawn_window(cmd)
    return
  end

  local restored = false
  if resurrect then
    restored = resurrect.state_manager.resurrect_on_gui_startup()
  end
  if not restored then
    wezterm.mux.spawn_window({})
  end
end)

-- --- Keybindings -------------------------------------------------------------

config.leader = { key = "a", mods = "CTRL", timeout_milliseconds = 1000 }

config.keys = {
  { key = "a", mods = "LEADER|CTRL", action = act.SendKey({ key = "a", mods = "CTRL" }) },

  -- --- Carried over from kitty (kitty_mod = ctrl+shift) ---
  { key = "c", mods = "CTRL|SHIFT", action = act.CopyTo("Clipboard") },
  { key = "v", mods = "CTRL|SHIFT", action = act.PasteFrom("Clipboard") },
  { key = "Enter", mods = "CTRL|SHIFT", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
  { key = "w", mods = "CTRL|SHIFT", action = act.CloseCurrentPane({ confirm = true }) },
  { key = "]", mods = "CTRL|SHIFT", action = act.ActivatePaneDirection("Next") },
  { key = "[", mods = "CTRL|SHIFT", action = act.ActivatePaneDirection("Prev") },
  { key = "f", mods = "CTRL|SHIFT", action = act.RotatePanes("Clockwise") },
  { key = "b", mods = "CTRL|SHIFT", action = act.RotatePanes("CounterClockwise") },
  { key = "t", mods = "CTRL|SHIFT", action = act.SpawnTab("CurrentPaneDomain") },
  { key = "q", mods = "CTRL|SHIFT", action = act.CloseCurrentTab({ confirm = true }) },
  { key = "RightArrow", mods = "CTRL|SHIFT", action = act.ActivateTabRelative(1) },
  { key = "LeftArrow", mods = "CTRL|SHIFT", action = act.ActivateTabRelative(-1) },
  { key = "=", mods = "CTRL|SHIFT", action = act.IncreaseFontSize },
  { key = "-", mods = "CTRL|SHIFT", action = act.DecreaseFontSize },
  { key = "Backspace", mods = "CTRL|SHIFT", action = act.ResetFontSize },

  { key = "u", mods = "CTRL|SHIFT", action = act.CharSelect({ copy_on_select = true }) },
  { key = "p", mods = "CTRL|SHIFT", action = act.QuickSelect },
  {
    key = "o",
    mods = "CTRL|SHIFT",
    action = act.QuickSelectArgs({
      label = "open url",
      patterns = { "https?://\\S+" },
      action = wezterm.action_callback(function(window, pane)
        local url = window:get_selection_text_for_pane(pane)
        wezterm.open_with(url)
      end),
    }),
  },

  -- --- Multiplexer: panes ---
  { key = "%", mods = "LEADER|SHIFT", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
  { key = '"', mods = "LEADER|SHIFT", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
  { key = "h", mods = "LEADER", action = act.ActivatePaneDirection("Left") },
  { key = "j", mods = "LEADER", action = act.ActivatePaneDirection("Down") },
  { key = "k", mods = "LEADER", action = act.ActivatePaneDirection("Up") },
  { key = "l", mods = "LEADER", action = act.ActivatePaneDirection("Right") },
  { key = "H", mods = "LEADER|SHIFT", action = act.AdjustPaneSize({ "Left", 5 }) },
  { key = "J", mods = "LEADER|SHIFT", action = act.AdjustPaneSize({ "Down", 5 }) },
  { key = "K", mods = "LEADER|SHIFT", action = act.AdjustPaneSize({ "Up", 5 }) },
  { key = "L", mods = "LEADER|SHIFT", action = act.AdjustPaneSize({ "Right", 5 }) },
  { key = "x", mods = "LEADER", action = act.CloseCurrentPane({ confirm = true }) },
  { key = "z", mods = "LEADER", action = act.TogglePaneZoomState },
  { key = "Space", mods = "LEADER", action = act.PaneSelect },

  -- --- Multiplexer: tabs ---
  { key = "c", mods = "LEADER", action = act.SpawnTab("CurrentPaneDomain") },
  { key = "n", mods = "LEADER", action = act.ActivateTabRelative(1) },
  { key = "p", mods = "LEADER", action = act.ActivateTabRelative(-1) },
  {
    key = ",",
    mods = "LEADER",
    action = act.PromptInputLine({
      description = "Rename tab",
      action = wezterm.action_callback(function(window, _, line)
        if line then
          window:active_tab():set_title(line)
        end
      end),
    }),
  },

  -- --- Multiplexer: workspaces ---
  { key = "w", mods = "LEADER", action = act.ShowLauncherArgs({ flags = "FUZZY|WORKSPACES" }) },
  {
    key = "$",
    mods = "LEADER|SHIFT",
    action = act.PromptInputLine({
      description = "Rename workspace",
      action = wezterm.action_callback(function(_, _, line)
        if line then
          wezterm.mux.rename_workspace(wezterm.mux.get_active_workspace(), line)
        end
      end),
    }),
  },

  -- --- Copy mode ---
  { key = "[", mods = "LEADER", action = act.ActivateCopyMode },
}

for i = 1, 9 do
  table.insert(config.keys, {
    key = tostring(i),
    mods = "LEADER",
    action = act.ActivateTab(i - 1),
  })
end

if resurrect then
  table.insert(config.keys, {
    key = "s",
    mods = "LEADER",
    action = wezterm.action_callback(function()
      local state = resurrect.workspace_state.get_workspace_state()
      resurrect.state_manager.save_state(state)
      resurrect.state_manager.write_current_state(state.workspace, "workspace")
    end),
  })

  table.insert(config.keys, {
    key = "r",
    mods = "LEADER",
    action = wezterm.action_callback(function(win, pane)
      resurrect.fuzzy_loader.fuzzy_load(win, pane, function(id, label)
        local type = string.match(id, "^([^/]+)") -- workspace | window | tab
        id = string.match(id, "([^/]+)$")
        id = string.match(id, "(.+)%..+$")

        if type == "workspace" then
          local state = resurrect.state_manager.load_state(id, "workspace")
          resurrect.workspace_state.restore_workspace(state, {
            window = win:mux_window(),
            relative = true,
            restore_text = true,
            on_pane_restore = resurrect.tab_state.default_on_pane_restore,
          })
          resurrect.state_manager.write_current_state(id, "workspace")
        elseif type == "window" then
          local state = resurrect.state_manager.load_state(id, "window")
          resurrect.window_state.restore_window(win:mux_window(), state, {
            relative = true,
            restore_text = true,
            on_pane_restore = resurrect.tab_state.default_on_pane_restore,
          })
        elseif type == "tab" then
          local state = resurrect.state_manager.load_state(id, "tab")
          resurrect.tab_state.restore_tab(pane:tab(), state, {
            relative = true,
            restore_text = true,
            on_pane_restore = resurrect.tab_state.default_on_pane_restore,
          })
        end
        wezterm.log_info("resurrect: restored " .. tostring(label))
      end)
    end),
  })

  table.insert(config.keys, {
    key = "d",
    mods = "LEADER",
    action = wezterm.action_callback(function(win, pane)
      resurrect.fuzzy_loader.fuzzy_load(win, pane, function(id)
        resurrect.state_manager.delete_state(id)
      end, {
        title = "Delete saved session",
        description = "Select session to delete",
        fuzzy_description = "Search session to delete: ",
        is_fuzzy = true,
      })
    end),
  })
end

return config
