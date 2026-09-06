--[[
  autostart.lua — Hyprland-side startup, deliberately minimal.

  waybar, swaync, hyprpaper, hypridle and hyprpolkitagent are all managed
  as systemd --user services under this project's UWSM lifecycle (enabled
  by install.sh, restarted by apply.sh when their config changes) — see
  scripts/lib/common.sh. Hyprland must never *also* exec them, or a second
  instance appears on every login/reload; that duplication was the actual
  bug behind the components "appearing twice" reports.

  cliphist has no upstream systemd user service, so its watchers are the
  one thing still started here — gated strictly by USER.components, and
  wrapped in `uwsm app --` when available so they get correct
  session/cgroup lifecycle under UWSM (falling back to a plain exec
  otherwise, e.g. outside a UWSM session).
]]

assert(type(USER) == "table", "autostart.lua requires a USER table")

local c = USER.components or {}

local function launch(cmd)
  hl.exec_cmd(
    "sh -c 'command -v uwsm >/dev/null 2>&1 && exec uwsm app -- " .. cmd ..
    " || exec " .. cmd .. "'"
  )
end

if c.cliphist then
  hl.on("hyprland.start", function()
    -- text + image history; single watcher per type.
    launch("wl-paste --type text --watch cliphist store")
    launch("wl-paste --type image --watch cliphist store")
  end)
end
