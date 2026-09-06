--[[
  core.lua — shared, theme-agnostic Hyprland behavior (layer A).

  No colors, no personal binds, nothing machine-specific. Visual geometry
  (rounding, blur, gaps) comes from THEME and is applied in windows.lua.
]]

hl.config({
  general = {
    layout = "dwindle",
  },

  dwindle = {
    -- dwindle:pseudotile was removed upstream — pseudotiling is per-window
    -- only now (the `pseudo` dispatcher / a window rule), so there is
    -- nothing global to set here in its place.
    preserve_split = true,
  },

  misc = {
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
    -- Tearing off by default: avoids visual artifacts, fine for a general
    -- desktop rice. Games that need it can opt in via a per-window rule.
    vrr = 0,
  },

  -- vfr moved from `misc` to `debug` upstream; same setting, new home.
  debug = {
    vfr = true,
  },

  render = {
    -- direct_scanout is an int now (0 off / 1 on / 2 always), not a bool.
    direct_scanout = 0,
  },
})
