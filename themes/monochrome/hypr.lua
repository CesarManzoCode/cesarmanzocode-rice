--[[
  themes/monochrome/hypr.lua — visual layer only (layer B).

  No binds, no app choices, nothing functional lives here on purpose:
  switching themes must never change behavior, only looks.
]]

return {
  name = "monochrome",

  colors = {
    background         = "050505",
    background_alt     = "0B0B0B",
    surface            = "101010",
    surface_alt        = "181818",
    foreground         = "F4F4F4",
    foreground_strong  = "FFFFFF",
    muted              = "9A9A9A",
    subtle             = "555555",
    border_inactive    = "383838",
    border_active      = "F0F0F0",
    accent             = "FFFFFF",
  },

  geometry = {
    border_size      = 1,
    gaps_in          = 8,
    gaps_out         = 16,
    rounding         = 9,
    -- rounding_power: Hyprland's corner-exponent field (2 = perfectly
    -- circular, its own default; a bit higher softens corners into a
    -- subtle squircle without touching the `rounding` radius itself).
    -- Applied defensively in windows.lua (pcall) since it's not present in
    -- every Hyprland build.
    rounding_power   = 4,
    blur_enabled     = true,
    blur_size        = 6,
    blur_passes      = 2,
    -- Mild depth cues on the blur itself — no vibrancy/saturation (this
    -- theme has no color to boost), a touch of noise so the blur doesn't
    -- read as a flat grey plate, and slightly reduced brightness/contrast
    -- so bright wallpaper regions don't wash out through translucent UI.
    blur_noise             = 0.02,
    blur_contrast          = 1.05,
    blur_brightness        = 0.9,
    blur_vibrancy          = 0,
    blur_vibrancy_darkness = 0,
    shadow_enabled   = true,
    active_opacity   = 1.0,
    inactive_opacity = 0.97,
  },

  wallpaper = "wallpapers/monochrome.png",
}
