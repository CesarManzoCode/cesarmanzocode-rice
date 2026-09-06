--[[
  hl.lua — minimal Lua DSL that builds a real Hyprland (hyprlang) config.

  Hyprland itself does not parse Lua. Instead, small modules in this
  directory call into this module to describe the configuration; the
  generator (scripts/generate-hyprland-conf.lua) then dumps the result as
  plain hyprlang text (`~/.config/hypr/hyprland.conf`).

  Lua's `require` caches modules, so every file that does
  `local hl = require("hl")` gets the SAME table/state — that's how the
  various modules (core, input, windows, binds, ...) accumulate into one
  buffer without any global variables.
]]

local M = {}
local out = {}

local function line(s)
  table.insert(out, s)
end

-- Emit a raw hyprlang line verbatim.
function M.raw(s)
  line(s)
end

local function fmt_value(v)
  if type(v) == "boolean" then
    return v and "true" or "false"
  end
  return tostring(v)
end

-- Emit `path = value` (dotted paths like "general:gaps_in" are how hyprlang
-- flattens categories, and are equivalent to nested blocks).
function M.set(path, value)
  line(string.format("%s = %s", path, fmt_value(value)))
end

-- Emit `prefix:key = value` for every key/value pair in tbl.
-- Keys are sorted so output is deterministic across Lua versions/runs.
function M.set_all(prefix, tbl)
  local keys = {}
  for k in pairs(tbl) do table.insert(keys, k) end
  table.sort(keys)
  for _, k in ipairs(keys) do
    M.set(prefix .. ":" .. k, tbl[k])
  end
end

-- monitor = name,resolution,position,scale
-- Passing an empty/omitted output matches every monitor generically.
function M.monitor(t)
  t = t or {}
  M.raw(string.format(
    "monitor = %s,%s,%s,%s",
    t.output or "",
    t.mode or "preferred",
    t.position or "auto",
    t.scale or "auto"
  ))
end

function M.exec_once(cmd)
  M.raw("exec-once = " .. cmd)
end

function M.env(key, value)
  M.raw(string.format("env = %s,%s", key, value))
end

-- kind defaults to "bind"; pass "bindm" (mouse), "bindl" (allowed while
-- locked), "bindel" (repeat + locked), etc. as needed.
function M.bind(mods, key, dispatcher, args, kind)
  kind = kind or "bind"
  local extra = ""
  if args ~= nil and args ~= "" then
    extra = "," .. args
  end
  M.raw(string.format("%s = %s,%s,%s%s", kind, mods, key, dispatcher, extra))
end

function M.bezier(name, x0, y0, x1, y1)
  M.raw(string.format("bezier = %s,%s,%s,%s,%s", name, x0, y0, x1, y1))
end

function M.animation(name, enabled, speed, curve, style)
  local extra = style and ("," .. style) or ""
  M.raw(string.format(
    "animation = %s,%s,%s,%s%s",
    name, enabled and 1 or 0, speed, curve, extra
  ))
end

function M.windowrule(rule, match)
  M.raw(string.format("windowrulev2 = %s,%s", rule, match))
end

function M.workspace(spec)
  M.raw("workspace = " .. spec)
end

function M.blank()
  line("")
end

function M.comment(s)
  line("# " .. s)
end

function M.dump()
  return table.concat(out, "\n") .. "\n"
end

return M
