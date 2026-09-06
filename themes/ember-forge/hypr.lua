--[[
  themes/ember-forge/hypr.lua — visual layer only (layer B).

  No binds, no app choices, nothing functional lives here on purpose:
  switching themes must never change behavior, only looks.

  Identity: industrial/carbon — dense, solid, mechanical. Charcoal/carbon
  bases with dark warm browns, copper/amber used only as a measured
  accent (border_active/accent), never a bright-orange gamer palette.
  Geometry reads as material/opaque, not glass (see docs/themes/
  ember-forge.md for the full comparison against monochrome).
]]

return {
  name = "ember-forge",

  colors = {
    background         = "0C0907",
    background_alt     = "140F0B",
    surface            = "1D1610",
    surface_alt        = "281E16",
    foreground         = "EAE0D5",
    foreground_strong  = "FFF6EC",
    muted              = "9C8570",
    subtle             = "4F3F32",
    border_inactive    = "3D2E23",
    border_active      = "C97536",
    accent             = "E8973B",
  },

  geometry = {
    -- Thicker, more present border than monochrome's 1 — a tool's frame,
    -- not a hairline.
    border_size      = 2,
    -- Tighter gaps than monochrome's 8/16 — dense, not floaty.
    gaps_in          = 5,
    gaps_out         = 10,
    -- Small/tense rounding vs. monochrome's 9 — corners read as machined,
    -- not soft.
    rounding         = 3,
    -- rounding_power: kept near Hyprland's own circular default (2) rather
    -- than monochrome's softened-squircle 4, so the little rounding this
    -- theme does use stays geometric/precise instead of organic.
    rounding_power   = 2,
    blur_enabled     = true,
    -- Less blur than monochrome's 6/2 in both size and pass count —
    -- surfaces read as solid material with only a hint of depth, not
    -- glass.
    blur_size        = 3,
    blur_passes      = 1,
    blur_noise             = 0.03,
    blur_contrast          = 1.1,
    blur_brightness        = 0.85,
    -- A little vibrancy (monochrome uses none, having no color to boost)
    -- so the copper/amber undertone still reads faintly through the
    -- blur instead of turning it into a flat grey plate.
    blur_vibrancy          = 0.2,
    blur_vibrancy_darkness = 0.3,
    shadow_enabled   = true,
    -- Closer to fully opaque than monochrome's 1.0/0.97 pair — less
    -- transparency all around, firmer visual weight.
    active_opacity   = 1.0,
    inactive_opacity = 0.99,
  },

  -- Firm/dry/terse: faster than the shared defaults (see
  -- config/hypr/animations.lua) and damping ratios pushed up toward
  -- 0.92-0.95 so motion settles almost without overshoot — decisive and
  -- mechanical rather than springy. See docs/themes/ember-forge.md for the
  -- exact ratio math against monochrome's own (unset -> shared-default)
  -- springs.
  motion = {
    springs = {
      -- critical ~= 2*sqrt(420) ~= 41.0; damping 38 -> ratio ~0.93 (vs
      -- the shared default's 310/31 -> ~0.88).
      window            = { stiffness = 420, damping = 38 },
      -- critical ~= 2*sqrt(340) ~= 36.9; damping 34 -> ratio ~0.92 (vs
      -- default 250/27 -> ~0.85).
      workspace         = { stiffness = 340, damping = 34 },
      -- critical ~= 2*sqrt(420) ~= 41.0; damping 39 -> ratio ~0.95 (vs
      -- default 330/33 -> ~0.91) — the firmest of the set, matching a
      -- menu/panel that must feel like it clicks into place.
      layer             = { stiffness = 420, damping = 39 },
      -- critical ~= 2*sqrt(300) ~= 34.6; damping 32 -> ratio ~0.92 (vs
      -- default 250/23 -> ~0.73) — deliberately far firmer than
      -- monochrome here: the special workspace should feel like a solid
      -- mechanical shift, not an energetic bounce.
      special_workspace = { stiffness = 300, damping = 32 },
    },
    speeds = {
      windows           = 1.2,
      windows_in        = 1.3,
      windows_out       = 0.9,
      windows_move      = 0.7,
      layers_in         = 1.1,
      layers_out        = 0.8,
      fade_in           = 0.75,
      fade_out          = 0.6,
      workspaces        = 1.3,
      special_workspace = 1.3,
      border            = 0.5,
    },
    styles = {
      -- Tighter pop-in than the shared default's "popin 94%" — less
      -- growth on arrival, reads as a snap into place rather than a
      -- soft materialization.
      windows_popin     = "popin 97%",
      workspaces        = "slidefade 8%",
      special_workspace = "slidefadevert 8%",
    },
  },

  wallpaper = "wallpapers/ember-forge.png",

  -- Structural pass: Waybar is now a LEFT VERTICAL DOCK (see
  -- themes/ember-forge/waybar/config.jsonc — position: "left") and Rofi
  -- is anchored to the left edge near the dock (see
  -- themes/ember-forge/rofi/config.rasi — location/anchor: west), not
  -- the v1 defaults (waybar sliding from the top, Rofi centered popin).
  -- SwayNC keeps the v1 default edge (docks top-right, slides from the
  -- right) — only its card styling/margins/width changed, not its edge —
  -- so it is deliberately omitted here and falls back to
  -- config/hypr/layers.lua's default "slide right".
  layers = {
    waybar = { animation = "slide left" },
    rofi   = { animation = "slide left" },
  },
}
