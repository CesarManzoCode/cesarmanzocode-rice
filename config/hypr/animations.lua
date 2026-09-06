--[[
  animations.lua — shared animation curves/speeds.

  Fast, precise, no "showcase" easing. Themes may override speed/curve
  values in the future via THEME.animations, but monochrome just uses
  these shared defaults.
]]

local hl = require("hl")

hl.comment("animations.lua: fast + precise motion")

hl.set_all("animations", {
  enabled = true,
})

hl.bezier("linear", 0, 0, 1, 1)
hl.bezier("snappy", 0.16, 1, 0.3, 1)
hl.bezier("overshot", 0.05, 0.9, 0.1, 1.05)

hl.animation("windows", true, 3, "snappy")
hl.animation("windowsOut", true, 3, "linear")
hl.animation("border", true, 4, "linear")
hl.animation("borderangle", true, 4, "linear")
hl.animation("fade", true, 3, "linear")
hl.animation("workspaces", true, 3, "snappy")
hl.animation("specialWorkspace", true, 3, "overshot", "slidevert")

hl.blank()
