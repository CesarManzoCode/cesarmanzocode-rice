--[[
  animations.lua — shared animation curves/speeds.

  `speed` is expressed in deciseconds (1.0 = 100ms) — confirmed against this
  project's own Hyprland 0.56.2 documentation reference before this pass;
  do not assume a different unit without re-checking that against whatever
  version is actually installed.

  Every leaf below uses the same hl.animation({ leaf, enabled, speed,
  bezier, style }) shape already exercised on real hardware by the
  pre-existing windows/border/fade/workspaces/specialWorkspace leaves in
  this file — extending it to sibling leaves in Hyprland's own animation
  tree (windowsIn/Out/Move, layersIn/Out, fadeIn/Out/Switch, workspacesIn/
  Out) is the same API, just more of it. A leaf name this exact Hyprland
  build doesn't recognize fails loudly at hl.animation() time and is caught
  by apply.sh's own `hyprctl configerrors` check (which auto-reverts to the
  previous working hyprland.lua) — never a silent partial config.

  Deliberately NOT used anywhere here: spring-based animations. Hyprland's
  spring config field names (damping vs. dampening, etc.) have shifted
  between versions and cannot be verified from this environment — bezier
  curves are quicker to prove correct and already cover everything this
  rice needs. Also deliberately absent: any bounce/wobble/jelly feel,
  workspace travel across the full screen, and anything at or above 300ms.
]]

hl.config({ animations = { enabled = true } })

-- "snappy" — fast ease-out, used for anything appearing/entering.
hl.curve("snappy",   { type = "bezier", points = { {0.16, 1},   {0.3, 1}    } })
-- "linear" — constant rate, used for anything disappearing/closing (a
-- linear fade/shrink reads as quicker and more decisive than an eased one
-- at the same duration).
hl.curve("linear",   { type = "bezier", points = { {0, 0},      {1, 1}      } })
-- "overshot" — a small, single overshoot past 1.0 then settle (not a
-- repeating wobble/jelly), reserved for the one place a little extra
-- personality earns its keep: the special workspace. Control points eased
-- slightly closer to a straight settle than V2's (0.9/1.05 -> 0.95/1.03)
-- after review flagged the original as reading a touch too "bouncy" for
-- this otherwise restrained rice — still a real, single overshoot, just
-- a smaller one.
hl.curve("overshot", { type = "bezier", points = { {0.05, 0.95}, {0.15, 1.03} } })

-- ---- windows -------------------------------------------------------------
-- Opening: a precise, small pop-in. Closing: noticeably quicker than
-- opening — dismissing something should never feel like it's waiting on
-- you. Moving/resizing: tightly bound to the input, effectively 1:1.
-- "windows" is the proven parent leaf from the pre-migration config (open
-- case); "windowsIn" is set identically alongside it in case this build
-- resolves it as the more specific override — redundant, never conflicting.
hl.animation({ leaf = "windows",     enabled = true, speed = 2.0, bezier = "snappy" })
hl.animation({ leaf = "windowsIn",   enabled = true, speed = 2.0, bezier = "snappy" })
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 1.3, bezier = "linear" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 1.0, bezier = "linear" })

-- ---- layers (rofi, waybar, swaync, and other layer-shell surfaces) -------
hl.animation({ leaf = "layersIn",  enabled = true, speed = 1.5, bezier = "snappy" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1.1, bezier = "linear" })

-- ---- fade ------------------------------------------------------------------
-- Fast across the board; fadeOut fastest of all so a closed window/layer
-- never lingers half-visible.
hl.animation({ leaf = "fadeIn",     enabled = true, speed = 1.4, bezier = "snappy" })
hl.animation({ leaf = "fadeOut",    enabled = true, speed = 1.0, bezier = "linear" })
hl.animation({ leaf = "fadeSwitch", enabled = true, speed = 1.3, bezier = "linear" })

-- ---- workspaces ------------------------------------------------------------
-- "slidefade" with a small percentage keeps the travel short (a hint of
-- direction, not a trip across the monitor) and pairs it with a fade —
-- exactly the "short displacement + fade" this rice wants instead of the
-- default full-width slide.
hl.animation({ leaf = "workspaces", enabled = true, speed = 2.4, bezier = "snappy", style = "slidefade 12%" })

-- Special workspace: short, recognizable movement; the one place the
-- slight "overshot" curve is used, for a small, single, deliberate bounce.
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 2.2, bezier = "overshot", style = "slidevert" })

-- ---- border / focus ---------------------------------------------------------
-- Fast, linear — a focus change should read as immediate.
hl.animation({ leaf = "border",      enabled = true, speed = 1.4, bezier = "linear" })
-- borderangle only matters for a rotating/animated gradient border, which
-- this theme doesn't use (windows.lua sets a solid active border color) —
-- left enabled at a modest speed for forward-compatibility, but it has no
-- visible effect today and is not a looping/pulsing effect either way.
hl.animation({ leaf = "borderangle", enabled = true, speed = 3,   bezier = "linear" })
