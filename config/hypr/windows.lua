--[[
  windows.lua — decoration/geometry driven by THEME (layer B: visual).

  THEME is set globally by the generator before this file is loaded; it
  comes from themes/<name>/hypr.lua and contains only colors + geometry,
  never binds or app choices.
]]

local hl = require("hl")

assert(type(THEME) == "table", "windows.lua requires a THEME table")

local c = THEME.colors
local g = THEME.geometry

hl.comment("windows.lua: decoration/geometry from theme '" .. (THEME.name or "?") .. "'")

local function rgba(hex, alpha)
  alpha = alpha or "ff"
  return string.format("rgba(%s%s)", hex, alpha)
end

hl.set_all("general", {
  gaps_in = g.gaps_in,
  gaps_out = g.gaps_out,
  border_size = g.border_size,
  ["col.active_border"] = rgba(c.border_active),
  ["col.inactive_border"] = rgba(c.border_inactive),
  resize_on_border = true,
  allow_tearing = false,
})

hl.set_all("decoration", {
  rounding = g.rounding,
  active_opacity = g.active_opacity,
  inactive_opacity = g.inactive_opacity,
})

hl.set_all("decoration:blur", {
  enabled = g.blur_enabled,
  size = g.blur_size,
  passes = g.blur_passes,
  new_optimizations = true,
  ignore_opacity = true,
})

hl.set_all("decoration:shadow", {
  enabled = g.shadow_enabled,
  range = 12,
  render_power = 2,
  color = rgba("000000", "aa"),
})

-- A handful of low-risk, broadly useful window rules. Nothing app-specific
-- beyond well-known system dialogs.
hl.windowrule("float", "class:^(pavucontrol)$")
hl.windowrule("float", "class:^(nm-connection-editor)$")
hl.windowrule("float", "title:^(Picture-in-Picture)$")
hl.windowrule("size 640 360", "title:^(Picture-in-Picture)$")
hl.windowrule("move 100%-w-24 24", "title:^(Picture-in-Picture)$")

hl.blank()
