#!/usr/bin/env bash
#
# apply.sh — (re)apply the rice from the current state of the repo.
#
# Usage:
#   ./apply.sh                     apply everything from the last install.sh
#   ./apply.sh monochrome          switch theme, keep the same components
#   ./apply.sh monochrome waybar   apply just one component with that theme
#
# Never touches user apps/binds/local overrides — those live outside the
# repo in ~/.config/cesarmanzocode-rice/ and are only written by install.sh.
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$REPO_ROOT/scripts/lib/common.sh"

NO_BACKUP=0
POSITIONAL=()
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --no-backup) NO_BACKUP=1 ;;
    -h|--help)
      cat <<'EOF'
Usage: ./apply.sh [--dry-run] [--no-backup] [theme] [component ...]
EOF
      exit 0 ;;
    *) POSITIONAL+=("$arg") ;;
  esac
done
set -- "${POSITIONAL[@]+"${POSITIONAL[@]}"}"

if [ -f "$STATE_FILE" ]; then
  # shellcheck source=/dev/null
  source "$STATE_FILE"
  # Bring an older on-disk state.sh up to what this checkout expects
  # (e.g. a component added after this install was first set up) before
  # anything below reads SELECTED_COMPONENTS. Skipped for --dry-run's own
  # explicit-args path (no THEME to migrate against yet in that branch).
  migrate_state
elif [ "$#" -lt 2 ]; then
  # No prior install.sh run to read theme/components from, and not enough
  # was given on the command line to fully stand in for it (this is the
  # path install.sh --dry-run takes, passing both explicitly).
  die "No previous install found ($STATE_FILE missing). Run ./install.sh first."
fi

if [ "$#" -ge 1 ]; then
  THEME="$1"
  shift
fi
[ -d "$REPO_ROOT/themes/$THEME" ] || die "Unknown theme: $THEME"

FILTER=("$@")
declare -A WANT=()
for c in ${SELECTED_COMPONENTS:-}; do WANT[$c]=1; done
if [ "${#FILTER[@]}" -gt 0 ]; then
  declare -A ONLY=()
  for c in "${FILTER[@]}"; do ONLY[$c]=1; done
  for c in "${!WANT[@]}"; do
    [ "${ONLY[$c]:-0}" = "1" ] || WANT[$c]=0
  done
fi

info "Applying theme '$THEME'"

STAMP="$(date +%Y%m%d-%H%M%S)-apply"
BACKUP_DIR="$BACKUP_ROOT/$STAMP"

maybe_backup() {
  [ "$NO_BACKUP" = "1" ] && return 0
  backup_path "$1" "$BACKUP_DIR"
}

install_pair() {
  # install_pair <component> <src> <dst>
  local component="$1" src="$2" dst="$3"
  maybe_backup "$dst"
  copy_file "$src" "$dst"
  manifest_add "$component" "$dst"
}

# ---- hypr ------------------------------------------------------------

if [ "${WANT[hypr]:-0}" = "1" ]; then
  info "hypr"

  HYPR_DIR="$XDG_CONFIG_HOME/hypr"
  RUNTIME_DIR="$HYPR_DIR/cesarmanzocode-rice"
  ENTRYPOINT="$HYPR_DIR/hyprland.lua"

  ensure_dir "$HYPR_DIR"
  ensure_dir "$RUNTIME_DIR"

  # Migration: a previous (hyprlang-generator) version of this rice wrote
  # ~/.config/hypr/hyprland.conf, which Hyprland >= 0.55 never reads. Only
  # remove it when the OLD manifest proves this rice wrote it — never a
  # file that merely happens to share the name.
  OLD_CONF="$HYPR_DIR/hyprland.conf"
  OLD_HYPR_MANIFEST="$MANIFEST_DIR/hypr.list"
  if [ -f "$OLD_HYPR_MANIFEST" ] && [ -f "$OLD_CONF" ] && grep -qxF "$OLD_CONF" "$OLD_HYPR_MANIFEST"; then
    info "removing stale hyprland.conf from a previous (hyprlang) version of this rice"
    maybe_backup "$OLD_CONF"
    [ "$DRY_RUN" = "1" ] || rm -f "$OLD_CONF"
  fi

  manifest_reset hypr

  # Back up whatever hyprland.lua exists right now — the user's own config,
  # or a previous run of this rice — before replacing it.
  maybe_backup "$ENTRYPOINT"
  HYPRLAND_LUA_BACKUP=""
  [ "$NO_BACKUP" = "1" ] || HYPRLAND_LUA_BACKUP="$BACKUP_DIR$ENTRYPOINT"

  if [ "$DRY_RUN" = "1" ]; then
    log "[dry-run] install $ENTRYPOINT + $RUNTIME_DIR/*.lua"
  else
    for f in init.lua core.lua input.lua animations.lua windows.lua layers.lua monitors.lua binds.lua autostart.lua; do
      atomic_install_file "$REPO_ROOT/config/hypr/$f" "$RUNTIME_DIR/$f"
      manifest_add hypr "$RUNTIME_DIR/$f"
    done
    atomic_install_file "$REPO_ROOT/config/hypr/screenshot.sh" "$RUNTIME_DIR/screenshot.sh"
    chmod +x "$RUNTIME_DIR/screenshot.sh"
    manifest_add hypr "$RUNTIME_DIR/screenshot.sh"
    atomic_install_file "$REPO_ROOT/themes/$THEME/hypr.lua" "$RUNTIME_DIR/theme.lua"
    manifest_add hypr "$RUNTIME_DIR/theme.lua"
    atomic_install_file "$REPO_ROOT/config/hypr/entrypoint.lua" "$ENTRYPOINT"
    manifest_add hypr "$ENTRYPOINT"
  fi
  ok "hyprland.lua + runtime modules installed"

  # Verify + fail safe — only meaningful with a live Hyprland session.
  if [ "$DRY_RUN" = "0" ] && command -v hyprctl >/dev/null 2>&1 && hyprctl -j monitors >/dev/null 2>&1; then
    hyprctl reload >/dev/null 2>&1 || true
    ERRORS="$(hyprctl configerrors 2>/dev/null || true)"
    if [ -n "$ERRORS" ] && [ "$ERRORS" != "no errors" ] && [ "$ERRORS" != "ok" ]; then
      err "hyprctl configerrors reported problems after reload:"
      printf '%s\n' "$ERRORS" >&2
      if [ -n "$HYPRLAND_LUA_BACKUP" ] && [ -f "$HYPRLAND_LUA_BACKUP" ]; then
        warn "restoring previous hyprland.lua"
        cp -a "$HYPRLAND_LUA_BACKUP" "$ENTRYPOINT"
        hyprctl reload >/dev/null 2>&1 || true
      fi
      die "Aborted: new Hyprland config has errors. Previous config restored where a backup existed."
    fi
    ok "hyprctl configerrors clean"
  fi

  # polkit rides along with hypr (see install.sh); enable its service iff
  # user.lua actually selected it. This runs only after the block above
  # has proven the new config loads clean (or been skipped outright, e.g.
  # no live Hyprland session on a TTY/container) — never as a side effect
  # of an apply that then gets aborted and rolled back.
  if component_enabled polkit; then
    rice_enable_service "hyprpolkitagent.service"
  fi
fi

# ---- wallpaper asset (shared by hyprlock + hyprpaper) ---------------------

WALLPAPER_DST="$XDG_CONFIG_HOME/hypr/wallpapers/${THEME}.png"

ensure_wallpaper_asset() {
  local component="$1"
  install_pair "$component" "$REPO_ROOT/wallpapers/${THEME}.png" "$WALLPAPER_DST"
}

# ---- hyprlock ----------------------------------------------------------

if [ "${WANT[hyprlock]:-0}" = "1" ]; then
  info "hyprlock"
  manifest_reset hyprlock
  ensure_wallpaper_asset hyprlock
  DST="$XDG_CONFIG_HOME/hypr/hyprlock.conf"
  maybe_backup "$DST"
  render_template "$REPO_ROOT/themes/$THEME/hyprlock.conf" "$DST" "@WALLPAPER@" "$WALLPAPER_DST"
  manifest_add hyprlock "$DST"
  ok "hyprlock.conf installed"
fi

# ---- hypridle ------------------------------------------------------------

if [ "${WANT[hypridle]:-0}" = "1" ]; then
  info "hypridle"
  manifest_reset hypridle
  DST="$XDG_CONFIG_HOME/hypr/hypridle.conf"
  install_pair hypridle "$REPO_ROOT/config/hypridle/hypridle.conf.template" "$DST"
  ok "hypridle.conf installed"
  rice_enable_service "hypridle.service"
fi

# ---- wallpaper / hyprpaper ------------------------------------------------

if [ "${WANT[wallpaper]:-0}" = "1" ]; then
  info "wallpaper"
  manifest_reset wallpaper
  ensure_wallpaper_asset wallpaper
  DST="$XDG_CONFIG_HOME/hypr/hyprpaper.conf"
  maybe_backup "$DST"
  render_template "$REPO_ROOT/config/hyprpaper/hyprpaper.conf.template" "$DST" "@WALLPAPER@" "$WALLPAPER_DST"
  manifest_add wallpaper "$DST"
  ok "wallpaper installed"
  rice_enable_service "hyprpaper.service"
fi

# ---- waybar ----------------------------------------------------------

if [ "${WANT[waybar]:-0}" = "1" ]; then
  info "waybar"
  manifest_reset waybar
  # A theme may override STRUCTURE (bar position/orientation/modules), not
  # just colors — themes/$THEME/waybar/config.jsonc|style.css, when
  # present, win over the shared defaults. monochrome ships neither, so it
  # keeps using config/waybar/{config.jsonc,style.css} exactly as before.
  WAYBAR_CONFIG_SRC="$(theme_file_or_shared "$REPO_ROOT/themes/$THEME/waybar/config.jsonc" "$REPO_ROOT/config/waybar/config.jsonc")"
  WAYBAR_STYLE_SRC="$(theme_file_or_shared "$REPO_ROOT/themes/$THEME/waybar/style.css" "$REPO_ROOT/config/waybar/style.css")"
  install_pair waybar "$WAYBAR_CONFIG_SRC" "$XDG_CONFIG_HOME/waybar/config.jsonc"
  install_pair waybar "$WAYBAR_STYLE_SRC" "$XDG_CONFIG_HOME/waybar/style.css"
  install_pair waybar "$REPO_ROOT/themes/$THEME/waybar/colors.css" "$XDG_CONFIG_HOME/waybar/colors.css"
  ok "waybar installed"
  rice_enable_service "waybar.service"
fi

# ---- rofi ------------------------------------------------------------

if [ "${WANT[rofi]:-0}" = "1" ]; then
  info "rofi"
  manifest_reset rofi
  # As with waybar: themes/$THEME/rofi/config.rasi overrides layout/geometry
  # (window anchor/location/width, listview shape, etc.) when present;
  # monochrome has none, so it keeps config/rofi/config.rasi unchanged.
  ROFI_CONFIG_SRC="$(theme_file_or_shared "$REPO_ROOT/themes/$THEME/rofi/config.rasi" "$REPO_ROOT/config/rofi/config.rasi")"
  install_pair rofi "$ROFI_CONFIG_SRC" "$XDG_CONFIG_HOME/rofi/config.rasi"
  install_pair rofi "$REPO_ROOT/themes/$THEME/rofi/colors.rasi" "$XDG_CONFIG_HOME/rofi/colors.rasi"
  install_pair rofi "$REPO_ROOT/config/rofi/power-menu.sh" "$XDG_CONFIG_HOME/rofi/power-menu.sh"
  [ "$DRY_RUN" = "1" ] || chmod +x "$XDG_CONFIG_HOME/rofi/power-menu.sh"
  ok "rofi installed"
fi

# ---- swaync ----------------------------------------------------------

if [ "${WANT[swaync]:-0}" = "1" ]; then
  info "swaync"
  manifest_reset swaync
  # Same override mechanism: themes/$THEME/swaync/{config.json,style.css}
  # win when present (position/margins/width/card geometry can differ per
  # theme, e.g. clearing a left dock vs. a top bar). monochrome has
  # neither, so it keeps config/swaync/{config.json,style.css} unchanged.
  SWAYNC_CONFIG_SRC="$(theme_file_or_shared "$REPO_ROOT/themes/$THEME/swaync/config.json" "$REPO_ROOT/config/swaync/config.json")"
  SWAYNC_STYLE_SRC="$(theme_file_or_shared "$REPO_ROOT/themes/$THEME/swaync/style.css" "$REPO_ROOT/config/swaync/style.css")"
  install_pair swaync "$SWAYNC_CONFIG_SRC" "$XDG_CONFIG_HOME/swaync/config.json"
  install_pair swaync "$SWAYNC_STYLE_SRC" "$XDG_CONFIG_HOME/swaync/style.css"
  install_pair swaync "$REPO_ROOT/themes/$THEME/swaync/colors.css" "$XDG_CONFIG_HOME/swaync/colors.css"
  ok "swaync installed"
  rice_enable_service "swaync.service"
fi

# ---- kitty -----------------------------------------------------------

if [ "${WANT[kitty]:-0}" = "1" ]; then
  info "kitty"
  manifest_reset kitty
  install_pair kitty "$REPO_ROOT/config/kitty/kitty.conf" "$XDG_CONFIG_HOME/kitty/kitty.conf"
  install_pair kitty "$REPO_ROOT/themes/$THEME/kitty/colors.conf" "$XDG_CONFIG_HOME/kitty/colors.conf"
  ok "kitty installed"
fi

# ---- brave (browser-chrome theme; NOT auto-loaded, see README) -----------
#
# A Chromium/Brave theme is a manifest-only, unpacked extension — Brave has
# no CLI/API to load one into a running profile, and this rice deliberately
# never touches ~/.config/BraveSoftware/ (no Preferences edit, no policy,
# no writing into the profile at all). So this only stages the theme files
# at a stable location outside any browser profile; loading it into Brave
# (brave://extensions -> Developer mode -> Load unpacked) stays a one-time
# manual step for the user, documented in the README.

if [ "${WANT[brave]:-0}" = "1" ]; then
  info "brave"
  BRAVE_SRC="$REPO_ROOT/themes/$THEME/brave/manifest.json"
  if [ ! -f "$BRAVE_SRC" ]; then
    warn "theme '$THEME' has no brave/manifest.json — skipping brave theme"
  else
    manifest_reset brave
    BRAVE_DST="$XDG_DATA_HOME/cesarmanzocode-rice/brave/$THEME/manifest.json"
    install_pair brave "$BRAVE_SRC" "$BRAVE_DST"
    ok "brave theme staged at $(dirname "$BRAVE_DST") — load it manually, see README"
  fi
fi

echo
ok "apply.sh finished (theme: $THEME)"
