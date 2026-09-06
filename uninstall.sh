#!/usr/bin/env bash
#
# uninstall.sh — conservatively removes only what this rice installed.
#
# Reads ~/.config/cesarmanzocode-rice/manifest.d/<component>.list — the
# exact set of files apply.sh wrote for each component — and removes just
# those. Nothing that appeared later on its own is touched. Offers to
# restore the most recent backup for each removed file when one exists.
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "$REPO_ROOT/scripts/lib/common.sh"

COMPONENTS=("$@")

usage() {
  cat <<'EOF'
Usage: ./uninstall.sh [component ...]

With no arguments, offers to remove every component this rice has ever
applied (any manifest under ~/.config/cesarmanzocode-rice/manifest.d/).
EOF
}
[ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ] && { usage; exit 0; }

[ -d "$MANIFEST_DIR" ] || die "Nothing to uninstall: $MANIFEST_DIR does not exist."

if [ "${#COMPONENTS[@]}" -eq 0 ]; then
  for f in "$MANIFEST_DIR"/*.list; do
    [ -e "$f" ] || continue
    COMPONENTS+=("$(basename "$f" .list)")
  done
fi
[ "${#COMPONENTS[@]}" -eq 0 ] && die "No installed components found."

info "Components to remove: ${COMPONENTS[*]}"
confirm "Proceed with removal?" "N" || { warn "Aborted."; exit 1; }

RESTORE=0
confirm "Restore the most recent backup for each removed file, where available?" "N" && RESTORE=1

latest_backup_for() {
  local path="$1" candidate best=""
  [ -d "$BACKUP_ROOT" ] || return 0
  for stamp_dir in $(ls -1 "$BACKUP_ROOT" 2>/dev/null | sort -r); do
    candidate="$BACKUP_ROOT/$stamp_dir$path"
    if [ -e "$candidate" ]; then
      best="$candidate"
      break
    fi
  done
  [ -n "$best" ] && printf '%s\n' "$best"
}

for component in "${COMPONENTS[@]}"; do
  list_file="$MANIFEST_DIR/$component.list"
  [ -f "$list_file" ] || { warn "No manifest for '$component', skipping."; continue; }
  info "$component"
  while IFS= read -r path; do
    [ -z "$path" ] && continue
    if [ ! -e "$path" ]; then
      log "already gone: $path"
      continue
    fi
    rm -f "$path"
    log "removed: $path"
    if [ "$RESTORE" = "1" ]; then
      src="$(latest_backup_for "$path" || true)"
      if [ -n "${src:-}" ]; then
        mkdir -p "$(dirname "$path")"
        cp -a "$src" "$path"
        ok "restored from backup: $path"
      fi
    fi
  done < "$list_file"
  rm -f "$list_file"

  # Only disables a systemd --user service THIS rice enabled (see
  # rice_enable_service in scripts/lib/common.sh); anything the user or
  # another tool already had enabled is left exactly as it was.
  case "$component" in
    hypr)      rice_disable_service_if_owned "hyprpolkitagent.service" ;;
    waybar)    rice_disable_service_if_owned "waybar.service" ;;
    swaync)    rice_disable_service_if_owned "swaync.service" ;;
    wallpaper) rice_disable_service_if_owned "hyprpaper.service" ;;
    hypridle)  rice_disable_service_if_owned "hypridle.service" ;;
  esac
done

echo
ok "Uninstall finished. ~/.config/cesarmanzocode-rice/{user,local,state}* were left untouched."
log "Remove them by hand if you want a fully clean slate:"
log "  rm -rf \"$STATE_DIR\""
