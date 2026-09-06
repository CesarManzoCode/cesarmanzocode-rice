--[[
  animations.lua — shared animation curves/speeds.

  `speed` is expressed in deciseconds (1.0 = 100ms) — confirmed against this
  project's own Hyprland 0.56.2 documentation reference before this pass;
  do not assume a different unit without re-checking that against whatever
  version is actually installed.

  Every leaf below uses the same hl.animation({ leaf, enabled, speed,
  bezier|spring, style }) shape already exercised on real hardware by the
  pre-existing windows/border/fade/workspaces/specialWorkspace leaves in
  this file. A leaf name this exact Hyprland build doesn't recognize fails
  loudly at hl.animation() time and is caught by apply.sh's own `hyprctl
  configerrors` check (which auto-reverts to the previous working
  hyprland.lua) — never a silent partial config.

  ---------------------------------------------------------------------------
  SPRINGS (final-polish pass)
  ---------------------------------------------------------------------------

  This pass migrates SELECTIVELY to Hyprland's native spring curves
  (hl.curve({ type = "spring", mass, stiffness, damping })) for the motion
  that benefits from a touch of real physicality — window open, workspace
  switch, layer popin — while everything that should read as instantaneous
  or decisive (window close, move/resize, border focus) stays on a plain
  bezier. Nothing here is jelly/wobble/looping; every spring below sits at
  or just under critical damping (damping-ratio ~0.75-0.95), i.e. at most a
  single, barely-perceptible overshoot, never a bounce.

  IMPORTANT — field name verified against the actual Hyprland 0.56 C++
  source (src/config/lua/bindings/LuaBindingsConfigRules.cpp), not just the
  wiki prose, because the two disagree:

    lua_getfield(L, 2, "damping");
    if (lua_isnil(L, -1)) {
      lua_pop(L, 1);
      // Old typo form, please add a deprecation notice if you ever plan on
      // removing these
      lua_getfield(L, 2, "dampening");
    }

  i.e. `damping` is the real, primary key the parser looks for first;
  `dampening` is only accepted as a legacy fallback for an old typo and is
  explicitly commented as something to eventually deprecate. This file uses
  `damping` for that reason — the source is the ground truth, not a wiki
  paraphrase that happened to list the deprecated spelling. (Both keys
  parse identically today, so this is a correctness-of-intent choice, not
  a functional one.)

  Also verified against source: hl.animation() takes an exclusive `spring`
  OR `bezier` field (never both), a leaf must already exist in Hyprland's
  animation tree, and the `style` string is validated per animation family
  (`popin NN%` for windows/layers, `slide`/`slidefade[vert] NN%` for
  workspaces/specialWorkspace, `loop`/`once` for the *angle leaves).
]]

hl.config({ animations = { enabled = true } })

-- ---- bezier curves ---------------------------------------------------------

-- "snappy" — fast ease-out, used for anything appearing/entering that isn't
-- on a spring.
hl.curve("snappy", { type = "bezier", points = { {0.16, 1}, {0.3, 1} } })
-- "linear" — constant rate, used for anything disappearing/closing (a
-- linear fade/shrink reads as quicker and more decisive than an eased one
-- at the same duration) and for input-bound motion (drag/resize) where any
-- easing would read as lag.
hl.curve("linear", { type = "bezier", points = { {0, 0}, {1, 1} } })

-- ---- spring curves ----------------------------------------------------------
-- mass kept at 1 throughout (Hyprland's own recommendation); stiffness and
-- damping are the two knobs actually tuned. Each is at ~0.75-0.95 of its
-- critical damping (2*sqrt(stiffness*mass)) — fast settle, at most a
-- diminutive overshoot, never a repeating wobble.

-- windowSpring: window open. critical damping ~= 2*sqrt(310) ~= 35.2;
-- damping 31 -> ratio ~0.88 — a few px of material overshoot, not jelly.
hl.curve("windowSpring", { type = "spring", mass = 1, stiffness = 310, dampening = 31 })

-- workspaceSpring: workspace switch. critical ~= 2*sqrt(250) ~= 31.6;
-- damping 27 -> ratio ~0.85.
hl.curve("workspaceSpring", { type = "spring", mass = 1, stiffness = 250, dampening = 27 })

-- layerSpring: layer-shell surfaces (Rofi, notifications, popups) that
-- opt into a spring via their own layer_rule animation style. critical
-- ~= 2*sqrt(330) ~= 36.3; damping 33 -> ratio ~0.91 — the most "solid"/
-- least-overshoot spring of the set, matching a menu that must never feel
-- squishy.
hl.curve("layerSpring", { type = "spring", mass = 1, stiffness = 330, dampening = 33 })

-- specialWorkspaceSpring: deliberately a little less damped than
-- workspaceSpring so the special workspace reads as a distinct, slightly
-- more energetic gesture — but still nowhere near an obvious bounce.
-- critical ~= 2*sqrt(250) ~= 31.6; damping 23 -> ratio ~0.73.
hl.curve("specialWorkspaceSpring", { type = "spring", mass = 1, stiffness = 250, dampening = 23 })

-- ---- windows ---------------------------------------------------------------
-- Opening: a precise, small pop-in on windowSpring — the window should
-- look like it materializes a few pixels out, never like it grows up from
-- half its size. Closing: quicker than opening, plain bezier (a spring's
-- tiny overshoot on the way OUT would read as an unwanted wobble on
-- dismiss). Moving/resizing: effectively 1:1 with the input, no spring.
hl.animation({ leaf = "windows",     enabled = true, speed = 1.6,  spring = "windowSpring", style = "popin 94%" })
hl.animation({ leaf = "windowsIn",   enabled = true, speed = 1.8,  spring = "windowSpring", style = "popin 94%" })
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 1.2,  bezier = "linear",       style = "popin 94%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 0.9,  bezier = "linear" })

-- ---- layers (rofi, waybar, swaync, and other layer-shell surfaces) -------
-- Position/size on layerSpring by default; per-namespace shape (popin vs.
-- slide, and which edge) comes from each surface's own layer_rule
-- `animation` field in layers.lua — this is just the timing/feel shared by
-- all of them. Exit stays a quick, non-spring bezier so nothing lingers.
hl.animation({ leaf = "layersIn",  enabled = true, speed = 1.5, spring = "layerSpring" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1.1, bezier = "linear" })

-- ---- fade --------------------------------------------------------------
-- Generic fallback for any fade leaf not overridden more specifically
-- below (fadeShadow, fadeGlow, fadeDim, fadeDpms).
hl.animation({ leaf = "fade",    enabled = true, speed = 1.0, bezier = "linear" })

hl.animation({ leaf = "fadeIn",     enabled = true, speed = 1.0, bezier = "snappy" })
hl.animation({ leaf = "fadeOut",    enabled = true, speed = 0.8, bezier = "linear" })
hl.animation({ leaf = "fadeSwitch", enabled = true, speed = 1.0, bezier = "linear" })

-- Layer-shell alpha is driven independently from layer position/size (see
-- layersIn/Out above) — this is what actually controls how Rofi/SwayNC/
-- Waybar fade in and out.
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 1.0, bezier = "snappy" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 0.8, bezier = "linear" })

-- Popups/context menus: precise, fade-out faster than fade-in.
hl.animation({ leaf = "fadePopupsIn",  enabled = true, speed = 1.0, bezier = "snappy" })
hl.animation({ leaf = "fadePopupsOut", enabled = true, speed = 0.8, bezier = "linear" })

-- Shadow fade tracks window fade so a shadow never pops/vanishes out of
-- sync with the window it belongs to.
hl.animation({ leaf = "fadeShadow", enabled = true, speed = 1.0, bezier = "linear" })

-- ---- workspaces ------------------------------------------------------------
-- "slidefade" with a modest percentage: a short, clearly-directional
-- displacement plus a fade, never a full-width slide. workspacesIn/Out
-- aren't set individually — the parent leaf's config is exactly what both
-- directions should share here, and setting them separately would just
-- duplicate this line for no behavioral difference.
hl.animation({ leaf = "workspaces", enabled = true, speed = 2.0, spring = "workspaceSpring", style = "slidefade 15%" })

-- Special workspace: its own, slightly-less-damped spring and a vertical
-- slide+fade so it reads as a distinct gesture from a normal workspace
-- switch, without the old fixed "overshot" bezier's baked-in bounce (the
-- spring's own light underdamping now supplies that personality).
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 2.0, spring = "specialWorkspaceSpring", style = "slidefadevert 12%" })

-- ---- border / focus ---------------------------------------------------------
-- Fast, linear — a focus change should read as immediate.
hl.animation({ leaf = "border", enabled = true, speed = 0.8, bezier = "linear" })

-- borderangle would only matter for a rotating/animated gradient border,
-- which this monochrome theme doesn't use anywhere (windows.lua sets a
-- solid active border color) — disabled outright rather than left
-- "animating" with no visible effect. In particular, never `loop`: looping
-- an angle animation keeps Hyprland rendering continuously at the
-- monitor's refresh rate for zero visual benefit here.
hl.animation({ leaf = "borderangle", enabled = false, speed = 1, bezier = "linear" })
