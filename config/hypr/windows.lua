--[[
  windows.lua — decoration/geometry driven by THEME (layer B: visual).

  THEME is set globally by init.lua before this file is loaded; it comes
  from themes/<name>/hypr.lua and contains only colors + geometry, never
  binds or app choices.
]]

assert(type(THEME) == "table", "windows.lua requires a THEME table")

local c = THEME.colors
local g = THEME.geometry

local function rgba(hex, alpha)
  return "rgba(" .. hex .. (alpha or "ff") .. ")"
end

hl.config({
  general = {
    gaps_in = g.gaps_in,
    gaps_out = g.gaps_out,
    border_size = g.border_size,
    col = {
      active_border = rgba(c.border_active),
      inactive_border = rgba(c.border_inactive),
    },
    resize_on_border = true,
    allow_tearing = false,
  },

  decoration = {
    rounding = g.rounding,
    active_opacity = g.active_opacity,
    inactive_opacity = g.inactive_opacity,

    blur = {
      enabled = g.blur_enabled,
      size = g.blur_size,
      passes = g.blur_passes,
      new_optimizations = true,
      ignore_opacity = true,
      noise = g.blur_noise,
      contrast = g.blur_contrast,
      brightness = g.blur_brightness,
      vibrancy = g.blur_vibrancy,
      vibrancy_darkness = g.blur_vibrancy_darkness,
    },

    shadow = {
      enabled = g.shadow_enabled,
      range = 12,
      render_power = 2,
      color = rgba("000000", "aa"),
    },
  },
})

-- rounding_power is set in its own hl.config() call, guarded by pcall: it's
-- a newer decoration field than everything above and not guaranteed to
-- exist in every Hyprland 0.55+ build. If this exact installed version
-- rejects it, the error is swallowed here (purely decorative, nothing else
-- in this file depends on it) rather than failing the whole config load —
-- apply.sh's own `hyprctl configerrors` check + auto-revert remains the
-- backstop for anything that *does* break config loading.
if g.rounding_power then
  pcall(function()
    hl.config({ decoration = { rounding_power = g.rounding_power } })
  end)
end

-- A handful of low-risk, broadly useful window rules. Nothing app-specific
-- beyond well-known system dialogs.
hl.window_rule({
  name = "float-pavucontrol",
  match = { class = "^(pavucontrol)$" },
  float = true,
})

hl.window_rule({
  name = "float-nm-editor",
  match = { class = "^(nm-connection-editor)$" },
  float = true,
})

hl.window_rule({
  name = "pip-float",
  match = { title = "^(Picture-in-Picture)$" },
  float = true,
  -- vec2 fields take two separate expressions, not a packed string
  -- ("640x360" / "100%-w-24 24" were leftovers from the old hyprlang
  -- text syntax and fail Hyprland 0.56's native Lua parser).
  size = { 640, 360 },
  move = { "monitor_w-window_w-24", "24" },
})
