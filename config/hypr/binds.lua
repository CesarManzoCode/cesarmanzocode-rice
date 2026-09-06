--[[
  binds.lua — all keybinds, generated from USER preferences (layer C).

  Nothing here is hardcoded for "the author": app launch binds and the
  handful of action binds below come entirely from
  ~/.config/cesarmanzocode-rice/user.lua, written by install.sh. Structural
  navigation (workspaces 1-10, focus arrows, mouse move/resize) has sane,
  always-on defaults but can be overridden too (advanced mode) via the
  same user.lua table.

  Uses the native hl.bind()/hl.dsp.* dispatcher API (Hyprland >= 0.55);
  no dispatch strings.
]]

assert(type(USER) == "table", "binds.lua requires a USER table (see user.lua.example)")

local apps = USER.apps or {}
local binds = USER.binds or {}

local function bindspec(b, fallback_mods, fallback_key)
  if type(b) == "table" and b.key and b.key ~= "" then
    return b.mods or "", b.key
  end
  return fallback_mods, fallback_key
end

-- hl.bind() takes keys as one "MODS + KEY" string, with each modifier
-- separated from the next (and from the key) by its own " + " — Hyprland
-- 0.56's parser rejects a combined "SUPER SHIFT" token, requiring
-- "SUPER + SHIFT" instead. mods here may be stored (per user.lua schema)
-- as whitespace- and/or "+"-separated, e.g. "SUPER SHIFT" or "SUPER+SHIFT",
-- so tokenize on both and rejoin with " + ".
local function keystr(mods, key)
  if mods == nil or mods == "" then return key end
  local tokens = {}
  for token in mods:gmatch("[^%s+]+") do
    tokens[#tokens + 1] = token
  end
  if #tokens == 0 then return key end
  return table.concat(tokens, " + ") .. " + " .. key
end

local SPECIAL_NAME = "magic"

-- ---- App / action binds (fully user-configurable) ----------------------

if apps.terminal and apps.terminal ~= "none" then
  local mods, key = bindspec(binds.terminal, "SUPER", "T")
  hl.bind(keystr(mods, key), hl.dsp.exec_cmd(apps.terminal))
end

if apps.browser and apps.browser ~= "none" then
  local mods, key = bindspec(binds.browser, "SUPER", "B")
  hl.bind(keystr(mods, key), hl.dsp.exec_cmd(apps.browser))
end

if apps.filemanager and apps.filemanager ~= "none" then
  local mods, key = bindspec(binds.filemanager, "SUPER", "E")
  hl.bind(keystr(mods, key), hl.dsp.exec_cmd(apps.filemanager))
end

if apps.launcher and apps.launcher ~= "none" then
  local mods, key = bindspec(binds.launcher, "SUPER", "R")
  hl.bind(keystr(mods, key), hl.dsp.exec_cmd(apps.launcher))
end

do
  local mods, key = bindspec(binds.close_window, "SUPER", "X")
  hl.bind(keystr(mods, key), hl.dsp.window.close())
end

do
  local mods, key = bindspec(binds.toggle_floating, "SUPER", "V")
  hl.bind(keystr(mods, key), hl.dsp.window.float({ action = "toggle" }))
end

do
  local mods, key = bindspec(binds.special_toggle, "SUPER", "S")
  hl.bind(keystr(mods, key), hl.dsp.workspace.toggle_special(SPECIAL_NAME))
end

do
  local mods, key = bindspec(binds.special_move, "SUPER SHIFT", "S")
  -- follow = false keeps focus on the current workspace, matching the old
  -- movetoworkspacesilent behavior.
  hl.bind(keystr(mods, key), hl.dsp.window.move({ workspace = "special:" .. SPECIAL_NAME, follow = false }))
end

-- fullscreen toggle is common enough to keep as a fixed, non-conflicting default
hl.bind("SUPER + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))

-- ---- Structural navigation (advanced-overridable, always has a default) -

local function dir_bind(name, fallback_mods, fallback_key, direction)
  local mods, key = bindspec(binds[name], fallback_mods, fallback_key)
  hl.bind(keystr(mods, key), hl.dsp.focus({ direction = direction }))
end

dir_bind("focus_left", "SUPER", "left", "left")
dir_bind("focus_right", "SUPER", "right", "right")
dir_bind("focus_up", "SUPER", "up", "up")
dir_bind("focus_down", "SUPER", "down", "down")

local ws_mods = binds.workspace_prefix or "SUPER"
local move_ws_mods = binds.move_workspace_prefix or "SUPER SHIFT"

-- Hyprland maps the "0" key to workspace 10 by convention.
local ws_keys = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0" }
for i, key in ipairs(ws_keys) do
  hl.bind(keystr(ws_mods, key), hl.dsp.focus({ workspace = tostring(i) }))
  hl.bind(keystr(move_ws_mods, key), hl.dsp.window.move({ workspace = tostring(i), follow = true }))
end

-- Mouse move/resize (not remapped in this version; low collision risk and
-- extremely standard across compositors).
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- ---- Media / volume keys -------------------------------------------------

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, repeating = true })
hl.bind("XF86AudioMicMute",     hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, repeating = true })
hl.bind("XF86AudioPlay",        hl.dsp.exec_cmd("playerctl play-pause"),                           { locked = true, repeating = true })
hl.bind("XF86AudioPause",       hl.dsp.exec_cmd("playerctl play-pause"),                           { locked = true, repeating = true })
hl.bind("XF86AudioNext",        hl.dsp.exec_cmd("playerctl next"),                                 { locked = true, repeating = true })
hl.bind("XF86AudioPrev",        hl.dsp.exec_cmd("playerctl previous"),                             { locked = true, repeating = true })

-- ---- Screenshots (grim + slurp; not user-customizable in v1) -----------

local screenshot_dir = "$HOME/Pictures/Screenshots"
hl.bind("Print", hl.dsp.exec_cmd(
  "mkdir -p " .. screenshot_dir .. " && grim " .. screenshot_dir .. "/$(date +%Y-%m-%d_%H-%M-%S).png"
))
hl.bind("SUPER + Print", hl.dsp.exec_cmd(
  "mkdir -p " .. screenshot_dir .. " && grim -g \"$(slurp)\" " .. screenshot_dir .. "/$(date +%Y-%m-%d_%H-%M-%S).png"
))

-- ---- Clipboard picker (only wired up if cliphist is enabled) ------------

if USER.components and USER.components.cliphist then
  local mods, key = bindspec(binds.clipboard, "SUPER", "period")
  hl.bind(keystr(mods, key), hl.dsp.exec_cmd("cliphist list | rofi -dmenu | cliphist decode | wl-copy"))
end
