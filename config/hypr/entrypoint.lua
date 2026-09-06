--[[
  entrypoint.lua — installed verbatim as ~/.config/hypr/hyprland.lua.

  Hyprland >= 0.55 reads $XDG_CONFIG_HOME/hypr/hyprland.lua as native Lua
  (hyprlang is deprecated). This file stays tiny and generic on purpose:
  do not hand-edit it. Edit the modules under config/hypr/ in the repo,
  themes/<name>/hypr.lua, or ~/.config/cesarmanzocode-rice/{user,local}.lua,
  then re-run ./apply.sh.

  Everything else this rice needs is installed under
  ~/.config/hypr/cesarmanzocode-rice/, so this file never depends on the
  repo staying checked out at any particular path.
]]

local runtime_dir = (os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config"))
  .. "/hypr/cesarmanzocode-rice"

package.path = runtime_dir .. "/?.lua;" .. package.path

require("init")
