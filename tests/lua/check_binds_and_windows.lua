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

  local screenshot_full = find_bind("exec_cmd", function(b)
    return b.dispatcher.cmd and b.dispatcher.cmd:match("screenshot%.sh full$")
  end)
  check("screenshot (full) bind calls screenshot.sh, not raw grim", screenshot_full ~= nil)
  if screenshot_full then
    check("screenshot (full) bind is plain Print, no modifier",
      screenshot_full.key == "Print", screenshot_full.key)
    check("screenshot helper path is not tied to any one $HOME (portable)",
      screenshot_full.dispatcher.cmd:match("^%$HOME/%.config/hypr/") ~= nil,
      screenshot_full.dispatcher.cmd)
  end

  local screenshot_region = find_bind("exec_cmd", function(b)
    return b.dispatcher.cmd and b.dispatcher.cmd:match("screenshot%.sh region$")
  end)
  check("screenshot (region) bind calls screenshot.sh", screenshot_region ~= nil)
  if screenshot_region then
    check("screenshot (region) bind is SUPER + Print",
      screenshot_region.key == "SUPER + Print", screenshot_region.key)
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
    rounding_power = 4,
    blur_enabled = true, blur_size = 6, blur_passes = 2,
    blur_noise = 0.02, blur_contrast = 1.05, blur_brightness = 0.9,
    blur_vibrancy = 0, blur_vibrancy_darkness = 0,
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

  local rounding_power_config = nil
  for _, cfg in ipairs(hl_mock.configs) do
    if cfg.decoration and cfg.decoration.rounding_power then rounding_power_config = cfg end
  end
  check("rounding_power sent via its own guarded hl.config() call",
    rounding_power_config ~= nil and rounding_power_config.decoration.rounding_power == 4)
end

-- ---- animations.lua ---------------------------------------------------------

hl_mock.animations = {}
hl_mock.curves = {}
local ok3, err3 = pcall(dofile, REPO_ROOT .. "config/hypr/animations.lua")
check("animations.lua loads and runs against the mock", ok3, err3)

if ok3 then
  local function find_anim(leaf)
    for _, a in ipairs(hl_mock.animations) do
      if a.leaf == leaf then return a end
    end
    return nil
  end

  local REQUIRED_LEAVES = {
    "windows", "windowsIn", "windowsOut", "windowsMove",
    "layersIn", "layersOut",
    "fade", "fadeIn", "fadeOut", "fadeSwitch",
    "fadeLayersIn", "fadeLayersOut", "fadePopupsIn", "fadePopupsOut", "fadeShadow",
    "workspaces", "specialWorkspace",
    "border", "borderangle",
  }
  for _, leaf in ipairs(REQUIRED_LEAVES) do
    check("animation leaf '" .. leaf .. "' is configured", find_anim(leaf) ~= nil)
  end

  -- Every referenced curve (bezier OR spring) must actually have been
  -- declared via hl.curve() earlier in the same file, with the matching
  -- type — a typo'd curve name is exactly the kind of mistake that parses
  -- fine as Lua but silently falls back to a default curve on the real
  -- Hyprland parser. (hl_mock.animation() already enforces this at call
  -- time; this re-checks the recorded data too, so a future mock change
  -- can't quietly drop the guarantee.)
  local all_curves_declared = true
  for _, a in ipairs(hl_mock.animations) do
    if a.enabled ~= false then
      if a.bezier and not (hl_mock.curves[a.bezier] and hl_mock.curves[a.bezier].type == "bezier") then
        all_curves_declared = false
      end
      if a.spring and not (hl_mock.curves[a.spring] and hl_mock.curves[a.spring].type == "spring") then
        all_curves_declared = false
      end
    end
  end
  check("every enabled animation references a curve declared via hl.curve()", all_curves_declared)

  -- Spring curves: mass/stiffness/dampening all present and > 0 (real
  -- Hyprland requires each > 0.5; hl_mock.curve() already enforces that at
  -- declaration time, this just confirms the springs this rice actually
  -- expects to exist do exist and use the key the EXACT installed build
  -- (0.56.2) actually requires — see hl_mock.lua's own comment on this).
  local EXPECTED_SPRINGS = { "windowSpring", "workspaceSpring", "layerSpring", "specialWorkspaceSpring" }
  for _, name in ipairs(EXPECTED_SPRINGS) do
    local c = hl_mock.curves[name]
    check("spring curve '" .. name .. "' is registered", c ~= nil and c.type == "spring")
    if c then
      check("spring '" .. name .. "' has mass > 0", type(c.mass) == "number" and c.mass > 0)
      check("spring '" .. name .. "' has stiffness > 0", type(c.stiffness) == "number" and c.stiffness > 0)
      check("spring '" .. name .. "' has dampening > 0 (via 'dampening' key)",
        type(c.dampening) == "number" and c.dampening > 0)
    end
  end

  -- The source must spell the key "dampening" (confirmed against the real,
  -- exact installed build — Hyprland 0.56.2 — not upstream source read out
  -- of context; see animations.lua's own header for the failure this
  -- corrects) for every spring it declares, never the "damping" spelling
  -- that this build actually rejects.
  local anim_src = io.open(REPO_ROOT .. "config/hypr/animations.lua", "r")
  local anim_text = anim_src and anim_src:read("*a") or ""
  if anim_src then anim_src:close() end
  check("animations.lua uses the 0.56.2-required 'dampening' key, not 'damping'",
    anim_text:match("dampening%s*=") ~= nil and anim_text:match("[^%a]damping%s*=") == nil)

  -- Speed budget: nothing in this rice's normal interaction animations
  -- should be at/above 300ms (speed 3.0) — everything should feel snappy,
  -- not "showcase". borderangle is exempt: it's disabled outright (see
  -- below) and carries no visible motion either way.
  local all_fast = true
  for _, a in ipairs(hl_mock.animations) do
    if a.leaf ~= "borderangle" and a.enabled ~= false and a.speed >= 3.0 then all_fast = false end
  end
  check("no normal interaction animation reaches 300ms", all_fast)

  local windows_out = find_anim("windowsOut")
  local windows_in = find_anim("windowsIn")
  check("closing a window is faster than opening it",
    windows_out ~= nil and windows_in ~= nil and windows_out.speed < windows_in.speed)

  -- windowsIn must be a small, "materializes a few px out" popin (90-98%),
  -- never a "grows from half its size" pop (see task's explicit ask).
  if windows_in then
    local perc = windows_in.style and tonumber(windows_in.style:match("popin%s+(%d+)%%"))
    check("windowsIn uses a popin between 90% and 98%",
      perc ~= nil and perc >= 90 and perc <= 98, windows_in.style)
  end

  local fade_in, fade_out = find_anim("fadeIn"), find_anim("fadeOut")
  check("fadeOut is never slower than fadeIn",
    fade_in ~= nil and fade_out ~= nil and fade_out.speed <= fade_in.speed)

  local fl_in, fl_out = find_anim("fadeLayersIn"), find_anim("fadeLayersOut")
  check("fadeLayersOut is never slower than fadeLayersIn",
    fl_in ~= nil and fl_out ~= nil and fl_out.speed <= fl_in.speed)

  local fp_in, fp_out = find_anim("fadePopupsIn"), find_anim("fadePopupsOut")
  check("fadePopupsOut is never slower than fadePopupsIn",
    fp_in ~= nil and fp_out ~= nil and fp_out.speed <= fp_in.speed)
  check("fadePopups leaves stay in the ~80-120ms popup range",
    fp_in ~= nil and fp_out ~= nil and fp_in.speed <= 1.2 and fp_out.speed <= 1.2)

  local workspaces = find_anim("workspaces")
  check("workspaces animation uses a short slidefade, not a full-screen slide",
    workspaces ~= nil and workspaces.style ~= nil and workspaces.style:match("^slidefade"),
    workspaces and workspaces.style or "nil")
  if workspaces then
    local perc = tonumber(workspaces.style:match("(%d+)%%"))
    check("workspaces displacement is within 10-20%% of the monitor",
      perc ~= nil and perc >= 10 and perc <= 20, workspaces.style)
  end

  local special = find_anim("specialWorkspace")
  check("specialWorkspace uses a vertical slidefade, distinct from a plain workspace switch",
    special ~= nil and special.style ~= nil and special.style:match("^slidefadevert"),
    special and special.style or "nil")

  -- borderangle: never a looping angle animation (a loop keeps Hyprland
  -- rendering at the monitor's refresh rate for no visual benefit on a
  -- theme with no animated gradient border) — either disabled outright, or
  -- at minimum never given style = "loop".
  local borderangle = find_anim("borderangle")
  check("borderangle is disabled or at least never set to loop",
    borderangle ~= nil and (borderangle.enabled == false or borderangle.style ~= "loop"))

  -- Broader net: no *angle leaf anywhere in this file should ever loop.
  local no_looping_angle = true
  for _, a in ipairs(hl_mock.animations) do
    if a.leaf:match("angle$") and a.style == "loop" then no_looping_angle = false end
  end
  check("no *angle animation leaf is set to loop", no_looping_angle)
end

-- ---- layers.lua ---------------------------------------------------------
-- Verifies the three layer rules use exactly the namespaces measured with
-- `hyprctl layers` on the real target machine, and that none of them
-- reach for fields this pass deliberately left out.

hl_mock.layer_rules = {}
local ok4, err4 = pcall(dofile, REPO_ROOT .. "config/hypr/layers.lua")
check("layers.lua loads and runs against the mock", ok4, err4)

if ok4 then
  local function find_layer(namespace_pattern)
    for _, r in ipairs(hl_mock.layer_rules) do
      if r.match and r.match.namespace == namespace_pattern then return r end
    end
    return nil
  end

  local EXPECTED_NAMESPACES = { "^rofi$", "^waybar$", "^swaync-control-center$" }

  check("layers.lua defines exactly 3 layer rules",
    #hl_mock.layer_rules == 3, tostring(#hl_mock.layer_rules))

  for _, ns in ipairs(EXPECTED_NAMESPACES) do
    local rule = find_layer(ns)
    check("layer rule for namespace " .. ns .. " exists", rule ~= nil)
    if rule then
      check("layer rule " .. ns .. " has blur = true", rule.blur == true)
      check("layer rule " .. ns .. " has ignore_alpha in [0, 1]",
        type(rule.ignore_alpha) == "number" and rule.ignore_alpha >= 0 and rule.ignore_alpha <= 1,
        tostring(rule.ignore_alpha))
    end
  end

  -- Per-namespace animation shape: Rofi is centered (popin, not a slide),
  -- SwayNC's control center docks right (forced right-edge slide), and
  -- Waybar only needs to not be jarring on the rare create/destroy of its
  -- layer surface (a plain top slide).
  local rofi = find_layer("^rofi$")
  check("rofi layer rule uses a popin animation",
    rofi ~= nil and rofi.animation ~= nil and rofi.animation:match("^popin"),
    rofi and rofi.animation or "nil")

  local swaync = find_layer("^swaync-control-center$")
  check("swaync-control-center layer rule slides in from the right",
    swaync ~= nil and swaync.animation == "slide right", swaync and swaync.animation or "nil")

  local waybar = find_layer("^waybar$")
  check("waybar layer rule uses a plain (non-looping) slide, not a continuous effect",
    waybar ~= nil and waybar.animation ~= nil and waybar.animation:match("^slide") and waybar.animation ~= "loop",
    waybar and waybar.animation or "nil")

  -- Only the 3 measured namespaces are used — no invented/guessed one
  -- (e.g. a notification-popup namespace that hasn't actually been
  -- measured yet).
  local only_expected_namespaces = true
  for _, r in ipairs(hl_mock.layer_rules) do
    local matched = false
    for _, ns in ipairs(EXPECTED_NAMESPACES) do
      if r.match and r.match.namespace == ns then matched = true end
    end
    if not matched then only_expected_namespaces = false end
  end
  check("layers.lua uses only the 3 verified namespaces", only_expected_namespaces)

  -- None of these fields serve this pass's goal; their presence would mean
  -- scope crept beyond what was asked.
  local DISALLOWED_FIELDS = { "dim_around", "xray", "above_lock", "no_screen_share", "order" }
  local no_disallowed_fields = true
  for _, r in ipairs(hl_mock.layer_rules) do
    for _, field in ipairs(DISALLOWED_FIELDS) do
      if r[field] ~= nil then no_disallowed_fields = false end
    end
  end
  check("no layer rule sets dim_around/xray/above_lock/no_screen_share/order",
    no_disallowed_fields)
end

if #failures > 0 then
  print(string.format("\n%d check(s) failed", #failures))
  os.exit(1)
end
print("\nall checks passed")
