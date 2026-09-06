--[[
  animations.lua — shared animation curves/speeds.

  Fast, precise, no "showcase" easing. Same curves/speeds as before the
  migration, just expressed with hl.curve()/hl.animation() tables instead
  of hyprlang `bezier =` / `animation =` lines.
]]

hl.config({ animations = { enabled = true } })

hl.curve("linear",   { type = "bezier", points = { {0, 0},      {1, 1}      } })
hl.curve("snappy",   { type = "bezier", points = { {0.16, 1},   {0.3, 1}    } })
hl.curve("overshot", { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.05} } })

hl.animation({ leaf = "windows",          enabled = true, speed = 3, bezier = "snappy" })
hl.animation({ leaf = "windowsOut",       enabled = true, speed = 3, bezier = "linear" })
hl.animation({ leaf = "border",           enabled = true, speed = 4, bezier = "linear" })
hl.animation({ leaf = "borderangle",      enabled = true, speed = 4, bezier = "linear" })
hl.animation({ leaf = "fade",             enabled = true, speed = 3, bezier = "linear" })
hl.animation({ leaf = "workspaces",       enabled = true, speed = 3, bezier = "snappy" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 3, bezier = "overshot", style = "slidevert" })
