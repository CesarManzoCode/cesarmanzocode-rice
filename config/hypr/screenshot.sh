#!/usr/bin/env bash
#
# screenshot.sh — full/region screenshot with visual feedback.
#
# Installed by apply.sh into ~/.config/hypr/cesarmanzocode-rice/ (the same
# runtime dir as the Lua modules) and invoked from binds.lua. grim does the
# actual capture; slurp supplies the region geometry for "region" mode.
#
# Saving the file is the one thing that must always work. The notification
# is best-effort feedback only — a missing/broken notify-send must never
# make the screenshot itself "fail", and a cancelled region selection must
# never leave behind a saved file or a false "saved" notification.
#
set -euo pipefail

MODE="${1:-full}"
DIR="$HOME/Pictures/Screenshots"
FILE="$DIR/$(date +%Y-%m-%d_%H-%M-%S).png"

notify() {
  command -v notify-send >/dev/null 2>&1 || return 0
  notify-send "$@" >/dev/null 2>&1 || true
}

save() {
  # save <grim args...> — shared by both modes so the "cancelled" vs.
  # "failed" vs. "saved" outcomes stay consistent.
  mkdir -p "$DIR"
  if grim "$@" "$FILE"; then
    notify "Screenshot saved" "$FILE"
  else
    rm -f "$FILE"
    notify "Screenshot failed" "grim exited with an error"
    exit 1
  fi
}

case "$MODE" in
  full)
    save
    ;;
  region)
    # slurp exits non-zero (Esc / right-click) or prints nothing when the
    # user cancels the selection — either way, stop here silently: no
    # file, no notification, no error. This must run before `set -e` would
    # otherwise abort the script on slurp's non-zero exit.
    GEOM="$(slurp)" || exit 0
    [ -n "$GEOM" ] || exit 0
    save -g "$GEOM"
    ;;
  *)
    echo "Usage: $(basename "$0") full|region" >&2
    exit 2
    ;;
esac
