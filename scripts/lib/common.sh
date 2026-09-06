#!/usr/bin/env bash
# common.sh — shared helpers for install.sh / apply.sh / uninstall.sh.
# Sourced, not executed. Assumes `set -euo pipefail` in the caller.

# ---- paths ---------------------------------------------------------------

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"

# shellcheck disable=SC2034  # consumed by install.sh / apply.sh / uninstall.sh, not this file
STATE_DIR="$XDG_CONFIG_HOME/cesarmanzocode-rice"
# shellcheck disable=SC2034
STATE_FILE="$STATE_DIR/state.sh"
# shellcheck disable=SC2034
USER_LUA="$STATE_DIR/user.lua"
# shellcheck disable=SC2034
LOCAL_LUA="$STATE_DIR/local.lua"
MANIFEST_DIR="$STATE_DIR/manifest.d"
# shellcheck disable=SC2034
BACKUP_ROOT="$XDG_DATA_HOME/cesarmanzocode-rice/backups"

DRY_RUN="${DRY_RUN:-0}"

# ---- logging ---------------------------------------------------------------

_c_reset=""; _c_bold=""; _c_dim=""; _c_red=""; _c_green=""; _c_yellow=""
if [ -t 1 ]; then
  _c_reset="\033[0m"; _c_bold="\033[1m"; _c_dim="\033[2m"
  _c_red="\033[31m"; _c_green="\033[32m"; _c_yellow="\033[33m"
fi

log()   { printf "%b\n" "  $*${_c_reset}"; }
info()  { printf "%b\n" "${_c_bold}==>${_c_reset} $*"; }
ok()    { printf "%b\n" "${_c_green}  ✓${_c_reset} $*"; }
warn()  { printf "%b\n" "${_c_yellow}  ! $*${_c_reset}" >&2; }
err()   { printf "%b\n" "${_c_red}  ✗ $*${_c_reset}" >&2; }
die()   { err "$*"; exit 1; }

# ---- prompts ---------------------------------------------------------------

# ask "Question" "default" -> echoes answer (default if empty/non-interactive)
ask() {
  local prompt="$1" default="$2" reply
  if [ "${NONINTERACTIVE:-0}" = "1" ]; then
    printf "%s\n" "$default"
    return 0
  fi
  if ! read -r -p "$(printf '%b' "${_c_bold}${prompt} [${default}]:${_c_reset} ")" reply; then
    die "Unexpected end of input while waiting for an answer to: $prompt"
  fi
  if [ -z "$reply" ]; then
    printf "%s\n" "$default"
  else
    printf "%s\n" "$reply"
  fi
}

# confirm "Question" "Y"|"N" -> returns 0 for yes, 1 for no
confirm() {
  local prompt="$1" default="${2:-Y}" hint reply
  if [ "$default" = "Y" ]; then hint="Y/n"; else hint="y/N"; fi
  if [ "${NONINTERACTIVE:-0}" = "1" ]; then
    [ "$default" = "Y" ] && return 0 || return 1
  fi
  if ! read -r -p "$(printf '%b' "${_c_bold}${prompt} [${hint}]:${_c_reset} ")" reply; then
    die "Unexpected end of input while waiting for an answer to: $prompt"
  fi
  reply="${reply:-$default}"
  case "$reply" in
    y|Y|yes|YES) return 0 ;;
    n|N|no|NO) return 1 ;;
    *) [ "$default" = "Y" ] && return 0 || return 1 ;;
  esac
}

# ---- system detection -------------------------------------------------------

is_arch() {
  [ -f /etc/os-release ] || return 1
  # shellcheck disable=SC1091
  . /etc/os-release
  case "${ID:-}:${ID_LIKE:-}" in
    arch:*|*:*arch*) return 0 ;;
  esac
  return 1
}

# ---- filesystem helpers -----------------------------------------------------

ensure_dir() {
  local d="$1"
  if [ "$DRY_RUN" = "1" ]; then
    log "[dry-run] mkdir -p $d"
  else
    mkdir -p "$d"
  fi
}

# backup_path <path> <backup_stamp_dir> — copies an existing file/dir into
# the backup location, preserving its original absolute path under it, so
# it can be restored later. No-op if the path doesn't exist.
backup_path() {
  local path="$1" stamp_dir="$2" dest
  [ -e "$path" ] || return 0
  dest="$stamp_dir$path"
  if [ "$DRY_RUN" = "1" ]; then
    log "[dry-run] backup $path -> $dest"
    return 0
  fi
  mkdir -p "$(dirname "$dest")"
  cp -a "$path" "$dest"
}

# copy_file <src> <dst> — plain copy (not a symlink): deterministic,
# survives the repo moving/disappearing, easy to reason about.
copy_file() {
  local src="$1" dst="$2"
  if [ "$DRY_RUN" = "1" ]; then
    log "[dry-run] install $src -> $dst"
    return 0
  fi
  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
}

# atomic_install_file <src> <dst> — write-to-temp + rename, so a reader
# (Hyprland reloading its config mid-write, e.g.) never sees a partial
# file. Used for the Hyprland Lua runtime, where a torn write would be a
# broken session, not just a cosmetic glitch.
atomic_install_file() {
  local src="$1" dst="$2" tmp
  if [ "$DRY_RUN" = "1" ]; then
    log "[dry-run] install $src -> $dst (atomic)"
    return 0
  fi
  mkdir -p "$(dirname "$dst")"
  tmp="$(mktemp "$(dirname "$dst")/.$(basename "$dst").XXXXXX")"
  cp "$src" "$tmp"
  mv -f "$tmp" "$dst"
}

# theme_file_or_shared <theme_specific> <shared_fallback> — echoes whichever
# exists, preferring the theme-specific one. Lets a theme override the
# STRUCTURE of a component (Waybar's config.jsonc, Rofi's config.rasi,
# SwayNC's config.json/style.css — position, layout, geometry), not just
# its colors, without forcing every theme to ship one. A theme that omits
# the file (monochrome does, for all of these, on purpose — it's closed)
# falls back to the shared file exactly as before this mechanism existed.
theme_file_or_shared() {
  local theme_specific="$1" shared="$2"
  if [ -f "$theme_specific" ]; then
    printf "%s\n" "$theme_specific"
  else
    printf "%s\n" "$shared"
  fi
}

# render_template <src> <dst> <FIND> <REPLACE> — copy with one literal
# placeholder substituted (used for @WALLPAPER@ etc).
render_template() {
  local src="$1" dst="$2" find="$3" replace="$4"
  if [ "$DRY_RUN" = "1" ]; then
    log "[dry-run] render $src -> $dst (${find} -> ${replace})"
    return 0
  fi
  mkdir -p "$(dirname "$dst")"
  sed "s|${find}|${replace}|g" "$src" > "$dst"
}

# manifest_reset <component> — start a fresh file list for a component.
manifest_reset() {
  local component="$1"
  ensure_dir "$MANIFEST_DIR"
  [ "$DRY_RUN" = "1" ] && return 0
  : > "$MANIFEST_DIR/$component.list"
}

# manifest_add <component> <path> — record a path as owned by this rice.
manifest_add() {
  local component="$1" path="$2"
  [ "$DRY_RUN" = "1" ] && return 0
  ensure_dir "$MANIFEST_DIR"
  printf "%s\n" "$path" >> "$MANIFEST_DIR/$component.list"
}

# ---- package management -----------------------------------------------------

pkg_install() {
  local pkgs=("$@")
  [ "${#pkgs[@]}" -eq 0 ] && return 0
  if [ "$DRY_RUN" = "1" ]; then
    log "[dry-run] sudo pacman -S --needed ${pkgs[*]}"
    return 0
  fi
  if [ "${NONINTERACTIVE:-0}" = "1" ]; then
    sudo pacman -S --needed --noconfirm "${pkgs[@]}"
  else
    sudo pacman -S --needed "${pkgs[@]}"
  fi
}

# ---- UWSM / systemd --user service lifecycle --------------------------
#
# One source of truth per daemon: a package-provided systemd --user unit,
# enabled once and left alone by every later re-apply. Hyprland's own
# config never exec-once's any of these (see config/hypr/autostart.lua) —
# running both would spawn a duplicate instance on every login.

# shellcheck disable=SC2034  # consumed by apply.sh/uninstall.sh, not this file
RICE_SERVICES_FILE="$MANIFEST_DIR/services-enabled-by-rice.list"

service_unit_exists() {
  local unit="$1"
  command -v systemctl >/dev/null 2>&1 || return 1
  systemctl --user list-unit-files "$unit" --no-legend 2>/dev/null | grep -q .
}

# rice_enable_service <unit> — idempotent. Enables+starts the unit only if
# it isn't already enabled (never touches one the user or another tool
# already turned on), and records only what THIS call newly enabled, so
# uninstall can revert exactly that and nothing else. If the unit is
# already enabled, just restarts it to pick up a fresh config.
rice_enable_service() {
  local unit="$1"
  if ! service_unit_exists "$unit"; then
    warn "$unit not found (package not installed?) — skipping autostart for it"
    return 0
  fi
  if systemctl --user is-enabled --quiet "$unit" 2>/dev/null; then
    rice_restart_service "$unit"
    return 0
  fi
  if [ "$DRY_RUN" = "1" ]; then
    log "[dry-run] systemctl --user enable --now $unit"
    return 0
  fi
  ensure_dir "$MANIFEST_DIR"
  if systemctl --user enable --now "$unit" >/dev/null 2>&1; then
    printf "%s\n" "$unit" >> "$RICE_SERVICES_FILE"
    ok "enabled $unit"
  else
    warn "could not enable $unit"
  fi
}

# rice_restart_service <unit> — best-effort reload of an already-running,
# already-enabled unit. No-op if it isn't active (a fresh session will
# start it via graphical-session.target on its own).
rice_restart_service() {
  local unit="$1"
  [ "$DRY_RUN" = "1" ] && return 0
  service_unit_exists "$unit" || return 0
  systemctl --user is-active --quiet "$unit" 2>/dev/null || return 0
  systemctl --user reload-or-restart "$unit" >/dev/null 2>&1 || true
}

# rice_disable_service_if_owned <unit> — only disables a service THIS rice
# enabled (per RICE_SERVICES_FILE); a service that was already enabled
# before install.sh ran is left exactly as it was.
rice_disable_service_if_owned() {
  local unit="$1"
  [ -f "$RICE_SERVICES_FILE" ] || return 0
  grep -qxF "$unit" "$RICE_SERVICES_FILE" || return 0
  systemctl --user disable --now "$unit" >/dev/null 2>&1 || true
  grep -vxF "$unit" "$RICE_SERVICES_FILE" > "$RICE_SERVICES_FILE.tmp" 2>/dev/null || true
  mv -f "$RICE_SERVICES_FILE.tmp" "$RICE_SERVICES_FILE" 2>/dev/null || true
}

# ---- state schema migrations ------------------------------------------
#
# STATE_FILE (~/.config/cesarmanzocode-rice/state.sh) persists THEME and
# SELECTED_COMPONENTS across bare `./apply.sh` re-runs. Without a version on
# that file, a component added by a later version of this rice (e.g.
# `brave`, added after some users had already run install.sh) would just be
# silently absent from an old SELECTED_COMPONENTS forever — `git pull &&
# ./apply.sh` never applies it, and the fix has to be done by hand.
#
# STATE_SCHEMA_VERSION_CURRENT is the version this checkout expects.
# migrate_state() brings an older on-disk state.sh up to it via small,
# explicit, one-time steps — never by turning every new component on
# unconditionally (a user who explicitly disabled something keeps it
# disabled forever; this only ever fills in a component that's simply
# *absent* from a pre-migration file, i.e. one it never had an opinion on).
# shellcheck disable=SC2034  # consumed by install.sh, not this file
STATE_SCHEMA_VERSION_CURRENT=2

# migrate_state — call once, right after sourcing STATE_FILE (so THEME,
# SELECTED_COMPONENTS and possibly-empty STATE_SCHEMA_VERSION are set) and
# before anything reads SELECTED_COMPONENTS to decide what to apply.
# Mutates SELECTED_COMPONENTS/STATE_SCHEMA_VERSION in the calling shell and,
# if anything actually changed, rewrites STATE_FILE so the migration runs
# exactly once — this run and every future bare `apply.sh` both see it.
migrate_state() {
  local v="${STATE_SCHEMA_VERSION:-1}" changed=0

  if [ "$v" -lt 2 ]; then
    # v1 -> v2: the `brave` component didn't exist when v1 state files were
    # written. Rule: bring the install up to what a brand-new install.sh
    # run would pick by default for it (brave defaults to enabled — see
    # install.sh's `ask_component brave ...`) — but only when the file has
    # no opinion on `brave` at all (i.e. it predates the component and
    # simply doesn't list it). A file that already lists brave, on or off,
    # is an explicit user choice and is never touched.
    case " ${SELECTED_COMPONENTS:-} " in
      *" brave "*) ;; # explicit already (on or off) — nothing to migrate
      *)
        SELECTED_COMPONENTS="${SELECTED_COMPONENTS:-}${SELECTED_COMPONENTS:+ }brave"
        info "state schema v1 -> v2: enabling the new 'brave' component (matches install.sh's own default for a fresh install)"
        log "  edit ~/.config/cesarmanzocode-rice/state.sh (SELECTED_COMPONENTS) to turn it back off"
        changed=1
        ;;
    esac
    v=2
  fi

  if [ "$changed" = "1" ] || [ "$v" != "${STATE_SCHEMA_VERSION:-}" ]; then
    STATE_SCHEMA_VERSION="$v"
    if [ "$DRY_RUN" != "1" ]; then
      cat > "$STATE_FILE" <<EOF
# Generated by install.sh / migrated by apply.sh — read by apply.sh / uninstall.sh
THEME="$THEME"
SELECTED_COMPONENTS="${SELECTED_COMPONENTS# }"
STATE_SCHEMA_VERSION="$STATE_SCHEMA_VERSION"
EOF
    fi
  fi
}

# component_enabled <name> — best-effort check of a boolean flag inside
# USER_LUA (e.g. `polkit = true,`), for components that ride along with
# `hypr` instead of having their own apply.sh --component flag.
component_enabled() {
  local name="$1"
  [ -f "$USER_LUA" ] || return 1
  grep -qE "^[[:space:]]*${name}[[:space:]]*=[[:space:]]*true[[:space:]]*,?[[:space:]]*\$" "$USER_LUA"
}
