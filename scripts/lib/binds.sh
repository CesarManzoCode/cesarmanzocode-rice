#!/usr/bin/env bash
# binds.sh — parse/validate the human keybind syntax used by install.sh
# ("SUPER+T", "SUPER+SHIFT+S", "ALT+RETURN") into the {mods,key} form
# stored in user.lua and consumed by config/hypr/binds.lua.
#
# Sourced, not executed.

# parse_bind <spec> -> sets PARSED_MODS / PARSED_KEY, returns 1 if empty.
parse_bind() {
  local spec="$1"
  PARSED_MODS=""
  PARSED_KEY=""
  spec="$(printf '%s' "$spec" | tr -d '[:space:]')"
  [ -z "$spec" ] && return 1

  local parts=()
  IFS='+' read -ra parts <<< "$spec"
  local n="${#parts[@]}"
  [ "$n" -lt 1 ] && return 1

  local key="${parts[$((n - 1))]}"
  [ -z "$key" ] && return 1

  local mods=() i
  for ((i = 0; i < n - 1; i++)); do
    [ -n "${parts[$i]}" ] && mods+=("$(printf '%s' "${parts[$i]}" | tr '[:lower:]' '[:upper:]')")
  done

  PARSED_MODS="${mods[*]}"
  PARSED_KEY="$key"
  return 0
}

# bind_key_of <mods> <key> -> a normalized "MODS|key" string used as a
# dedup/collision key (case-insensitive on the key name).
bind_dedup_key() {
  local m="$1" k="$2"
  printf '%s|%s' "$m" "$(printf '%s' "$k" | tr '[:upper:]' '[:lower:]')"
}

# register_bind <assoc_array_name> <action_label> <spec>
#
# Validates non-empty + no duplicate, printing a Conflict message and
# returning 1 on failure (caller decides whether to re-prompt or abort).
# On success, sets PARSED_MODS/PARSED_KEY and records the binding in the
# named associative array (bash -n keyword avoided; caller passes the
# array by nameref).
register_bind() {
  local -n _seen="$1"
  local action="$2" spec="$3"
  local dk

  if ! parse_bind "$spec"; then
    err "Bind for '$action' is empty or invalid: '$spec'"
    return 1
  fi

  dk="$(bind_dedup_key "$PARSED_MODS" "$PARSED_KEY")"
  if [ -n "${_seen[$dk]:-}" ]; then
    err "Conflict:"
    err "  ${_seen[$dk]} -> ${PARSED_MODS}+${PARSED_KEY}"
    err "  ${action} -> ${PARSED_MODS}+${PARSED_KEY}"
    return 1
  fi

  _seen[$dk]="$action"
  return 0
}
