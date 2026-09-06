--[[
  tests/lua/check_binds_and_windows.lua — regression tests for the two
  Hyprland 0.56.2 real-parser errors that a plain loadfile() syntax check
  cannot catch:

    - binds.lua: multi-modifier bind strings must be "SUPER + SHIFT + S",
      never the packed "SUPER SHIFT + S".
    - windows.lua: the pip-float window rule's vec2 fields (size, move)
      must be native { a, b } tables, never a packed "640x360" string.

  Run standalone: lua tests/lua/check_binds_and_windows.lua
  (invoked from tests/run_tests.sh, gated on `command -v lua`.)
]]

local SELF_DIR = arg[0]:match("(.*/)") or "./"
package.path = SELF_DIR .. "?.lua;" .. package.path

local REPO_ROOT = SELF_DIR .. "../../"

local hl_mock = require("hl_mock")
_G.hl = hl_mock

local failures = {}
local function check(name, cond, detail)
  if cond then
    print("  ok " .. name)
  else
    print("  ✗ " .. name .. (detail and (" — " .. detail) or ""))
    failures[#failures + 1] = name
  end
end

-- ---- binds.lua ------------------------------------------------------------

-- Mirrors what install.sh's --defaults actually writes to user.lua (see
-- scripts/lib/binds.sh normalizing "SUPER+SHIFT+S" -> mods="SUPER SHIFT"),
-- so this exercises the exact shape that broke on the real Arch box.
_G.USER = {
  apps = {
    terminal = "kitty",
    browser = "brave",
    filemanager = "dolphin",
    launcher = "rofi -show drun",
  },
  binds = {
    terminal = { mods = "SUPER", key = "T" },
    close_window = { mods = "SUPER", key = "X" },
    special_toggle = { mods = "SUPER", key = "S" },
    special_move = { mods = "SUPER SHIFT", key = "S" },
    -- exercise the "+"-separated storage form too, in case a hand-edited
    -- user.lua uses it instead of whitespace-separated.
    move_workspace_prefix = "SUPER+SHIFT",
  },
}

local ok, err = pcall(dofile, REPO_ROOT .. "config/hypr/binds.lua")
check("binds.lua loads and runs against the mock", ok, err)

if ok then
  local function find_bind(dispatcher_name, matcher)
    for _, b in ipairs(hl_mock.binds) do
      if b.dispatcher and b.dispatcher.__dispatcher == dispatcher_name and (not matcher or matcher(b)) then
        return b
      end
    end
    return nil
  end

  local special_move = find_bind("window.move", function(b)
    return b.dispatcher.opts and b.dispatcher.opts.workspace == "special:magic"
  end)
  check("special_move bind exists", special_move ~= nil)
  if special_move then
    check("special_move key string is 'SUPER + SHIFT + S'",
      special_move.key == "SUPER + SHIFT + S", special_move.key)
  end

  local move_ws_1 = find_bind("window.move", function(b)
    return b.dispatcher.opts and b.dispatcher.opts.workspace == "1" and b.dispatcher.opts.follow == true
  end)
  check("move-to-workspace-1 bind exists", move_ws_1 ~= nil)
  if move_ws_1 then
    check("move-workspace-1 key string is 'SUPER + SHIFT + 1' (from '+'-separated prefix)",
      move_ws_1.key == "SUPER + SHIFT + 1", move_ws_1.key)
  end

  local terminal_bind = find_bind("exec_cmd", function(b)
    return b.dispatcher.cmd == "kitty"
  end)
  check("single-modifier terminal bind exists", terminal_bind ~= nil)
  if terminal_bind then
    check("single-modifier key string is 'SUPER + T'",
      terminal_bind.key == "SUPER + T", terminal_bind.key)
  end

  local no_mod_bind = find_bind("exec_cmd", function(b)
    return b.dispatcher.cmd and b.dispatcher.cmd:match("wpctl set%-volume %-l 1")
  end)
  check("no-modifier media bind exists", no_mod_bind ~= nil)
  if no_mod_bind then
    check("no-modifier key string has no ' + '",
      no_mod_bind.key == "XF86AudioRaiseVolume", no_mod_bind.key)
  end
end

-- ---- windows.lua ------------------------------------------------------------

_G.THEME = {
  name = "test",
  colors = {
    background = "050505", background_alt = "0B0B0B",
    surface = "101010", surface_alt = "181818",
    foreground = "F4F4F4", foreground_strong = "FFFFFF",
    muted = "9A9A9A", subtle = "555555",
    border_inactive = "383838", border_active = "F0F0F0",
    accent = "FFFFFF",
  },
  geometry = {
    border_size = 1, gaps_in = 8, gaps_out = 16, rounding = 9,
    blur_enabled = true, blur_size = 4, blur_passes = 2,
    shadow_enabled = true, active_opacity = 1.0, inactive_opacity = 0.97,
  },
}

hl_mock.window_rules = {}
local ok2, err2 = pcall(dofile, REPO_ROOT .. "config/hypr/windows.lua")
check("windows.lua loads and runs against the mock", ok2, err2)

if ok2 then
  local pip = nil
  for _, r in ipairs(hl_mock.window_rules) do
    if r.name == "pip-float" then pip = r end
  end
  check("pip-float window rule exists", pip ~= nil)
  if pip then
    check("pip size is native vec2 { 640, 360 }",
      type(pip.size) == "table" and pip.size[1] == 640 and pip.size[2] == 360,
      pip.size and (tostring(pip.size[1]) .. "," .. tostring(pip.size[2])) or tostring(pip.size))
    check("pip move is native vec2 with two components",
      type(pip.move) == "table" and pip.move[1] ~= nil and pip.move[2] == "24",
      pip.move and tostring(pip.move[2]) or tostring(pip.move))
    check("pip match/float/geometry intent unchanged",
      pip.match and pip.match.title == "^(Picture-in-Picture)$" and pip.float == true)
  end
end

if #failures > 0 then
  print(string.format("\n%d check(s) failed", #failures))
  os.exit(1)
end
print("\nall checks passed")
