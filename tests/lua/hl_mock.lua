--[[
  tests/lua/hl_mock.lua — a strict-enough stand-in for the real hl.* API.

  loadfile() only proves a .lua file is syntactically valid Lua; it never
  calls hl.bind()/hl.window_rule(), so it cannot catch a bind or window
  rule whose *shape* Hyprland's real parser rejects at runtime (that's
  exactly how the "SUPER SHIFT + S" and packed-string vec2 bugs slipped
  through). This mock actually executes config/hypr/*.lua and records what
  gets sent to hl.bind()/hl.window_rule(), validating the parts of the
  shape we've been burned by before.

  This is deliberately NOT a general Hyprland config validator: it does
  not know about every dispatcher or every rule field, and it makes no
  attempt to reimplement hyprlang's real parser. It only asserts the
  narrow properties that caused real, reproduced 0.56.2 parser errors.
]]

local M = {}

M.binds = {}
M.window_rules = {}
M.layer_rules = {}
M.monitors = {}
M.configs = {}
M.animations = {}
M.curves = {}

-- A "MODS + KEY" string, as sent to the real hl.bind(), must have every
-- modifier separated from the next token by its own " + " — a token that
-- itself contains whitespace (e.g. "SUPER SHIFT + S") is exactly the
-- hyprlang-era leftover Hyprland 0.56 rejects ("Unknown keysym: 'SUPER
-- SHIFT', did you forget a +?").
local function validate_keystr(keystr)
  assert(type(keystr) == "string" and keystr ~= "", "hl.bind: key string must be a non-empty string")
  for _, part in ipairs((function()
    local parts = {}
    for p in (keystr .. " + "):gmatch("(.-) %+ ") do
      parts[#parts + 1] = p
    end
    return parts
  end)()) do
    assert(not part:match("%s"), string.format(
      "hl.bind: failed to parse key string: %q — token %q contains whitespace " ..
      "(did you forget a '+' between modifiers?)", keystr, part))
    assert(part ~= "", string.format("hl.bind: empty token in key string %q (stray '+'?)", keystr))
  end
end

function M.bind(keystr, dispatcher, opts)
  validate_keystr(keystr)
  M.binds[#M.binds + 1] = { key = keystr, dispatcher = dispatcher, opts = opts }
end

-- A vec2 field (size, move, ...) is two separate expressions in the native
-- Lua API, never one packed "WxH" / "expr expr" string (that was the
-- hyprlang text-config syntax, and it's exactly what Hyprland 0.56's real
-- parser rejected: "expression vec2 requires two expressions separated by
-- whitespace").
local VEC2_FIELDS = { size = true, move = true }

function M.window_rule(rule)
  assert(type(rule) == "table", "hl.window_rule: rule must be a table")
  for field in pairs(VEC2_FIELDS) do
    local v = rule[field]
    if v ~= nil then
      assert(type(v) == "table" and v[1] ~= nil and v[2] ~= nil and v[3] == nil, string.format(
        "hl.window_rule: field %q must be a two-element vec2 table { x, y }, got %s",
        field, type(v) == "string" and string.format("%q", v) or type(v)))
      assert(type(v[1]) == "string" or type(v[1]) == "number", string.format(
        "hl.window_rule: field %q component 1 must be a string or number", field))
      assert(type(v[2]) == "string" or type(v[2]) == "number", string.format(
        "hl.window_rule: field %q component 2 must be a string or number", field))
    end
  end
  M.window_rules[#M.window_rules + 1] = rule
end

-- hl.layer_rule: match.namespace must be a non-empty string and, when a
-- numeric ignore_alpha is given, it must sit within layer-shell's valid
-- 0..1 alpha-threshold range (the shape this repo actually sends; not a
-- reimplementation of every field Hyprland's real layer-rule accepts).
-- `animation`, when given, must be a non-empty string (Hyprland's own
-- LAYER_RULE_EFFECT_ANIMATION field — a style string like "popin 95%" or
-- "slide right", validated more specifically by check_binds_and_windows.lua
-- against the animation-style grammar itself).
function M.layer_rule(rule)
  assert(type(rule) == "table", "hl.layer_rule: rule must be a table")
  assert(type(rule.match) == "table" and type(rule.match.namespace) == "string"
    and rule.match.namespace ~= "", "hl.layer_rule: match.namespace must be a non-empty string")
  if rule.ignore_alpha ~= nil then
    assert(type(rule.ignore_alpha) == "number" and rule.ignore_alpha >= 0 and rule.ignore_alpha <= 1,
      string.format("hl.layer_rule: ignore_alpha must be a number in [0, 1], got %s",
        tostring(rule.ignore_alpha)))
  end
  if rule.animation ~= nil then
    assert(type(rule.animation) == "string" and rule.animation ~= "",
      "hl.layer_rule: animation must be a non-empty string")
  end
  M.layer_rules[#M.layer_rules + 1] = rule
end

function M.monitor(spec)
  M.monitors[#M.monitors + 1] = spec
end

function M.config(spec)
  M.configs[#M.configs + 1] = spec
end

-- speed must be a positive number (deciseconds) and leaf/bezier|spring must
-- be non-empty strings referencing a real, already-declared curve — the
-- shape animations.lua actually sends, and the part a plain loadfile()
-- syntax check cannot catch (a stray string like speed = "2.0" parses fine
-- as Lua but is exactly the kind of thing that only shows up wrong against
-- the real Hyprland parser). Real Hyprland requires exactly one of
-- bezier/spring — never both, never neither, when enabled.
function M.animation(spec)
  assert(type(spec) == "table", "hl.animation: spec must be a table")
  assert(type(spec.leaf) == "string" and spec.leaf ~= "", "hl.animation: leaf must be a non-empty string")
  if spec.enabled == false then
    -- Mirrors the real hl.animation: a disabled leaf short-circuits before
    -- speed/bezier/spring are required at all.
    M.animations[#M.animations + 1] = spec
    return
  end
  assert(type(spec.speed) == "number" and spec.speed > 0, string.format(
    "hl.animation: leaf %q speed must be a positive number, got %s", spec.leaf, tostring(spec.speed)))
  assert(not (spec.bezier and spec.spring),
    string.format("hl.animation: leaf %q must not set both bezier and spring", spec.leaf))
  if spec.bezier ~= nil then
    assert(type(spec.bezier) == "string" and spec.bezier ~= "",
      string.format("hl.animation: leaf %q bezier must be a non-empty string", spec.leaf))
    assert(M.curves[spec.bezier] and M.curves[spec.bezier].type == "bezier", string.format(
      "hl.animation: leaf %q references unknown bezier %q", spec.leaf, spec.bezier))
  elseif spec.spring ~= nil then
    assert(type(spec.spring) == "string" and spec.spring ~= "",
      string.format("hl.animation: leaf %q spring must be a non-empty string", spec.leaf))
    assert(M.curves[spec.spring] and M.curves[spec.spring].type == "spring", string.format(
      "hl.animation: leaf %q references unknown spring %q", spec.leaf, spec.spring))
  else
    error(string.format("hl.animation: leaf %q requires bezier or spring", spec.leaf))
  end
  if spec.style ~= nil then
    assert(type(spec.style) == "string" and spec.style ~= "",
      string.format("hl.animation: leaf %q style must be a non-empty string", spec.leaf))
  end
  M.animations[#M.animations + 1] = spec
end

-- hl.curve: bezier curves need { points = {...} }; spring curves need
-- numeric mass/stiffness/dampening, each > 0.5 (Hyprland's own real
-- constraint). Confirmed against the EXACT installed build (Hyprland
-- 0.56.2) on real hardware: that build's Lua binding requires
-- `dampening` — passing `damping` fails to load ("dampening expects a
-- number") and cascades into "no such spring" errors. `damping` is
-- accepted here too (so a mock spec written either way still validates),
-- but `dampening` is the key this repo's own animations.lua actually
-- uses, and the one every real spring below must resolve to.
function M.curve(name, spec)
  assert(type(name) == "string" and name ~= "", "hl.curve: name must be a non-empty string")
  assert(type(spec) == "table", "hl.curve: spec must be a table")
  if spec.type == "spring" then
    local damping = spec.damping
    if damping == nil then damping = spec.dampening end
    assert(type(spec.mass) == "number" and spec.mass > 0.5,
      string.format("hl.curve(%q): mass must be a number > 0.5", name))
    assert(type(spec.stiffness) == "number" and spec.stiffness > 0.5,
      string.format("hl.curve(%q): stiffness must be a number > 0.5", name))
    assert(type(damping) == "number" and damping > 0.5,
      string.format("hl.curve(%q): damping (or legacy dampening) must be a number > 0.5", name))
  else
    assert(type(spec.points) == "table", "hl.curve: spec.points must be a table")
  end
  M.curves[name] = spec
end

function M.exec_cmd(cmd)
  return { __dispatcher = "exec_cmd", cmd = cmd }
end

-- hl.dsp.* — dispatcher builders. None of the bugs we're guarding against
-- live here, so these are permissive stand-ins that just record what they
-- were called with.
local function dispatcher(name)
  return function(opts)
    return { __dispatcher = name, opts = opts }
  end
end

M.dsp = {
  exec_cmd = M.exec_cmd,
  focus = dispatcher("focus"),
  window = {
    close = dispatcher("window.close"),
    float = dispatcher("window.float"),
    fullscreen = dispatcher("window.fullscreen"),
    move = dispatcher("window.move"),
    drag = dispatcher("window.drag"),
    resize = dispatcher("window.resize"),
  },
  workspace = {
    toggle_special = dispatcher("workspace.toggle_special"),
  },
}

return M
