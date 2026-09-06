--[[
  themes/arctic-glass/hypr.lua — visual layer only (layer B).

  No binds, no app choices, nothing functional lives here on purpose:
  switching themes must never change behavior, only looks.

  Identity: cold, light, airy, translucent glass — deep blue-tinted
  blacks, cool grays, a very controlled ice-blue/cyan accent used only on
  border_active/accent (never washed across the whole palette). See
  docs/themes/arctic-glass.md for the full rationale and the exact deltas
  from monochrome's numbers.
]]

return {
  name = "arctic-glass",

  colors = {
    background         = "0A0F16",
    background_alt     = "0D141C",
    surface            = "121B25",
    surface_alt        = "1A2530",
    foreground         = "E8F0F5",
    foreground_strong  = "FFFFFF",
    muted              = "8CA0AF",
    subtle             = "3D4C58",
    border_inactive    = "2A3A46",
    border_active      = "7FD8E8",
    accent             = "7FD8E8",
  },

  geometry = {
    -- Thin, soft border — a hairline of ice-blue on focus, not a frame.
    border_size      = 1,
    -- More breathing room than monochrome's 8/16 — panels read as
    -- floating glass, not tiled slabs.
    gaps_in          = 10,
    gaps_out         = 20,
    -- Gentler, larger rounding than monochrome's 9.
    rounding         = 14,
    -- rounding_power: closer to 2 (perfectly circular) than monochrome's
    -- 4 (squircle) — a rounder, softer corner suits a glass panel better
    -- than a technical squircle. Applied defensively in windows.lua
    -- (pcall) since it's not present in every Hyprland build.
    rounding_power   = 3,
    blur_enabled     = true,
    -- Real depth: much heavier blur than monochrome's 6/2 so glass panels
    -- genuinely separate from the wallpaper behind them.
    blur_size        = 10,
    blur_passes      = 4,
    -- A touch of noise keeps the blur from reading as a flat plate; mild
    -- vibrancy (unlike monochrome's 0) lets the cool wallpaper hues bleed
    -- through the glass instead of graying out, and a slight brightness
    -- lift (vs. monochrome's dimming 0.9) keeps the frost feeling light,
    -- not murky.
    blur_noise             = 0.015,
    blur_contrast          = 1.02,
    blur_brightness        = 1.06,
    blur_vibrancy          = 0.15,
    blur_vibrancy_darkness = 0.2,
    shadow_enabled   = true,
    -- Visibly more transparent than monochrome's 1.0/0.97 — panels must
    -- read as glass, not solid slabs, without losing legibility.
    active_opacity   = 0.92,
    inactive_opacity = 0.82,
  },

  -- "Glide" motion: smooth, fluid, near-critically-damped (ratio ~0.9-0.95
  -- across the board) so nothing bounces, just settles — and a little
  -- longer/softer than monochrome's timings so it reads as floaty/premium
  -- without ever feeling laggy. See docs/themes/arctic-glass.md for the
  -- damping-ratio arithmetic behind each pair below.
  motion = {
    springs = {
      -- critical = 2*sqrt(220) ~= 29.7; damping 28 -> ratio ~0.944.
      window            = { stiffness = 220, damping = 28 },
      -- critical = 2*sqrt(190) ~= 27.6; damping 26 -> ratio ~0.943.
      workspace         = { stiffness = 190, damping = 26 },
      -- critical = 2*sqrt(230) ~= 30.3; damping 28 -> ratio ~0.923.
      layer             = { stiffness = 230, damping = 28 },
      -- critical = 2*sqrt(190) ~= 27.6; damping 25 -> ratio ~0.907 — the
      -- least damped of the set, still firmly in "no bounce" territory.
      special_workspace = { stiffness = 190, damping = 25 },
    },
    speeds = {
      windows        = 1.9,
      windows_in     = 2.1,
      windows_out    = 1.3,
      windows_move   = 0.9,
      layers_in      = 1.8,
      layers_out     = 1.2,
      fade_in        = 1.15,
      fade_out       = 0.9,
      workspaces     = 2.3,
      special_workspace = 2.3,
      border         = 0.85,
    },
    styles = {
      -- Softer pop-in (less shrink) than monochrome's 94% — a gentler
      -- materialize suits the glide feel.
      windows_popin     = "popin 96%",
      -- Smaller displacement than monochrome's 15%/12% — a hint of drift
      -- rather than a slide, matching a lighter, floatier surface.
      workspaces        = "slidefade 10%",
      special_workspace = "slidefadevert 8%",
    },
  },

  wallpaper = "wallpapers/arctic-glass.png",
}
