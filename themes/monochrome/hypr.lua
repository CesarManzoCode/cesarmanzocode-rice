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
    blur_enabled     = true,
    blur_size        = 4,
    blur_passes      = 2,
    shadow_enabled   = true,
    active_opacity   = 1.0,
    inactive_opacity = 0.97,
  },

  wallpaper = "wallpapers/monochrome.png",
}
