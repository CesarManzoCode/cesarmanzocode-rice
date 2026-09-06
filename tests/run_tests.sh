#!/usr/bin/env bash
#
# tests/run_tests.sh — lightweight, no-framework verification.
#
# Every "install" here runs against a throwaway $HOME under mktemp, never
# the real one. Safe to run repeatedly and safe to run in CI. These are
# filesystem/idempotence checks against a fake $HOME — they say nothing
# about a real Hyprland session actually loading the config; that's the
# manual smoke test on the real machine.
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
for f in install.sh apply.sh uninstall.sh scripts/lib/*.sh scripts/dev/*.sh \
         config/hypr/screenshot.sh config/rofi/power-menu.sh; do
  [ -f "$f" ] || continue
  check "bash -n $f" bash -n "$f"
done

echo "== shellcheck (if available) =="
if command -v shellcheck >/dev/null 2>&1; then
  for f in install.sh apply.sh uninstall.sh scripts/lib/common.sh scripts/lib/binds.sh \
           config/hypr/screenshot.sh config/rofi/power-menu.sh; do
    check "shellcheck $f" shellcheck -S warning "$f"
  done
else
  echo "  (shellcheck not installed, skipping)"
fi

echo "== lua syntax (config/hypr/*.lua run standalone by Hyprland's own Lua) =="
if command -v lua >/dev/null 2>&1; then
  for f in config/hypr/*.lua themes/*/hypr.lua; do
    check "luac-equivalent parse $f" lua -e "assert(loadfile('$f'))"
  done
else
  echo "  (lua not installed, skipping — not required at runtime any more)"
fi

echo "== lua runtime shape (mock hl.bind/hl.window_rule catch what loadfile() can't) =="
if command -v lua >/dev/null 2>&1; then
  check "binds.lua/windows.lua produce hl.bind/hl.window_rule shapes Hyprland 0.56 accepts" \
    lua tests/lua/check_binds_and_windows.lua
else
  echo "  (lua not installed, skipping)"
fi

echo "== no machine-specific hardcoding outside documented examples =="
check_no_hardcode() {
  local pattern="$1"
  ! grep -rn "$pattern" \
      --include="*.lua" --include="*.sh" --include="*.rasi" --include="*.css" \
      --include="*.conf" --include="*.jsonc" --include="*.json" --include="*.template" \
      config themes scripts install.sh apply.sh uninstall.sh 2>/dev/null \
    | grep -v "config/hypr/monitors.lua"
}
check "no HDMI-A-1 outside monitors.lua's documented example" check_no_hardcode "HDMI-A-1"
check "no hardcoded /home/<user> path" check_no_hardcode "/home/[a-zA-Z_][a-zA-Z0-9_-]*/"
check "no 1920x1080 used as a functional requirement" check_no_hardcode "1920x1080"

echo "== regression: obsolete/removed APIs must not reappear =="
check_absent() {
  local pattern="$1"
  ! grep -rn "$pattern" \
      --include="*.lua" --include="*.sh" --include="*.rasi" --include="*.css" \
      --include="*.conf" --include="*.jsonc" --include="*.json" --include="*.template" \
      config themes scripts install.sh apply.sh uninstall.sh 2>/dev/null
}
check "no hyprlang text-generator runtime (config/hypr/hl.lua)" \
  bash -c '[ ! -e config/hypr/hl.lua ]'
check "no scripts/generate-hyprland-conf.lua (dead hyprlang generator)" \
  bash -c '[ ! -e scripts/generate-hyprland-conf.lua ]'
check "no dwindle:pseudotile (removed upstream)" \
  bash -c '! grep -RIn "^\s*pseudotile\s*=" config/hypr/*.lua'
check "vfr lives under debug, not misc (moved upstream)" \
  bash -c '
    ! sed -n "/misc = {/,/^  },/p" config/hypr/core.lua | grep -q vfr &&
    sed -n "/debug = {/,/^  },/p" config/hypr/core.lua | grep -q vfr
  '
check "no old hyprctl dispatch dpms on/off form" check_absent "dispatch dpms (on|off)"
check "no old hyprpaper preload=/wallpaper=, syntax" \
  bash -c '! grep -qE "^(preload|wallpaper) *= *,?" config/hyprpaper/hyprpaper.conf.template'
check "no old KDE polkit path" check_absent "polkit-kde-authentication-agent"
check "no general:grace in hyprlock theme" \
  bash -c '! grep -qE "^\s*grace\s*=" themes/monochrome/hyprlock.conf'
check "no old border_size inside hyprlock input-field" \
  bash -c '! grep -qE "^\s*border_size\s*=" themes/monochrome/hyprlock.conf'
check "waybar workspaces module does not use empty icons for numbers" \
  bash -c '! grep -A2 "hyprland/workspaces" config/waybar/config.jsonc | grep -q "format-icons"'
check "waybar workspaces format shows the id" \
  bash -c 'grep -A1 "hyprland/workspaces" config/waybar/config.jsonc | grep -q "{id}"'
check "rofi does not hardcode a Papirus dependency the installer never installs" \
  bash -c '! grep -q "icon-theme:.*Papirus" config/rofi/config.rasi'

echo "== v3: layer blur rules =="
check "init.lua requires layers.lua" bash -c 'grep -q "require(\"layers\")" config/hypr/init.lua'
check "layers.lua loaded after windows.lua, before monitors.lua" bash -c '
  python3 -c "
lines = [l.strip() for l in open(\"config/hypr/init.lua\") if l.strip().startswith(\"require\")]
i_windows = lines.index(\"require(\\\"windows\\\")\")
i_layers = lines.index(\"require(\\\"layers\\\")\")
i_monitors = lines.index(\"require(\\\"monitors\\\")\")
i_autostart = lines.index(\"require(\\\"autostart\\\")\")
assert i_windows < i_layers < i_monitors < i_autostart
"
'
check "layers.lua only references the 3 verified namespaces" bash -c '
  actual=$(grep -oE "\^[a-z-]+\\\$" config/hypr/layers.lua | sort -u)
  expected=$(printf "%s\n" "^rofi\$" "^waybar\$" "^swaync-control-center\$" | sort -u)
  [ "$actual" = "$expected" ]
'
strip_lua_comments() {
  # Drop --[[ ... ]] block comments and full-line "--" comments so prose
  # explaining what NOT to add (this file's own header/footer commentary)
  # doesn't trip a check meant to scan actual code.
  python3 -c "
import re, sys
text = open(sys.argv[1]).read()
text = re.sub(r'--\[\[.*?\]\]', '', text, flags=re.S)
for line in text.splitlines():
    if not line.strip().startswith('--'):
        print(line)
" "$1"
}
check "no dim_around/xray/above_lock/no_screen_share field set in layers.lua" \
  bash -c '! strip_lua_comments config/hypr/layers.lua | grep -qE "dim_around|xray|above_lock|no_screen_share"'
check "no order = field in layers.lua" \
  bash -c '! strip_lua_comments config/hypr/layers.lua | grep -qE "\<order\>\s*="'
check "no invented notification-popup namespace hardcoded as an actual rule" \
  bash -c '! strip_lua_comments config/hypr/layers.lua | grep -q "swaync-notification"'

echo "== v3: kitty translucency stays sane =="
check "kitty keeps tab_bar_style separator (not slim)" \
  grep -q "^tab_bar_style separator$" config/kitty/kitty.conf
check "kitty background_opacity is within 0.80-0.86" bash -c '
  python3 -c "
import re
v = float(re.search(r\"background_opacity ([0-9.]+)\", open(\"config/kitty/kitty.conf\").read()).group(1))
assert 0.80 <= v <= 0.86, v
"
'

echo "== v3: swaync adaptive control center =="
check "swaync fit-to-screen is false" \
  bash -c 'python3 -c "import json; assert json.load(open(\"config/swaync/config.json\"))[\"fit-to-screen\"] is False"'
check "swaync control-center-height is -1 (content-fit)" \
  bash -c 'python3 -c "import json; assert json.load(open(\"config/swaync/config.json\"))[\"control-center-height\"] == -1"'
check "swaync config.json is valid JSON" \
  bash -c 'python3 -c "import json; json.load(open(\"config/swaync/config.json\"))"'

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
check "hyprland.lua entrypoint installed" test -f "$HOME1/.config/hypr/hyprland.lua"
check "hyprland.lua does NOT depend on the repo path" \
  bash -c "! grep -q '$REPO_ROOT' '$HOME1/.config/hypr/hyprland.lua'"
check "runtime modules installed" test -f "$HOME1/.config/hypr/cesarmanzocode-rice/binds.lua"
check "theme.lua installed" test -f "$HOME1/.config/hypr/cesarmanzocode-rice/theme.lua"
check "no hyprland.conf runtime file generated" \
  bash -c "[ ! -e '$HOME1/.config/hypr/hyprland.conf' ]"
check "binds.lua has default terminal bind" \
  grep -q 'hl.dsp.exec_cmd(apps.terminal)' "$HOME1/.config/hypr/cesarmanzocode-rice/binds.lua"
check "user.lua has default terminal app" \
  grep -q 'terminal = "kitty"' "$HOME1/.config/cesarmanzocode-rice/user.lua"
check "user.lua has default browser app" \
  grep -q 'browser = "brave"' "$HOME1/.config/cesarmanzocode-rice/user.lua"
check "generic monitor rule present" \
  grep -q 'hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })' \
  "$HOME1/.config/hypr/cesarmanzocode-rice/monitors.lua"
check "waybar installed" test -f "$HOME1/.config/waybar/config.jsonc"

echo "== autostart: only cliphist is started from Hyprland; the rest are services =="
check "cliphist text watcher in autostart.lua" \
  grep -q "wl-paste --type text --watch cliphist store" "$HOME1/.config/hypr/cesarmanzocode-rice/autostart.lua"
check "cliphist image watcher in autostart.lua" \
  grep -q "wl-paste --type image --watch cliphist store" "$HOME1/.config/hypr/cesarmanzocode-rice/autostart.lua"
check "waybar is NOT exec-once'd from Hyprland" \
  bash -c '! grep -q "hl.exec_cmd(\"waybar\")" "'"$HOME1"'/.config/hypr/cesarmanzocode-rice/autostart.lua"'
check "hyprpaper is NOT exec-once'd from Hyprland" \
  bash -c '! grep -q "hl.exec_cmd(\"hyprpaper\")" "'"$HOME1"'/.config/hypr/cesarmanzocode-rice/autostart.lua"'

echo "== idempotence: re-apply produces byte-identical runtime modules =="
cp "$HOME1/.config/hypr/cesarmanzocode-rice/binds.lua" /tmp/rice-first.$$
check "re-run apply.sh" env HOME="$HOME1" XDG_CONFIG_HOME="$HOME1/.config" \
  XDG_DATA_HOME="$HOME1/.local/share" ./apply.sh
check "binds.lua unchanged across re-apply" \
  diff -q /tmp/rice-first.$$ "$HOME1/.config/hypr/cesarmanzocode-rice/binds.lua"
rm -f /tmp/rice-first.$$

echo "== persistence: hand-edited user.lua survives apply.sh =="
sed -i 's/browser = "brave"/browser = "brave", -- kept/' "$HOME1/.config/cesarmanzocode-rice/user.lua"
check "user.lua still parses" lua -e "assert(loadfile('$HOME1/.config/cesarmanzocode-rice/user.lua'))" \
  || true # lua may be unavailable; not fatal to this check's intent below
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
                 polkit = false, cliphist = true },
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
rm -rf "$HOME2"

echo "== rofi: every element state is explicitly themed, monochrome only =="
ROFI_RASI="config/rofi/config.rasi"
check "no bare 'element selected {' left unqualified (must be selected.normal/.active/.urgent)" \
  bash -c "! grep -qE '^element selected \{' '$ROFI_RASI'"
for state in normal.normal normal.active normal.urgent \
             alternate.normal alternate.active alternate.urgent \
             selected.normal selected.active selected.urgent; do
  check "rofi themes 'element $state'" bash -c "grep -qF 'element $state' '$ROFI_RASI'"
done
check "no color words (blue/red/beige) outside comments in rofi theme files" bash -c '
  python3 -c "
import re, sys
text = \"\"
for f in [\"config/rofi/config.rasi\", \"themes/monochrome/rofi/colors.rasi\"]:
    text += re.sub(r\"/\\*.*?\\*/\", \"\", open(f).read(), flags=re.S)
sys.exit(1 if re.search(r\"blue|beige|crimson|#ff0000|#0000ff\", text, re.I) else 0)
"
'

echo "== waybar: ethernet interface name is tooltip-only, never on the bar =="
check "no {ifname} in a bar-visible waybar format" bash -c '
  ! grep -E "\"format(-wifi|-ethernet|-disconnected|-linked)?\"[^,}]*\{ifname\}" config/waybar/config.jsonc
'
check "{ifname} still available in a network tooltip" \
  grep -q "tooltip-format.*{ifname}" config/waybar/config.jsonc

echo "== screenshot helper: portable, cancel-safe, notification is best-effort =="
SCREENSHOT_SH="config/hypr/screenshot.sh"
check "screenshot.sh has no hardcoded username" bash -c '! grep -qE "/home/[a-zA-Z_][a-zA-Z0-9_-]*/" '"$SCREENSHOT_SH"
check "screenshot.sh saves to \$HOME/Pictures/Screenshots" \
  grep -q 'HOME/Pictures/Screenshots' "$SCREENSHOT_SH"
check "screenshot.sh notification is gated on notify-send being present" \
  grep -q 'command -v notify-send' "$SCREENSHOT_SH"

SCR_BIN="$(mktemp -d)"
SCR_HOME="$(mktemp -d)"
cat > "$SCR_BIN/grim" <<'EOF'
#!/usr/bin/env bash
# Mock grim: last arg is the output path.
for f in "$@"; do :; done
touch "$f"
EOF
cat > "$SCR_BIN/slurp-ok" <<'EOF'
#!/usr/bin/env bash
echo "0,0 100x100"
EOF
cat > "$SCR_BIN/slurp-cancel" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
chmod +x "$SCR_BIN"/grim "$SCR_BIN"/slurp-ok "$SCR_BIN"/slurp-cancel

check "full mode saves exactly one file" bash -c '
  set -e
  rm -f "'"$SCR_HOME"'"/Pictures/Screenshots/*.png 2>/dev/null || true
  PATH="'"$SCR_BIN"':$PATH" HOME="'"$SCR_HOME"'" bash "'"$SCREENSHOT_SH"'" full
  n=$(find "'"$SCR_HOME"'/Pictures/Screenshots" -name "*.png" 2>/dev/null | wc -l)
  [ "$n" -eq 1 ]
'
check "region mode with a real slurp selection saves a file" bash -c '
  rm -rf "'"$SCR_HOME"'/Pictures/Screenshots"
  ln -sf "'"$SCR_BIN"'/slurp-ok" "'"$SCR_BIN"'/slurp"
  PATH="'"$SCR_BIN"':$PATH" HOME="'"$SCR_HOME"'" bash "'"$SCREENSHOT_SH"'" region
  n=$(find "'"$SCR_HOME"'/Pictures/Screenshots" -name "*.png" 2>/dev/null | wc -l)
  [ "$n" -eq 1 ]
'
check "region mode cancelled (slurp fails) creates no file" bash -c '
  rm -rf "'"$SCR_HOME"'/Pictures/Screenshots"
  ln -sf "'"$SCR_BIN"'/slurp-cancel" "'"$SCR_BIN"'/slurp"
  PATH="'"$SCR_BIN"':$PATH" HOME="'"$SCR_HOME"'" bash "'"$SCREENSHOT_SH"'" region
  [ ! -d "'"$SCR_HOME"'/Pictures/Screenshots" ] || \
    [ -z "$(find "'"$SCR_HOME"'/Pictures/Screenshots" -name "*.png" 2>/dev/null)" ]
'
check "full mode succeeds even with no notify-send on PATH" bash -c '
  rm -rf "'"$SCR_HOME"'/Pictures/Screenshots"
  EMPTYBIN=$(mktemp -d)
  PATH="'"$SCR_BIN"':$EMPTYBIN:/usr/bin:/bin" HOME="'"$SCR_HOME"'" bash "'"$SCREENSHOT_SH"'" full
'
rm -rf "$SCR_BIN" "$SCR_HOME"

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
