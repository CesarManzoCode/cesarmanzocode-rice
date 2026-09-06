--[[
  autostart.lua — exec-once entries, gated strictly by USER.components.

  A component that was not selected at install time must never be
  autostarted, even if it happens to be installed on the system for
  unrelated reasons.
]]

local hl = require("hl")

assert(type(USER) == "table", "autostart.lua requires a USER table")

hl.comment("autostart.lua: only selected components")

local c = USER.components or {}

if c.waybar then
  hl.exec_once("waybar")
end

if c.swaync then
  hl.exec_once("swaync")
end

if c.hyprpaper then
  hl.exec_once("hyprpaper")
end

if c.hypridle then
  hl.exec_once("hypridle")
end

-- Polkit agent is independent of any single visual component but only
-- worth starting if the user opted into the shell stack at all.
if c.polkit then
  hl.exec_once("/usr/lib/polkit-kde-authentication-agent-1")
end

if c.cliphist then
  -- text + image history; single watcher per type, started once by Hyprland
  -- itself (not re-spawned on config reload since exec-once is idempotent
  -- per Hyprland session).
  hl.exec_once("wl-paste --type text --watch cliphist store")
  hl.exec_once("wl-paste --type image --watch cliphist store")
end

hl.blank()
