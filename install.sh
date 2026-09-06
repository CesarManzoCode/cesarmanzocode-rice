#!/usr/bin/env bash
#
# install.sh — interactive (or fully automatic) installer for
# cesarmanzocode-rice.
#
# Every default answer below is the author's own configuration: pressing
# Enter at every prompt reproduces it exactly. `--defaults` skips all
# prompts and does the same thing non-interactively.
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$REPO_ROOT/scripts/lib/common.sh"
# shellcheck source=scripts/lib/binds.sh
source "$REPO_ROOT/scripts/lib/binds.sh"

NONINTERACTIVE=0
SKIP_PACKAGES=0
ADVANCED=0
THEME="monochrome"

usage() {
  cat <<'EOF'
Usage: ./install.sh [options]

  --defaults        Non-interactive install using the author's defaults.
  --advanced        Also prompt for workspace/navigation keybinds.
  --skip-packages   Never call pacman, even on Arch.
  --dry-run         Print what would happen; touch nothing.
  -h, --help        Show this help.
EOF
}

for arg in "$@"; do
  case "$arg" in
    --defaults) NONINTERACTIVE=1 ;;
    --advanced) ADVANCED=1 ;;
    --skip-packages) SKIP_PACKAGES=1 ;;
    --dry-run) DRY_RUN=1 ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown option: $arg (see --help)" ;;
  esac
done

info "cesarmanzocode-rice installer"

# ---- platform ---------------------------------------------------------

ON_ARCH=1
if ! is_arch; then
  ON_ARCH=0
  warn "This doesn't look like Arch Linux."
  warn "Automatic package installation is only supported on Arch."
  warn "Configs can still be installed; pass --skip-packages to silence this."
  SKIP_PACKAGES=1
fi

# ---- theme --------------------------------------------------------------

THEME="$(ask "Theme" "$THEME")"
[ -d "$REPO_ROOT/themes/$THEME" ] || die "Unknown theme: $THEME (see themes/)"

# ---- component selection --------------------------------------------------

declare -A COMPONENTS=(
  [hypr]=1 [waybar]=1 [rofi]=1 [swaync]=1 [kitty]=1 [hyprlock]=1 [hypridle]=1 [wallpaper]=1 [brave]=1
)

ask_component() {
  local key="$1" label="$2"
  if confirm "Install $label?" "Y"; then COMPONENTS[$key]=1; else COMPONENTS[$key]=0; fi
}

ask_component hypr     "Hyprland config"
ask_component waybar   "Waybar"
ask_component rofi     "Rofi"
ask_component swaync   "SwayNC"
ask_component kitty    "Kitty theme"
ask_component hyprlock "Hyprlock"
ask_component hypridle "Hypridle"
ask_component wallpaper "wallpaper"
ask_component brave    "Brave browser-chrome theme (manual load, see README)"

# polkit + cliphist ride along with the core Hyprland shell; not worth a
# separate prompt in the normal flow.
COMPONENT_POLKIT="${COMPONENTS[hypr]}"
COMPONENT_CLIPHIST="${COMPONENTS[hypr]}"

# ---- applications -----------------------------------------------------

echo
info "Applications (type 'none' to disable one)"
APP_TERMINAL="$(ask "Terminal" "kitty")"
APP_BROWSER="$(ask "Browser" "brave")"
APP_FILEMANAGER="$(ask "File manager" "dolphin")"
APP_LAUNCHER="$(ask "Launcher" "rofi -show drun")"

check_app() {
  local val="$1" label="$2"
  [ "$val" = "none" ] && return 0
  local bin="${val%% *}"
  if ! command -v "$bin" >/dev/null 2>&1; then
    warn "$label command '$bin' was not found on PATH. It can be installed later; the keybind will still be written."
  fi
}
check_app "$APP_TERMINAL" "Terminal"
check_app "$APP_BROWSER" "Browser"
check_app "$APP_FILEMANAGER" "File manager"
check_app "$APP_LAUNCHER" "Launcher"

# ---- keybinds -----------------------------------------------------------

echo
info "Keybinds"
# shellcheck disable=SC2034  # read via nameref in register_bind (scripts/lib/binds.sh)
declare -A SEEN_BINDS=()
declare -A BINDS=()

prompt_bind() {
  local action="$1" label="$2" default="$3"
  while true; do
    local spec
    spec="$(ask "$label" "$default")"
    if register_bind SEEN_BINDS "$action" "$spec"; then
      BINDS[$action]="${PARSED_MODS}|${PARSED_KEY}"
      break
    fi
    [ "${NONINTERACTIVE:-0}" = "1" ] && die "Conflicting default binds — this should never happen; please report it."
  done
}

[ "$APP_TERMINAL" != "none" ]    && prompt_bind terminal        "Terminal bind"    "SUPER+T"
prompt_bind close_window         "Close window bind"            "SUPER+X"
[ "$APP_BROWSER" != "none" ]     && prompt_bind browser          "Browser bind"     "SUPER+B"
[ "$APP_FILEMANAGER" != "none" ] && prompt_bind filemanager      "Files bind"       "SUPER+E"
[ "$APP_LAUNCHER" != "none" ]    && prompt_bind launcher         "Launcher bind"    "SUPER+R"
prompt_bind toggle_floating       "Floating bind"                "SUPER+V"
prompt_bind special_toggle        "Special workspace bind"       "SUPER+S"
prompt_bind special_move          "Move to special workspace bind" "SUPER+SHIFT+S"
if [ "$COMPONENT_CLIPHIST" = "1" ]; then
  prompt_bind clipboard            "Clipboard picker bind"        "SUPER+period"
fi

if [ "$ADVANCED" = "0" ]; then
  confirm "Customize advanced keybinds (workspaces/navigation)?" "N" && ADVANCED=1
fi

if [ "$ADVANCED" = "1" ]; then
  prompt_bind focus_left  "Focus left bind"  "SUPER+left"
  prompt_bind focus_right "Focus right bind" "SUPER+right"
  prompt_bind focus_up    "Focus up bind"    "SUPER+up"
  prompt_bind focus_down  "Focus down bind"  "SUPER+down"
  WORKSPACE_PREFIX="$(ask "Workspace switch prefix" "SUPER")"
  MOVE_WORKSPACE_PREFIX="$(ask "Move-to-workspace prefix" "SUPER SHIFT")"
else
  WORKSPACE_PREFIX="SUPER"
  MOVE_WORKSPACE_PREFIX="SUPER SHIFT"
fi

# ---- packages / backup / confirmation --------------------------------

echo
DO_PACKAGES=0
if [ "$ON_ARCH" = "1" ] && [ "$SKIP_PACKAGES" = "0" ]; then
  confirm "Install missing component packages?" "Y" && DO_PACKAGES=1
fi
DO_BACKUP=1
confirm "Backup existing configs?" "Y" || DO_BACKUP=0

echo
info "Summary"
log "theme:      $THEME"
log "components: $(for k in "${!COMPONENTS[@]}"; do [ "${COMPONENTS[$k]}" = "1" ] && printf '%s ' "$k"; done)"
log "apps:       terminal=$APP_TERMINAL browser=$APP_BROWSER filemanager=$APP_FILEMANAGER launcher=$APP_LAUNCHER"
echo

confirm "Proceed?" "Y" || { warn "Aborted, nothing changed."; exit 1; }

# ---- package mapping ------------------------------------------------------

declare -A PKGS_FOR=(
  [waybar]="waybar"
  [rofi]="rofi"
  [swaync]="swaync"
  [hyprlock]="hyprlock"
  [hypridle]="hypridle"
  [wallpaper]="hyprpaper"
  [kitty]="kitty"
)

if [ "$DO_PACKAGES" = "1" ]; then
  info "Installing packages"
  # playerctl/wpctl are used unconditionally by binds.lua whenever the hypr
  # component is on, regardless of whether waybar is installed — don't let
  # them arrive only as an accidental transitive dependency of Waybar.
  PKG_LIST=(xdg-desktop-portal-hyprland xdg-desktop-portal-gtk grim slurp cliphist \
            playerctl wireplumber libnotify \
            ttf-jetbrains-mono-nerd noto-fonts noto-fonts-emoji)
  [ "$COMPONENT_POLKIT" = "1" ] && PKG_LIST+=(hyprpolkitagent)
  for comp in "${!PKGS_FOR[@]}"; do
    [ "${COMPONENTS[$comp]:-0}" = "1" ] && PKG_LIST+=("${PKGS_FOR[$comp]}")
  done
  pkg_install "${PKG_LIST[@]}"
fi

# ---- write persistent user preferences -----------------------------------

ensure_dir "$STATE_DIR"

if [ -f "$USER_LUA" ] && [ "$DO_BACKUP" = "1" ]; then
  STAMP="$(date +%Y%m%d-%H%M%S)-install"
  backup_path "$USER_LUA" "$BACKUP_ROOT/$STAMP"
fi

bindlua() {
  local action="$1"
  [ -n "${BINDS[$action]:-}" ] || return 0
  local mods="${BINDS[$action]%%|*}" key="${BINDS[$action]##*|}"
  printf '    %s = { mods = "%s", key = "%s" },\n' "$action" "$mods" "$key"
}

if [ "$DRY_RUN" = "1" ]; then
  log "[dry-run] would write $USER_LUA"
else
  {
    echo "-- Generated by install.sh on $(date -Iseconds). Hand-editable; see user.lua.example for the schema."
    echo "return {"
    echo "  components = {"
    for k in hypr waybar rofi swaync kitty hyprlock hypridle wallpaper brave; do
      printf '    %s = %s,\n' "$k" "$([ "${COMPONENTS[$k]}" = "1" ] && echo true || echo false)"
    done
    printf '    polkit = %s,\n' "$([ "$COMPONENT_POLKIT" = "1" ] && echo true || echo false)"
    printf '    cliphist = %s,\n' "$([ "$COMPONENT_CLIPHIST" = "1" ] && echo true || echo false)"
    echo "  },"
    echo "  apps = {"
    printf '    terminal = "%s",\n' "$APP_TERMINAL"
    printf '    browser = "%s",\n' "$APP_BROWSER"
    printf '    filemanager = "%s",\n' "$APP_FILEMANAGER"
    printf '    launcher = "%s",\n' "$APP_LAUNCHER"
    echo "  },"
    echo "  binds = {"
    for action in terminal close_window browser filemanager launcher toggle_floating \
                  special_toggle special_move clipboard focus_left focus_right focus_up focus_down; do
      bindlua "$action"
    done
    [ "$ADVANCED" = "1" ] && printf '    workspace_prefix = "%s",\n    move_workspace_prefix = "%s",\n' \
      "$WORKSPACE_PREFIX" "$MOVE_WORKSPACE_PREFIX"
    echo "  },"
    echo "}"
  } > "$USER_LUA"
  ok "wrote $USER_LUA"
fi

# persist the theme/component selection for bare `./apply.sh` re-runs
SELECTED_COMPONENTS=""
for k in hypr waybar rofi swaync kitty hyprlock hypridle wallpaper brave; do
  [ "${COMPONENTS[$k]}" = "1" ] && SELECTED_COMPONENTS="$SELECTED_COMPONENTS $k"
done
if [ "$DRY_RUN" = "1" ]; then
  log "[dry-run] would write $STATE_FILE"
else
  cat > "$STATE_FILE" <<EOF
# Generated by install.sh — read by apply.sh / uninstall.sh
THEME="$THEME"
SELECTED_COMPONENTS="${SELECTED_COMPONENTS# }"
EOF
  ok "wrote $STATE_FILE"
fi

# ---- apply ----------------------------------------------------------------

APPLY_ARGS=("$THEME")
if [ "$DRY_RUN" = "1" ]; then
  # No state.sh was actually written in dry-run mode, so hand apply.sh the
  # component list explicitly instead of letting it read the (nonexistent) file.
  read -ra SELECTED_ARR <<< "$SELECTED_COMPONENTS"
  APPLY_ARGS=("$THEME" "${SELECTED_ARR[@]}")
fi
if [ "$DO_BACKUP" = "0" ]; then APPLY_ARGS=("--no-backup" "${APPLY_ARGS[@]}"); fi
[ "$DRY_RUN" = "1" ] && APPLY_ARGS=("--dry-run" "${APPLY_ARGS[@]}")

info "Applying configuration"
"$REPO_ROOT/apply.sh" "${APPLY_ARGS[@]}"

echo
ok "Done. Log out/in (or reload Hyprland) to pick up all changes."
