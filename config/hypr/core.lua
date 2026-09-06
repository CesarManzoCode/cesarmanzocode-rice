--[[
  core.lua — shared, theme-agnostic Hyprland behavior.

  This is layer A (common functionality) from the project's architecture:
  no colors, no personal binds, nothing machine-specific. Geometry values
  that are visual (rounding, blur, gaps) come from THEME and are applied
  in windows.lua, not here.
]]

local hl = require("hl")

hl.comment("core.lua: layout + general behavior (shared across themes)")

hl.set_all("general", {
  ["layout"] = "dwindle",
})

hl.set_all("dwindle", {
  pseudotile = true,
  preserve_split = true,
})

hl.set_all("misc", {
  disable_hyprland_logo = true,
  disable_splash_rendering = true,
  -- Tearing off by default: avoids visual artifacts, fine for a general
  -- desktop rice. Games that need it can opt in via a per-window rule.
  vfr = true,
  vrr = 0,
})

hl.set_all("render", {
  direct_scanout = false,
})

hl.blank()
