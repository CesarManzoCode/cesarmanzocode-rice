# Theme authoring contract (v2 — structural pass)

This supersedes the v1 contract used for the first pass. The palette/
geometry/motion/wallpaper contract from v1 is UNCHANGED and still applies
(see below) — this version adds the STRUCTURAL override mechanism that
lets a theme's actual shell layout (bar position, launcher composition,
notification panel placement) differ, not just its colors.

**Scope discipline is unchanged: touch ONLY the files listed under "Files
you own" for your theme's slug. Never edit anything shared** — `config/`,
`scripts/lib/`, `install.sh`, `apply.sh`, `uninstall.sh`,
`tests/run_tests.sh`, `tests/check_all_themes.py`,
`scripts/dev/wallpaper_lib.py`, `config/hypr/layers.lua`,
`config/hypr/animations.lua`, or another theme's directory. All shared
mechanics already exist; if something is genuinely missing, say so in
your report instead of changing shared files.

## THE MOCKUP IS THE SPEC, NOT INSPIRATION

You were given (in your task prompt) the exact composition for your
theme's quadrant of an approved 4-panel mockup image. That composition —
bar position and orientation, where the "main area" sits, where secondary
panels/stacks sit, how much whitespace there is — is a literal
requirement, not a mood reference. Your job is to make Waybar/Rofi/
SwayNC/Hyprland/Kitty/Brave/Hyprlock reproduce that composition as
faithfully as real components allow. Where something literally cannot be
reproduced (there is no such thing as a fake chat app, a fake code editor,
a fake music player in this rice — never build one), adapt while
preserving: composition, hierarchy, geometry, density, spatial direction,
visual language. Never substitute "a different but thematically similar"
layout for the one you were given.

**The grayscale test**: if you screenshotted your theme applied and
converted it to grayscale, someone who has seen the mockup should still
be able to tell which quadrant it is, from layout alone — bar position,
launcher shape/anchor, notification panel placement, density, gaps. If
color is doing all the identity work, you are not done.

## Files you own (replace `<slug>` with your theme's name)

Same as v1, PLUS four new optional structural files:

```
themes/<slug>/hypr.lua                       # colors + geometry + optional motion + optional layers
themes/<slug>/waybar/colors.css              # required
themes/<slug>/waybar/config.jsonc            # OPTIONAL — bar structure override (NEW)
themes/<slug>/waybar/style.css               # OPTIONAL — bar layout/CSS override (NEW)
themes/<slug>/rofi/colors.rasi               # required
themes/<slug>/rofi/config.rasi               # OPTIONAL — launcher structure override (NEW)
themes/<slug>/swaync/colors.css              # required
themes/<slug>/swaync/config.json             # OPTIONAL — panel position/geometry override (NEW)
themes/<slug>/swaync/style.css               # OPTIONAL — panel layout/CSS override (NEW)
themes/<slug>/kitty/colors.conf
themes/<slug>/hyprlock.conf                  # give it YOUR theme's own composition, not monochrome's relabeled
themes/<slug>/brave/manifest.json
scripts/dev/generate_wallpaper_<slug>.py     # dev-time only — reuse the existing wallpapers unless your
                                              #   composition genuinely requires new ones (see below)
docs/themes/<slug>.md                        # identity, palette, motion, STRUCTURE, manual QA checklist
```

**How the optional overrides work** (`apply.sh`, via
`scripts/lib/common.sh`'s `theme_file_or_shared`): if
`themes/<slug>/waybar/config.jsonc` exists, it is installed instead of
the shared `config/waybar/config.jsonc` — same for `waybar/style.css`,
`rofi/config.rasi`, `swaync/config.json`, `swaync/style.css`. Omit any of
these and the shared default is used for that file. **You almost
certainly need at least `waybar/config.jsonc` and `waybar/style.css`** to
get a non-top-bar layout (vertical dock/rail) — the shared one is a fixed
horizontal top bar and cannot become vertical via colors alone. Copy the
shared file as your starting point (`config/waybar/config.jsonc` etc.)
and restructure from there — keep every existing module (launcher,
workspaces, clock, pulseaudio, network, cliphist, tray, notification,
power) present and wired to the same `on-click`/`exec` commands; you are
changing layout/orientation/grouping, never functionality, app choices,
or binds.

Waybar's `"position": "left"|"right"|"top"|"bottom"` alone controls
vertical vs. horizontal bars — `Bar::Bar` picks
`Gtk::ORIENTATION_VERTICAL` automatically for `left`/`right`; there is
no separate top-level `"orientation"` key, and setting one has no effect
(verified against Waybar 0.15.0 source). Keep using
`modules-left`/`modules-center`/`modules-right` on a vertical bar too —
`setupWidgets()` only ever wires up those three keys, never a top-level
`"modules"` array (a theme that ships one instead of
`modules-left`/`-center`/`-right` starts with zero modules on that
group). On a left/right bar, Waybar stacks each group's modules
top-to-bottom within it, and stacks the groups themselves top-to-bottom
in order (`modules-left` = top, `modules-center` = middle,
`modules-right` = bottom) — see `themes/ember-forge/waybar/config.jsonc`
or `themes/violet-night/waybar/config.jsonc` for worked examples. Write
CSS for a narrow, tall `window#waybar` instead of a wide, short one.

Rofi's `window { location; anchor; }` control on-screen placement — e.g.
`location: west; anchor: west;` docks it to the left edge instead of
center. SwayNC's `config.json` has `positionX`/`positionY`,
`control-center-margin-*`, `control-center-width` — use these to place/
size the panel to match your composition and to avoid overlapping your
theme's own Waybar placement (e.g. a left-dock theme can use a small
`control-center-margin-top` since there's no top bar to clear; a
top-bar theme needs enough margin to clear it).

## `themes/<slug>/hypr.lua`: optional `layers` table (NEW)

If your theme's Waybar/Rofi don't enter from their v1-default edge
(Rofi popin center, Waybar slide from top, SwayNC slide from right), add
only the overrides you need — `config/hypr/layers.lua` reads these with
the v1 defaults as fallback, so omit anything unchanged:

```lua
layers = {
  waybar = { animation = "slide left" },   -- for a left dock, e.g.
  rofi   = { animation = "slide left" },   -- if Rofi isn't centered
  swaync = { animation = "slide right" },  -- override only if you actually reposition it
},
```

Never change the `match.namespace` values (they're verified against
real `hyprctl layers` output and stay `^waybar$` / `^rofi$` /
`^swaync-control-center$` regardless of theme) — only `animation`/
`ignore_alpha` are theme-overridable, and only via this table, never by
editing `layers.lua` itself.

## Everything else from v1 is unchanged — still required

- `hypr.lua`'s `colors`/`geometry`/optional `motion` tables: same schema
  as before (see `tests/check_all_themes.py` for the exact required
  keys). Use `themes/monochrome/hypr.lua` as the structural reference for
  shape, never for values.
- Wallpapers: the existing packs from the first pass
  (`wallpapers/<slug>-*.png` + canonical `wallpapers/<slug>.png`,
  generated by `scripts/dev/generate_wallpaper_<slug>.py`) already exist
  and were approved — **do not regenerate them** unless your theme's
  composition literally requires a different aspect/quiet-zone layout
  (e.g. a vertical dock changes where the "quiet zone" should sit — the
  `Canvas` in `scripts/dev/wallpaper_lib.py` dims a top strip + a
  centered box by default; if your bar is now a side dock, consider
  passing different quiet-zone geometry or accept the existing wallpaper
  as close enough). If you do touch a generator, keep it fully backward
  compatible (same CLI, same determinism) and regenerate + commit the
  PNGs.
- Brave manifest schema: unchanged (manifest_version 3, `theme.colors`
  only, documented Chromium keys only, no JS/permissions/content
  scripts). Revisit only the actual color VALUES if your composition
  brief calls for a different frame/toolbar mood — do not change the
  file's shape.
- `docs/themes/<slug>.md`: keep the v1 content (identity/palette/
  wallpaper/motion/manual QA) and ADD a "Structure" section describing
  the composition you implemented (bar position/orientation, launcher
  anchor, notification panel placement) and exactly which optional
  override files you added and why.

## Hyprlock composition (NEW emphasis)

Give your theme's `hyprlock.conf` its own composition, not monochrome's
relabeled — e.g. different label position/alignment, input-field
position/size/anchor, sizing that matches your theme's density (Ivory:
more whitespace, smaller/quieter type; Ember: tighter, more centered/
industrial; Arctic: airy, could shift elements to echo the floating-glass
language; Violet: could feel more cinematic/off-center). Keep the same
three blocks (`background`, two `label`s, one `input-field`) and the
`@WALLPAPER@` placeholder — restructure position/size/alignment/type
choices within that shape.

## No fake apps

The mockup shows an editor, a browser, a music player, a terminal, a chat
UI, a file manager, a system monitor. **Never build a clone or fake of
any of these** — that content is illustrative, not something this rice
ships. Reproduce only real shell surfaces this rice actually has: the
bar, the launcher, the notification panel, window decoration/blur/
rounding, the lock screen, browser chrome, terminal appearance, and the
wallpaper. Do not add new widgets/scripts/fake-content modules to make a
screenshot look more like the mockup.

## Validating your work (this environment has no live Hyprland/lua/kitty)

From your worktree's repo root:

```sh
python3 tests/check_all_themes.py
bash tests/run_tests.sh 2>&1 | tail -60   # ignore the single pre-existing
  # "user.lua still parses" failure — caused by no `lua` binary in this
  # container, unrelated to any theme work
```

Also hand-verify your new/changed JSON:

```sh
python3 -c "import json; json.load(open('themes/<slug>/swaync/config.json'))"
python3 -c "import json; json.load(open('themes/<slug>/brave/manifest.json'))"
```

There is no `lua`, `hyprctl`, or Waybar/Rofi/SwayNC/Kitty binary in this
environment. Say so plainly in your report — do not claim a live
rendering check you could not actually run. If `grim`/a live Hyprland
session genuinely is available to you, apply your theme and screenshot
it; if not (expected in this environment), say that explicitly and leave
a manual-verification checklist in your `docs/themes/<slug>.md` instead.

## Commit

One commit (or a couple of small, clearly-scoped ones) on your branch
(`feat/theme-<slug>-structure`), touching only the files listed above.
Do not push — report back when done.
