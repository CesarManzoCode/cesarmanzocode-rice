--[[
  hyprland.lua — entry manifest.

  Hyprland reads hyprlang, not Lua, so this file is not executed by
  Hyprland directly. It's the ordered list of modules that
  scripts/generate-hyprland-conf.lua composes (via `lua`) into the real
  ~/.config/hypr/hyprland.conf. Order matters: monitors/core/input/
  animations/windows before binds/autostart keeps the generated file easy
  to read top to bottom.
]]

return {
  "core.lua",
  "input.lua",
  "animations.lua",
  "windows.lua",
  "monitors.lua",
  "binds.lua",
  "autostart.lua",
}
