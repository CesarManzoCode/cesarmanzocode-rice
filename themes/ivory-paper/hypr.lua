--[[
  themes/ivory-paper/hypr.lua — visual layer only (layer B).

  No binds, no app choices, nothing functional lives here on purpose:
  switching themes must never change behavior, only looks.

  ivory-paper is the rice's one LIGHT theme: paper + ink, editorial and
  quiet. Contrast comes from typography/hierarchy, not saturation — the
  palette below has zero loud/saturated colors, and geometry favors thin
  borders, generous whitespace, and light/near-opaque surfaces over the
  heavier glass/blur look the dark themes use (see docs/themes/
  ivory-paper.md for the reasoning against monochrome's numbers).
]]

return {
  name = "ivory-paper",

  colors = {
    background         = "F7F4EE",
    background_alt     = "EFEAE0",
    surface            = "FBF9F4",
    surface_alt        = "F1ECE2",
    foreground         = "262319",
    foreground_strong  = "141210",
    muted              = "8D8574",
    subtle             = "C7BFAE",
    border_inactive    = "DDD6C7",
    border_active      = "2B2820",
    accent             = "5B6B5E",
  },

  geometry = {
    border_size      = 1,
    gaps_in          = 10,
    gaps_out         = 20,
    rounding         = 10,
    -- Slightly softer squircle than monochrome's 4 — a light theme reads
    -- calmer with corners a touch rounder, without changing `rounding`
    -- itself. Still applied defensively in windows.lua (pcall).
    rounding_power   = 3,
    -- Deliberately light blur: heavy glass reads muddy on a paper-white
    -- background, so this theme uses less than half of monochrome's
    -- blur_size and a single pass, with neutral noise/contrast/brightness
    -- (no darkening needed — there's no bright wallpaper to tame here).
    blur_enabled     = true,
    blur_size        = 3,
    blur_passes      = 1,
    blur_noise             = 0.01,
    blur_contrast          = 1.0,
    blur_brightness        = 1.0,
    blur_vibrancy          = 0,
    blur_vibrancy_darkness = 0,
    shadow_enabled   = true,
    -- Near-fully opaque throughout — light "glass" looks muddy, so depth
    -- here comes from the (light) shadow, not from transparency.
    active_opacity   = 1.0,
    inactive_opacity = 0.99,
  },

  -- Discreet/editorial/precise motion: damping ratios sit near the top of
  -- the contract's safe range (~0.9-0.95, vs. monochrome's ~0.73-0.91) and
  -- speeds are trimmed down from the shared defaults, so everything reads
  -- as quick and firm rather than cinematic. See docs/themes/
  -- ivory-paper.md for the exact ratios.
  motion = {
    springs = {
      window            = { stiffness = 320, damping = 33 },
      workspace         = { stiffness = 260, damping = 30 },
      layer             = { stiffness = 340, damping = 35 },
      special_workspace = { stiffness = 260, damping = 29 },
    },
    speeds = {
      windows            = 1.2,
      windows_in         = 1.3,
      windows_out        = 0.9,
      windows_move       = 0.7,
      layers_in          = 1.1,
      layers_out         = 0.8,
      fade_in            = 0.8,
      fade_out           = 0.6,
      workspaces         = 1.4,
      special_workspace  = 1.4,
      border             = 0.6,
    },
    styles = {
      windows_popin     = "popin 96%",
      workspaces        = "slidefade 8%",
      special_workspace = "slidefadevert 8%",
    },
  },

  wallpaper = "wallpapers/ivory-paper.png",
}
