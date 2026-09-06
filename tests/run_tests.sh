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

echo "== final polish: swaync empty-state icon actually targets the real node =="
check "swaync style.css targets the real placeholder selector (verified against 0.12.6 source)" \
  grep -q '\.control-center-list-placeholder image' config/swaync/style.css
check "old, structurally-inert '.control-center > box > image' selector is gone (mentioned only in prose, never used live)" \
  bash -c '! grep -qE "^\.control-center > box > image \{" config/swaync/style.css'
check "placeholder icon is shrunk via a CSS transform (pixel-size wins over -gtk-icon-size)" \
  bash -c 'sed -n "/\.control-center-list-placeholder image/,/}/p" config/swaync/style.css | grep -q "transform: scale"'

echo "== v3: swaync adaptive control center =="
check "swaync fit-to-screen is false" \
  bash -c 'python3 -c "import json; assert json.load(open(\"config/swaync/config.json\"))[\"fit-to-screen\"] is False"'
check "swaync control-center-height is -1 (content-fit)" \
  bash -c 'python3 -c "import json; assert json.load(open(\"config/swaync/config.json\"))[\"control-center-height\"] == -1"'
check "swaync config.json is valid JSON" \
  bash -c 'python3 -c "import json; json.load(open(\"config/swaync/config.json\"))"'

echo "== final wallpaper pack: 4 variants + canonical default + determinism =="
if command -v python3 >/dev/null 2>&1; then
  check "wallpaper pack invariants (resolution/grayscale/canonical/determinism)" \
    python3 tests/check_wallpapers.py
else
  echo "  (python3 not installed, skipping)"
fi

echo "== theme registry: every theme under themes/ satisfies the common contract =="
if command -v python3 >/dev/null 2>&1; then
  check "per-theme invariants (geometry/colors/components/wallpapers, discovered from themes/)" \
    python3 tests/check_all_themes.py
else
  echo "  (python3 not installed, skipping)"
fi

echo "== v3: brave theme (manifest-only extension, no code) =="
BRAVE_MANIFEST="themes/monochrome/brave/manifest.json"
check "brave manifest.json is valid JSON" \
  bash -c "python3 -c \"import json; json.load(open('$BRAVE_MANIFEST'))\""
check "brave manifest_version == 3" \
  bash -c "python3 -c \"
import json
d = json.load(open('$BRAVE_MANIFEST'))
assert d['manifest_version'] == 3
\""
check "brave manifest has a 'theme' key with 'colors'" \
  bash -c "python3 -c \"
import json
d = json.load(open('$BRAVE_MANIFEST'))
assert 'theme' in d and 'colors' in d['theme'] and len(d['theme']['colors']) > 0
\""
check "brave manifest has no permissions/host_permissions/content_scripts/background" \
  bash -c "python3 -c \"
import json
d = json.load(open('$BRAVE_MANIFEST'))
for forbidden in ('permissions', 'host_permissions', 'content_scripts', 'background'):
    assert forbidden not in d, forbidden
\""
check "brave manifest only uses documented, current Chromium theme.colors keys" \
  bash -c "python3 -c \"
import json
d = json.load(open('$BRAVE_MANIFEST'))
# Verified against chrome/browser/themes/browser_theme_pack.cc's
# kOverwritableColorTable on the Chromium main branch — see layers.lua-style
# commit message for the source. Not a guess, not copied for volume.
allowed = {
    'background_tab', 'background_tab_inactive',
    'background_tab_incognito', 'background_tab_incognito_inactive',
    'bookmark_text', 'button_background',
    'frame', 'frame_inactive', 'frame_incognito', 'frame_incognito_inactive',
    'ntp_background', 'ntp_header', 'ntp_link', 'ntp_text',
    'omnibox_background', 'omnibox_text',
    'tab_background_text', 'tab_background_text_inactive',
    'tab_background_text_incognito', 'tab_background_text_incognito_inactive',
    'tab_text', 'toolbar', 'toolbar_button_icon', 'toolbar_text',
}
used = set(d['theme']['colors'].keys())
assert used <= allowed, used - allowed
\""
check "every brave theme color is a 3-element [0-255] RGB array" \
  bash -c "python3 -c \"
import json
d = json.load(open('$BRAVE_MANIFEST'))
for name, rgb in d['theme']['colors'].items():
    assert isinstance(rgb, list) and len(rgb) == 3, name
    for c in rgb:
        assert isinstance(c, int) and 0 <= c <= 255, (name, c)
\""
check "no color outside the monochrome identity (no orange/blue/beige/purple hue)" \
  bash -c "python3 -c \"
import json, colorsys
d = json.load(open('$BRAVE_MANIFEST'))
for name, rgb in d['theme']['colors'].items():
    r, g, b = (c / 255 for c in rgb)
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    # Pure grays (s == 0) are always fine; this theme is monochrome, so any
    # saturated color at all is the regression this guards against — not
    # just orange/blue/beige/purple specifically.
    assert s < 0.05, (name, rgb, 'saturation', s)
\""
check "no JS in the brave theme (theme-only extension, no code)" \
  bash -c '! find themes/monochrome/brave -name "*.js" | grep -q .'
check "brave theme has no icons/background/content-script directories" \
  bash -c '! find themes/monochrome/brave -mindepth 1 -type d | grep -q .'

check "apply.sh stages the brave theme under XDG_DATA_HOME, not the Brave profile" \
  grep -q 'XDG_DATA_HOME/cesarmanzocode-rice/brave' apply.sh
check "apply.sh never writes into BraveSoftware/Brave-Browser" \
  bash -c '
    # Drop full-line "#" comments (this codebases own explanatory prose,
    # which legitimately names BraveSoftware to say it is never touched)
    # before scanning for the string as actual code.
    for f in apply.sh install.sh uninstall.sh scripts/lib/*.sh; do
      grep -vE "^\s*#" "$f" | grep -q "BraveSoftware" && exit 1
    done
    exit 0
  '
check "no code path touches Brave profile files (Preferences/Local State/Cookies/History/...)" \
  bash -c '! grep -rEn "BraveSoftware/Brave-Browser/(Preferences|Local State|Bookmarks|Cookies|History|Sessions|Passwords|Extensions)\b" \
      --include="*.sh" apply.sh install.sh uninstall.sh scripts'

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
check "layers.lua installed (init.lua's require(\"layers\") must resolve)" \
  test -f "$HOME1/.config/hypr/cesarmanzocode-rice/layers.lua"
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
check "brave theme staged under XDG_DATA_HOME (portable, not repo path)" \
  test -f "$HOME1/.local/share/cesarmanzocode-rice/brave/monochrome/manifest.json"
check "staged brave manifest matches the repo source" \
  diff -q "$REPO_ROOT/themes/monochrome/brave/manifest.json" \
    "$HOME1/.local/share/cesarmanzocode-rice/brave/monochrome/manifest.json"
check "brave theme was NOT installed into the Brave profile" \
  bash -c "[ ! -e '$HOME1/.config/BraveSoftware' ]"

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

echo "== v3: uninstall removes only the brave theme files it manages =="
BRAVE_STAGED="$HOME1/.local/share/cesarmanzocode-rice/brave/monochrome/manifest.json"
UNRELATED_MARKER="$HOME1/.local/share/cesarmanzocode-rice/brave/monochrome/user-added-file.txt"
echo "not managed by this rice" > "$UNRELATED_MARKER"
check "brave theme present before uninstall" test -f "$BRAVE_STAGED"
check "uninstall brave component" env HOME="$HOME1" XDG_CONFIG_HOME="$HOME1/.config" \
  XDG_DATA_HOME="$HOME1/.local/share" bash -c '
    printf "y\nn\n" | ./uninstall.sh brave
  '
check "manifest-tracked brave theme file removed" bash -c "[ ! -e '$BRAVE_STAGED' ]"
check "uninstall left an unrelated file in the same directory alone" test -f "$UNRELATED_MARKER"
check "uninstall did not touch a Brave profile (none exists here, and none was created)" \
  bash -c "[ ! -e '$HOME1/.config/BraveSoftware' ]"

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

echo "== state migration: a pre-brave install picks up brave on the next apply =="
HOME3="$(mktemp -d)"
mkdir -p "$HOME3/.config/cesarmanzocode-rice"
cat > "$HOME3/.config/cesarmanzocode-rice/user.lua" <<'EOF'
return {
  components = { hypr = true, waybar = false, rofi = false, swaync = false,
                 kitty = false, hyprlock = false, hypridle = false, wallpaper = false },
  apps = { terminal = "kitty", browser = "brave", filemanager = "dolphin", launcher = "rofi -show drun" },
  binds = {},
}
EOF
# A pre-brave state.sh: no `brave` in SELECTED_COMPONENTS, no
# STATE_SCHEMA_VERSION line at all — exactly what install.sh wrote before
# the brave component existed.
cat > "$HOME3/.config/cesarmanzocode-rice/state.sh" <<'EOF'
THEME="monochrome"
SELECTED_COMPONENTS="hypr"
EOF
check "apply.sh migrates a pre-brave state.sh" env HOME="$HOME3" XDG_CONFIG_HOME="$HOME3/.config" \
  XDG_DATA_HOME="$HOME3/.local/share" ./apply.sh
check "brave theme got staged (component migrated on, matching install.sh's default)" \
  test -f "$HOME3/.local/share/cesarmanzocode-rice/brave/monochrome/manifest.json"
check "state.sh now records STATE_SCHEMA_VERSION" \
  grep -q '^STATE_SCHEMA_VERSION=' "$HOME3/.config/cesarmanzocode-rice/state.sh"
check "state.sh now lists brave in SELECTED_COMPONENTS" \
  bash -c '. "'"$HOME3"'/.config/cesarmanzocode-rice/state.sh"; case " $SELECTED_COMPONENTS " in *" brave "*) exit 0;; *) exit 1;; esac'
check "migration did not touch the user's other explicit off-choices (waybar stays off)" \
  bash -c "[ ! -e '$HOME3/.config/waybar' ]"

# Re-running apply.sh must not re-print the migration or duplicate `brave`.
check "second apply.sh run is a no-op for the migration" env HOME="$HOME3" XDG_CONFIG_HOME="$HOME3/.config" \
  XDG_DATA_HOME="$HOME3/.local/share" ./apply.sh
check "SELECTED_COMPONENTS lists brave exactly once after two runs" \
  bash -c '[ "$(grep -o "brave" "'"$HOME3"'/.config/cesarmanzocode-rice/state.sh" | wc -l)" -eq 1 ]'
rm -rf "$HOME3"

echo "== state migration: once versioned, an explicit brave=off choice is never re-added =="
HOME4="$(mktemp -d)"
mkdir -p "$HOME4/.config/cesarmanzocode-rice"
cat > "$HOME4/.config/cesarmanzocode-rice/user.lua" <<'EOF'
return {
  components = { hypr = true, waybar = false, rofi = false, swaync = false,
                 kitty = false, hyprlock = false, hypridle = false, wallpaper = false, brave = false },
  apps = { terminal = "kitty", browser = "brave", filemanager = "dolphin", launcher = "rofi -show drun" },
  binds = {},
}
EOF
# Already at the current schema version, brave absent on purpose — e.g. a
# fresh install.sh run where the user answered "no" to the brave prompt.
# Because the file is already versioned, migrate_state's v1->v2 step never
# runs again, so this stays off forever, unlike the one-time legacy
# (unversioned) case above.
cat > "$HOME4/.config/cesarmanzocode-rice/state.sh" <<'EOF'
THEME="monochrome"
SELECTED_COMPONENTS="hypr"
STATE_SCHEMA_VERSION="2"
EOF
check "apply.sh runs against an already-versioned, brave-off state" \
  env HOME="$HOME4" XDG_CONFIG_HOME="$HOME4/.config" XDG_DATA_HOME="$HOME4/.local/share" ./apply.sh
check "brave was NOT re-added (explicit choice preserved)" \
  bash -c "[ ! -e '$HOME4/.local/share/cesarmanzocode-rice/brave' ]"
check "state.sh's SELECTED_COMPONENTS is untouched (no rewrite needed)" \
  grep -q '^SELECTED_COMPONENTS="hypr"$' "$HOME4/.config/cesarmanzocode-rice/state.sh"
rm -rf "$HOME4"

echo "== rofi: every element state is explicitly themed, monochrome only =="
ROFI_RASI="config/rofi/config.rasi"
check "no bare 'element selected {' left unqualified (must be selected.normal/.active/.urgent)" \
  bash -c "! grep -qE '^element selected \{' '$ROFI_RASI'"
for state in normal.normal normal.active normal.urgent \
             alternate.normal alternate.active alternate.urgent \
             selected.normal selected.active selected.urgent; do
  check "rofi themes 'element $state'" bash -c "grep -qF 'element $state' '$ROFI_RASI'"
done
check "listview zeroes rofi's own default dashed top border" bash -c '
  sed -n "/^listview {/,/^}/p" config/rofi/config.rasi | grep -qE "border:\s*0;"
'
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

echo "== theme registry: apply.sh cleanly applies EVERY theme under themes/ =="
# apply.sh <theme> <components...> only NARROWS an already-selected set (see
# its own WANT/FILTER logic) — it never turns a component on that isn't
# already in SELECTED_COMPONENTS, exactly like a bare `./apply.sh` re-run
# after install.sh. So each theme gets a state.sh written first, the same
# way install.sh itself would, rather than relying on FILTER to enable
# components from nothing.
for THEME_DIR in themes/*/; do
  T="$(basename "$THEME_DIR")"
  THOME="$(mktemp -d)"
  mkdir -p "$THOME/.config/cesarmanzocode-rice"
  cat > "$THOME/.config/cesarmanzocode-rice/state.sh" <<EOF
THEME="$T"
SELECTED_COMPONENTS="hypr waybar rofi swaync kitty hyprlock hypridle wallpaper brave"
STATE_SCHEMA_VERSION="2"
EOF
  check "apply.sh $T (fresh, no prior install)" env HOME="$THOME" XDG_CONFIG_HOME="$THOME/.config" \
    XDG_DATA_HOME="$THOME/.local/share" ./apply.sh --no-backup
  check "$T: theme.lua installed" test -f "$THOME/.config/hypr/cesarmanzocode-rice/theme.lua"
  check "$T: theme.lua declares this theme's name" \
    grep -q "name = \"$T\"" "$THOME/.config/hypr/cesarmanzocode-rice/theme.lua"
  check "$T: wallpaper asset installed" test -f "$THOME/.config/hypr/wallpapers/$T.png"
  check "$T: waybar colors installed" test -f "$THOME/.config/waybar/colors.css"
  check "$T: rofi colors installed" test -f "$THOME/.config/rofi/colors.rasi"
  check "$T: swaync colors installed" test -f "$THOME/.config/swaync/colors.css"
  check "$T: kitty colors installed" test -f "$THOME/.config/kitty/colors.conf"
  check "$T: hyprlock.conf installed" test -f "$THOME/.config/hypr/hyprlock.conf"
  if [ -f "themes/$T/brave/manifest.json" ]; then
    check "$T: brave theme staged" test -f "$THOME/.local/share/cesarmanzocode-rice/brave/$T/manifest.json"
  fi

  # Structural overrides (theme_file_or_shared, see scripts/lib/common.sh):
  # when a theme ships its own waybar/rofi/swaync structure file, the
  # INSTALLED file must match the theme's, not the shared default — and
  # when it doesn't ship one, the shared default must still be installed
  # unchanged (this is monochrome's path, and must never regress).
  assert_structural_src() {
    local component_dir="$1" filename="$2" installed="$3"
    local theme_specific="themes/$T/$component_dir/$filename"
    local shared="config/$component_dir/$filename"
    if [ -f "$theme_specific" ]; then
      check "$T: installed $component_dir/$filename matches theme's own override" \
        diff -q "$theme_specific" "$installed"
    else
      check "$T: installed $component_dir/$filename falls back to the shared default" \
        diff -q "$shared" "$installed"
    fi
  }
  assert_structural_src waybar config.jsonc "$THOME/.config/waybar/config.jsonc"
  assert_structural_src waybar style.css    "$THOME/.config/waybar/style.css"
  assert_structural_src rofi   config.rasi  "$THOME/.config/rofi/config.rasi"
  assert_structural_src swaync config.json  "$THOME/.config/swaync/config.json"
  assert_structural_src swaync style.css    "$THOME/.config/swaync/style.css"

  rm -rf "$THOME"
done

echo
echo "passed: $PASS  failed: $FAIL"
[ "$FAIL" -eq 0 ]
