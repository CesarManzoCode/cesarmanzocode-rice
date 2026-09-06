--[[
  init.lua — cesarmanzocode-rice Hyprland runtime, loaded by entrypoint.lua
  (installed as ~/.config/hypr/hyprland.lua).

  Loads USER/LOCAL from ~/.config/cesarmanzocode-rice/ — outside this
  runtime directory, so apply.sh never touches them — plus the active
  theme (theme.lua, installed alongside this file), then requires each
  module in order. Modules read the USER/LOCAL/THEME globals set here,
  same shared-state pattern as the pre-migration architecture, just
  without a hyprlang text generator in between.
]]

local function config_home()
  return os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")
end

local function load_table(path)
  local f = io.open(path, "r")
  if not f then return nil end
  f:close()
  local chunk, err = loadfile(path)
  if not chunk then
    error("cesarmanzocode-rice: failed to parse " .. path .. ": " .. tostring(err))
  end
  return chunk()
end

local state_dir = config_home() .. "/cesarmanzocode-rice"

USER = load_table(state_dir .. "/user.lua")
  or error("cesarmanzocode-rice: missing " .. state_dir .. "/user.lua — run ./install.sh")
LOCAL = load_table(state_dir .. "/local.lua") or {}
THEME = assert(require("theme"), "cesarmanzocode-rice: missing theme.lua (installed by apply.sh)")

require("core")
require("input")
require("animations")
require("windows")
require("layers")
require("monitors")
require("binds")
require("autostart")
