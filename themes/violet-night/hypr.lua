--[[
  themes/violet-night/hypr.lua — visual layer only (layer B).

  No binds, no app choices, nothing functional lives here on purpose:
  switching themes must never change behavior, only looks.

  Identity: nocturnal / technological / cinematic. A near-black
  blue-violet base with deep purple surfaces, a bright but tightly
  contained violet accent (border_active/accent only — everything else
  stays desaturated near-black so the accent actually reads as an
  accent), and cool off-white foreground. More atmospheric/layered than
  monochrome (lower opacities, stronger blur) but not as dense/opaque as
  an industrial "ember" theme.
]]

return {
  name = "violet-night",

  colors = {
    background         = "0A0812",
    background_alt     = "100D1D",
    surface            = "16122A",
    surface_alt        = "1E1836",
    foreground         = "E7E3F6",
    foreground_strong  = "F6F4FF",
    muted              = "8C84AD",
    subtle             = "463D66",
    border_inactive    = "342B52",
    border_active      = "A970FF",
    accent             = "A970FF",
  },

  geometry = {
    border_size      = 2,
    gaps_in          = 10,
    gaps_out         = 20,
    rounding         = 14,
    -- A touch less than monochrome's rounding_power (4 -> 3.5): corners
    -- stay a soft squircle but slightly less "pillowy" now that rounding
    -- itself is bigger, so the shape doesn't get mushy.
    rounding_power   = 3.5,
    blur_enabled     = true,
    -- Blur is expressive here, not incidental: bigger/more passes than
    -- monochrome (6/2 -> 9/3) so translucent surfaces read as genuinely
    -- deep/layered rather than a lightly-softened plate.
    blur_size        = 9,
    blur_passes      = 3,
    -- More noise than monochrome to keep the (much stronger) blur from
    -- reading as a flat gradient, contrast/brightness pulled down a bit
    -- further so bright wallpaper glows don't wash through the glass, and
    -- unlike monochrome this theme actually has color to carry — a modest
    -- amount of vibrancy so violet tints the blur itself instead of
    -- staying purely a border/accent color.
    blur_noise             = 0.035,
    blur_contrast          = 1.1,
    blur_brightness        = 0.82,
    blur_vibrancy          = 0.18,
    blur_vibrancy_darkness = 0.25,
    shadow_enabled   = true,
    -- Noticeably lower than monochrome's 1.0/0.97 — the atmospheric,
    -- layered look the brief asks for, without going as translucent as an
    -- overlay/HUD.
    active_opacity   = 0.94,
    inactive_opacity = 0.82,
  },

  -- Slightly more underdamped than monochrome's own defaults (see
  -- config/hypr/animations.lua) across the board — a bit more "alive"/
  -- cinematic, similar to or a touch livelier than monochrome's own
  -- specialWorkspace spring (ratio ~0.73), but every ratio here still
  -- sits comfortably inside the 0.7-0.95 band: at most a faint overshoot,
  -- never a repeating wobble.
  motion = {
    springs = {
      -- critical ~= 2*sqrt(310) ~= 35.21; damping 28 -> ratio ~0.80
      -- (monochrome: stiffness 310/damping 31, ratio ~0.88).
      window            = { stiffness = 310, damping = 28 },
      -- critical ~= 2*sqrt(250) ~= 31.62; damping 25 -> ratio ~0.79
      -- (monochrome: stiffness 250/damping 27, ratio ~0.85).
      workspace         = { stiffness = 250, damping = 25 },
      -- critical ~= 2*sqrt(330) ~= 36.33; damping 31 -> ratio ~0.85
      -- (monochrome: stiffness 330/damping 33, ratio ~0.91) — still the
      -- "most solid" spring of the set, just not as stiff as monochrome's.
      layer             = { stiffness = 330, damping = 31 },
      -- critical ~= 2*sqrt(250) ~= 31.62; damping 24 -> ratio ~0.76
      -- (monochrome: stiffness 250/damping 23, ratio ~0.73) — close to
      -- monochrome's own special-workspace feel, a hair firmer.
      special_workspace = { stiffness = 250, damping = 24 },
    },
  },

  wallpaper = "wallpapers/violet-night.png",
}
