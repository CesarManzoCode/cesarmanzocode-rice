--[[
  binds.lua — all keybinds, generated from USER preferences (layer C).

  Nothing here is hardcoded for "the author": app launch binds and the
  handful of action binds below come entirely from
  ~/.config/cesarmanzocode-rice/user.lua, written by install.sh. Structural
  navigation (workspaces 1-10, focus arrows, mouse move/resize) has sane,
  always-on defaults but can be overridden too (advanced mode) via the
  same user.lua table.
]]

local hl = require("hl")

assert(type(USER) == "table", "binds.lua requires a USER table (see user.lua.example)")

hl.comment("binds.lua: generated from user.lua")

local apps = USER.apps or {}
local binds = USER.binds or {}

local function bindspec(b, fallback_mods, fallback_key)
  if type(b) == "table" and b.key and b.key ~= "" then
    return b.mods or "", b.key
  end
  return fallback_mods, fallback_key
end

local SPECIAL_NAME = "magic"

-- ---- App / action binds (fully user-configurable) ----------------------

if apps.terminal and apps.terminal ~= "none" then
  local mods, key = bindspec(binds.terminal, "SUPER", "T")
  hl.bind(mods, key, "exec", apps.terminal)
end

if apps.browser and apps.browser ~= "none" then
  local mods, key = bindspec(binds.browser, "SUPER", "B")
  hl.bind(mods, key, "exec", apps.browser)
end

if apps.filemanager and apps.filemanager ~= "none" then
  local mods, key = bindspec(binds.filemanager, "SUPER", "E")
  hl.bind(mods, key, "exec", apps.filemanager)
end

if apps.launcher and apps.launcher ~= "none" then
  local mods, key = bindspec(binds.launcher, "SUPER", "R")
  hl.bind(mods, key, "exec", apps.launcher)
end

do
  local mods, key = bindspec(binds.close_window, "SUPER", "X")
  hl.bind(mods, key, "killactive")
end

do
  local mods, key = bindspec(binds.toggle_floating, "SUPER", "V")
  hl.bind(mods, key, "togglefloating")
end

do
  local mods, key = bindspec(binds.special_toggle, "SUPER", "S")
  hl.bind(mods, key, "togglespecialworkspace", SPECIAL_NAME)
end

do
  local mods, key = bindspec(binds.special_move, "SUPER SHIFT", "S")
  hl.bind(mods, key, "movetoworkspacesilent", "special:" .. SPECIAL_NAME)
end

-- fullscreen toggle is common enough to keep as a fixed, non-conflicting default
hl.bind("SUPER", "F", "fullscreen")

-- ---- Structural navigation (advanced-overridable, always has a default) -

local function dir_bind(name, fallback_mods, fallback_key, dispatcher, arg)
  local mods, key = bindspec(binds[name], fallback_mods, fallback_key)
  hl.bind(mods, key, dispatcher, arg)
end

dir_bind("focus_left", "SUPER", "left", "movefocus", "l")
dir_bind("focus_right", "SUPER", "right", "movefocus", "r")
dir_bind("focus_up", "SUPER", "up", "movefocus", "u")
dir_bind("focus_down", "SUPER", "down", "movefocus", "d")

local ws_mods = (binds.workspace_prefix) or "SUPER"
local move_ws_mods = (binds.move_workspace_prefix) or "SUPER SHIFT"

-- Hyprland maps the "0" key to workspace 10 by convention.
local ws_keys = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0" }
for i, key in ipairs(ws_keys) do
  hl.bind(ws_mods, key, "workspace", tostring(i))
  hl.bind(move_ws_mods, key, "movetoworkspace", tostring(i))
end

-- Mouse move/resize (not remapped in this version; low collision risk and
-- extremely standard across compositors).
hl.bind("SUPER", "mouse:272", "movewindow", nil, "bindm")
hl.bind("SUPER", "mouse:273", "resizewindow", nil, "bindm")

-- ---- Media / volume keys -------------------------------------------------

hl.bind("", "XF86AudioRaiseVolume", "exec", "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+", "bindel")
hl.bind("", "XF86AudioLowerVolume", "exec", "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-", "bindel")
hl.bind("", "XF86AudioMute", "exec", "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle", "bindel")
hl.bind("", "XF86AudioMicMute", "exec", "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle", "bindel")
hl.bind("", "XF86AudioPlay", "exec", "playerctl play-pause", "bindel")
hl.bind("", "XF86AudioPause", "exec", "playerctl play-pause", "bindel")
hl.bind("", "XF86AudioNext", "exec", "playerctl next", "bindel")
hl.bind("", "XF86AudioPrev", "exec", "playerctl previous", "bindel")

-- ---- Screenshots (grim + slurp; not user-customizable in v1) -----------

local screenshot_dir = "$HOME/Pictures/Screenshots"
hl.bind("", "Print", "exec", "mkdir -p " .. screenshot_dir .. " && grim " .. screenshot_dir .. "/$(date +%Y-%m-%d_%H-%M-%S).png")
hl.bind("SUPER", "Print", "exec", "mkdir -p " .. screenshot_dir .. " && grim -g \"$(slurp)\" " .. screenshot_dir .. "/$(date +%Y-%m-%d_%H-%M-%S).png")

-- ---- Clipboard picker (only wired up if cliphist is enabled) ------------

if USER.components and USER.components.cliphist then
  local mods, key = bindspec(binds.clipboard, "SUPER", "period")
  hl.bind(mods, key, "exec", "cliphist list | rofi -dmenu | cliphist decode | wl-copy")
end

hl.blank()
