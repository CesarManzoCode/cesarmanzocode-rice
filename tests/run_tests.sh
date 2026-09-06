#!/usr/bin/env bash
#
# tests/run_tests.sh — lightweight, no-framework verification.
#
# Every "install" here runs against a throwaway $HOME under mktemp, never
# the real one. Safe to run repeatedly and safe to run in CI.
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

PASS=0
FAIL=0

check() {
  local name="$1"; shift
  if "$@" >/tmp/rice-test-out.$$ 2>&1; then
    echo "  ✓ $name"
    PASS=$((PASS + 1))
  else
    echo "  ✗ $name"
    sed 's/^/      /' /tmp/rice-test-out.$$
    FAIL=$((FAIL + 1))
  fi
  rm -f /tmp/rice-test-out.$$
}

echo "== bash -n =="
for f in install.sh apply.sh uninstall.sh scripts/lib/*.sh scripts/dev/*.sh; do
  [ -f "$f" ] || continue
  check "bash -n $f" bash -n "$f"
done

echo "== shellcheck (if available) =="
if command -v shellcheck >/dev/null 2>&1; then
  for f in install.sh apply.sh uninstall.sh scripts/lib/common.sh scripts/lib/binds.sh; do
    check "shellcheck $f" shellcheck -S warning "$f"
  done
else
  echo "  (shellcheck not installed, skipping)"
fi

echo "== lua syntax =="
if command -v lua >/dev/null 2>&1; then
  for f in config/hypr/*.lua themes/*/hypr.lua; do
    check "luac-equivalent parse $f" lua -e "assert(loadfile('$f'))"
  done
else
  echo "  (lua not installed, skipping)"
fi

echo "== no machine-specific hardcoding outside documented examples =="
check_no_hardcode() {
  local pattern="$1"
  ! grep -rn "$pattern" \
      --include="*.lua" --include="*.sh" --include="*.rasi" --include="*.css" \
      --include="*.conf" --include="*.jsonc" --include="*.json" \
      config themes scripts install.sh apply.sh uninstall.sh 2>/dev/null \
    | grep -v "config/hypr/monitors.lua"
}
check "no HDMI-A-1 outside monitors.lua's documented example" check_no_hardcode "HDMI-A-1"
check "no hardcoded /home/<user> path" check_no_hardcode "/home/[a-zA-Z_][a-zA-Z0-9_-]*/"
check "no 1920x1080 used as a functional requirement" check_no_hardcode "1920x1080"

echo "== end-to-end: --dry-run touches nothing =="
DRYHOME="$(mktemp -d)"
check "dry-run --defaults" env HOME="$DRYHOME" XDG_CONFIG_HOME="$DRYHOME/.config" \
  XDG_DATA_HOME="$DRYHOME/.local/share" ./install.sh --defaults --skip-packages --dry-run
check "dry-run created no files" bash -c "[ -z \"\$(find '$DRYHOME' -type f 2>/dev/null)\" ]"
rm -rf "$DRYHOME"

echo "== end-to-end: --defaults full install =="
HOME1="$(mktemp -d)"
check "install --defaults" env HOME="$HOME1" XDG_CONFIG_HOME="$HOME1/.config" \
  XDG_DATA_HOME="$HOME1/.local/share" ./install.sh --defaults --skip-packages
check "hyprland.conf has default terminal bind" \
  grep -q "bind = SUPER,T,exec,kitty" "$HOME1/.config/hypr/hyprland.conf"
check "hyprland.conf has default browser bind" \
  grep -q "bind = SUPER,B,exec,brave" "$HOME1/.config/hypr/hyprland.conf"
check "generic monitor line present" \
  grep -q "^monitor = ,preferred,auto,auto$" "$HOME1/.config/hypr/hyprland.conf"
check "waybar installed" test -f "$HOME1/.config/waybar/config.jsonc"

echo "== autostart: defaults enable every selected component's exec-once =="
check "waybar autostarts"  grep -q "^exec-once = waybar$" "$HOME1/.config/hypr/hyprland.conf"
check "swaync autostarts"  grep -q "^exec-once = swaync$" "$HOME1/.config/hypr/hyprland.conf"
check "hyprpaper autostarts (wallpaper component)" \
  grep -q "^exec-once = hyprpaper$" "$HOME1/.config/hypr/hyprland.conf"
check "hypridle autostarts" grep -q "^exec-once = hypridle$" "$HOME1/.config/hypr/hyprland.conf"
check "polkit agent autostarts" \
  grep -q "^exec-once = /usr/lib/polkit-kde-authentication-agent-1$" "$HOME1/.config/hypr/hyprland.conf"
check "cliphist text watcher autostarts" \
  grep -q "^exec-once = wl-paste --type text --watch cliphist store$" "$HOME1/.config/hypr/hyprland.conf"
check "cliphist image watcher autostarts" \
  grep -q "^exec-once = wl-paste --type image --watch cliphist store$" "$HOME1/.config/hypr/hyprland.conf"

echo "== idempotence: re-apply produces byte-identical output =="
cp "$HOME1/.config/hypr/hyprland.conf" /tmp/rice-first.$$
check "re-run apply.sh" env HOME="$HOME1" XDG_CONFIG_HOME="$HOME1/.config" \
  XDG_DATA_HOME="$HOME1/.local/share" ./apply.sh
check "hyprland.conf unchanged across re-apply" \
  diff -q /tmp/rice-first.$$ "$HOME1/.config/hypr/hyprland.conf"
rm -f /tmp/rice-first.$$

echo "== persistence: hand-edited user.lua survives apply.sh =="
sed -i 's/browser = "brave"/browser = "brave", -- kept/' "$HOME1/.config/cesarmanzocode-rice/user.lua"
check "user.lua still parses" lua -e "assert(loadfile('$HOME1/.config/cesarmanzocode-rice/user.lua'))"
check "re-run apply.sh again" env HOME="$HOME1" XDG_CONFIG_HOME="$HOME1/.config" \
  XDG_DATA_HOME="$HOME1/.local/share" ./apply.sh
check "custom marker survived" grep -q -- "-- kept" "$HOME1/.config/cesarmanzocode-rice/user.lua"
rm -rf "$HOME1"

echo "== component isolation: disabled components are never touched =="
HOME2="$(mktemp -d)"
mkdir -p "$HOME2/.config/cesarmanzocode-rice"
cat > "$HOME2/.config/cesarmanzocode-rice/user.lua" <<'EOF'
return {
  components = { hypr = true, waybar = false, rofi = true, swaync = false,
                 kitty = false, hyprlock = false, hypridle = false, wallpaper = false,
                 polkit = true, cliphist = true },
  apps = { terminal = "kitty", browser = "brave", filemanager = "dolphin", launcher = "rofi -show drun" },
  binds = {},
}
EOF
cat > "$HOME2/.config/cesarmanzocode-rice/state.sh" <<'EOF'
THEME="monochrome"
SELECTED_COMPONENTS="hypr rofi"
EOF
check "apply.sh with waybar/kitty/swaync disabled" env HOME="$HOME2" XDG_CONFIG_HOME="$HOME2/.config" \
  XDG_DATA_HOME="$HOME2/.local/share" ./apply.sh
check "waybar was NOT installed" bash -c "[ ! -e '$HOME2/.config/waybar' ]"
check "kitty was NOT installed" bash -c "[ ! -e '$HOME2/.config/kitty' ]"
check "swaync was NOT installed" bash -c "[ ! -e '$HOME2/.config/swaync' ]"
check "rofi WAS installed" test -f "$HOME2/.config/rofi/config.rasi"
check "waybar exec-once absent (component disabled)" \
  bash -c "! grep -q '^exec-once = waybar\$' '$HOME2/.config/hypr/hyprland.conf'"
check "hyprpaper exec-once absent (wallpaper component disabled)" \
  bash -c "! grep -q '^exec-once = hyprpaper\$' '$HOME2/.config/hypr/hyprland.conf'"
check "hypridle exec-once absent (component disabled)" \
  bash -c "! grep -q '^exec-once = hypridle\$' '$HOME2/.config/hypr/hyprland.conf'"
rm -rf "$HOME2"

echo "== duplicate bind detection =="
check "register_bind rejects a duplicate" bash -c '
  set -euo pipefail
  source "'"$REPO_ROOT"'/scripts/lib/binds.sh"
  err(){ :; }
  declare -A seen=()
  register_bind seen "a" "SUPER+T"
  ! register_bind seen "b" "super+t"
'
check "register_bind rejects an empty bind" bash -c '
  set -euo pipefail
  source "'"$REPO_ROOT"'/scripts/lib/binds.sh"
  err(){ :; }
  declare -A seen=()
  ! register_bind seen "a" ""
'

echo
echo "passed: $PASS  failed: $FAIL"
[ "$FAIL" -eq 0 ]
