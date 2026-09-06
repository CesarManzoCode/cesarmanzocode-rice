--[[
  monitors.lua — generic monitor default.

  Deliberately NOT hardcoded to any output name, resolution or refresh
  rate. A specific machine adds its own layout in
  ~/.config/cesarmanzocode-rice/local.lua, e.g.:

    return {
      monitors = {
        { output = "HDMI-A-1", mode = "1920x1080@75", position = "0x0", scale = "1" },
      },
    }

  Local monitor rules are applied *after* the generic default below, and
  Hyprland applies monitor rules in order, so a specific override wins.
]]

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

if type(LOCAL) == "table" and type(LOCAL.monitors) == "table" then
  for _, m in ipairs(LOCAL.monitors) do
    hl.monitor(m)
  end
end
