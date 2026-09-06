--[[
  input.lua — keyboard/mouse/touchpad behavior (shared, theme-agnostic).

  Keyboard layout defaults to LATAM to match the reference environment,
  but this is a *functional* default, not a visual one — override it in
  ~/.config/cesarmanzocode-rice/local.lua on any machine that needs a
  different layout:

    return {
      input = { kb_layout = "us" },
    }
]]

local input_overrides = (type(LOCAL) == "table" and LOCAL.input) or {}
local touchpad_overrides = input_overrides.touchpad or {}

local input_defaults = {
  kb_layout = "latam",
  follow_mouse = 1,
  sensitivity = 0,
  accel_profile = "flat",
}
for k, v in pairs(input_overrides) do
  if k ~= "touchpad" then input_defaults[k] = v end
end

local touchpad_defaults = {
  natural_scroll = false,
  disable_while_typing = true,
}
for k, v in pairs(touchpad_overrides) do touchpad_defaults[k] = v end
input_defaults.touchpad = touchpad_defaults

hl.config({
  input = input_defaults,
  cursor = {
    inactive_timeout = 0,
  },
})
