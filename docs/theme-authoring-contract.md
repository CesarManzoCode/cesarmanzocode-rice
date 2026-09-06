# Theme authoring contract

This is the exact, self-contained contract a new theme must satisfy in
this repo. It exists so a theme can be built in isolation (its own
branch/worktree) without touching shared code, and so
`tests/check_all_themes.py` validates it automatically.

**Scope discipline: touch ONLY the files listed under "Files you own"
below for your theme's slug. Never edit anything under `config/`,
`scripts/lib/`, `install.sh`, `apply.sh`, `uninstall.sh`,
`tests/run_tests.sh`, `tests/check_all_themes.py`,
`scripts/dev/wallpaper_lib.py`, or another theme's directory.** All of
that is shared foundation, already done; if you think it's genuinely
missing something, say so in your final report instead of changing it.

## Files you own (replace `<slug>` with your theme's name)

```
themes/<slug>/hypr.lua                       # colors + geometry (+ optional motion)
themes/<slug>/waybar/colors.css
themes/<slug>/rofi/colors.rasi
themes/<slug>/swaync/colors.css
themes/<slug>/kitty/colors.conf
themes/<slug>/hyprlock.conf
themes/<slug>/brave/manifest.json
scripts/dev/generate_wallpaper_<slug>.py     # dev-time only, see below
wallpapers/<slug>.png                        # canonical default (byte-identical copy of one variant)
wallpapers/<slug>-<variant1>.png             # >= 3 variants total
wallpapers/<slug>-<variant2>.png
wallpapers/<slug>-<variant3>.png
docs/themes/<slug>.md                        # identity, palette, motion, manual QA checklist
```

Use `themes/monochrome/*` as your working reference for shape/format —
copy its structure, never its actual colors/values (this theme must look
and feel different, not just be monochrome relabeled).

## `themes/<slug>/hypr.lua`

Same shape as `themes/monochrome/hypr.lua`. Required top-level keys:

```lua
return {
  name = "<slug>",   -- must equal your theme's directory name exactly

  colors = {
    background, background_alt, surface, surface_alt,
    foreground, foreground_strong, muted, subtle,
    border_inactive, border_active, accent,   -- all required, hex strings without '#'
  },

  geometry = {
    border_size, gaps_in, gaps_out, rounding,           -- required
    rounding_power,                                      -- optional (see monochrome's comment on it)
    blur_enabled, blur_size, blur_passes,                -- required
    blur_noise, blur_contrast, blur_brightness,          -- required
    blur_vibrancy, blur_vibrancy_darkness,               -- required (0 is a valid/common value)
    shadow_enabled, active_opacity, inactive_opacity,    -- required
  },

  -- OPTIONAL: only set the sub-keys you actually want to differ from
  -- monochrome's hardcoded defaults (see config/hypr/animations.lua for
  -- what each default is). Omit any field/sub-table you don't need to
  -- change — you do not have to specify all of them.
  motion = {
    springs = {
      window            = { stiffness = ..., damping = ... },
      workspace         = { stiffness = ..., damping = ... },
      layer             = { stiffness = ..., damping = ... },
      special_workspace = { stiffness = ..., damping = ... },
    },
    speeds = {
      windows, windows_in, windows_out, windows_move,
      layers_in, layers_out, fade_in, fade_out,
      workspaces, special_workspace, border,
    },
    styles = {
      windows_popin, workspaces, special_workspace,   -- e.g. "popin 92%", "slidefade 12%"
    },
  },

  wallpaper = "wallpapers/<slug>.png",
}
```

`tests/check_all_themes.py` checks that every required `colors`/`geometry`
key is present and that `name`/`wallpaper` match your slug — it does NOT
police specific values (that's your judgment call per the visual brief
you were given), only structural completeness.

Springs: `mass` is always 1 (fixed elsewhere). Pick `stiffness`/`damping`
so the damping ratio (`damping / (2*sqrt(stiffness*mass))`) sits in
roughly 0.7-0.95 — at most a barely-perceptible overshoot, never a
repeating wobble/bounce. A lower ratio (more underdamped) reads as more
"alive"/expressive; near 0.95 reads as firm/precise.

## Per-component color/CSS/rasi files

Copy `themes/monochrome/{waybar,rofi,swaync,kitty}/...` and
`themes/monochrome/hyprlock.conf` structurally (same selectors/keys/
variables), replacing only the actual color values and any
theme-specific numeric tuning called out in your visual brief (e.g.
opacity/alpha, blur amounts already live in `hypr.lua`'s `geometry`, not
here — these files are palette only, same division of labor monochrome
already uses). Never touch `config/waybar/config.jsonc`,
`config/waybar/style.css`, `config/rofi/config.rasi`,
`config/swaync/config.json`, `config/swaync/style.css`,
`config/kitty/kitty.conf` (the shared, theme-agnostic component
configs) — only your theme's own `colors.css`/`colors.rasi`/
`colors.conf`/`hyprlock.conf`.

`hyprlock.conf`: same structure as monochrome's (background block with
`path = @WALLPAPER@`, two labels, one input-field) — `apply.sh` replaces
`@WALLPAPER@` for you; keep the placeholder literally as `@WALLPAPER@`.

## `themes/<slug>/brave/manifest.json`

Copy `themes/monochrome/brave/manifest.json`'s exact shape
(`manifest_version: 3`, `theme.colors` only, no `permissions` /
`host_permissions` / `content_scripts` / `background`), and use ONLY
these documented Chromium `theme.colors` keys (verified against
`chrome/browser/themes/browser_theme_pack.cc`'s
`kOverwritableColorTable`):

```
background_tab, background_tab_inactive,
background_tab_incognito, background_tab_incognito_inactive,
bookmark_text, button_background,
frame, frame_inactive, frame_incognito, frame_incognito_inactive,
ntp_background, ntp_header, ntp_link, ntp_text,
omnibox_background, omnibox_text,
tab_background_text, tab_background_text_inactive,
tab_background_text_incognito, tab_background_text_incognito_inactive,
tab_text, toolbar, toolbar_button_icon, toolbar_text
```

Every color is a 3-element `[R, G, B]` integer array (0-255). No JS
files, no icons/background/content-script directories under
`themes/<slug>/brave/` — manifest-only.

## Wallpapers: `scripts/dev/generate_wallpaper_<slug>.py`

Procedural, standard-library only, dev-time-only (never invoked by
install.sh/apply.sh/uninstall.sh). Import the shared canvas from the
sibling module:

```python
from wallpaper_lib import Canvas, DEFAULT_WIDTH, DEFAULT_HEIGHT
```

(`wallpaper_lib.py` lives at `scripts/dev/wallpaper_lib.py` — do not
edit it, only import from it. It offers `Canvas(w, h, bg=...)` with
`set_px`, `draw_line`, `fill_rect`, `fill_triangle`, `fill_circle`,
`blend_px`, `radial_glow`, and `write_png(path)`.)

Structure your script after `scripts/dev/generate_wallpaper.py`
(monochrome's own, now a thin user of `wallpaper_lib`): a fixed,
variant-specific integer seed per variant (never time/host-derived — this
is what makes regeneration deterministic), a `VARIANTS` tuple, one draw
function per variant, a `render(variant, width, height)` entry point, and
a CLI (`variant`, `out.png`, optional `WxHeight`, plus an `all
<out_dir>` mode that writes `wallpapers/<slug>-<variant>.png` for every
variant). At least 3 variants; a 4th is fine if the marginal effort is
small — do not build more than that.

Then actually run it and commit the generated PNGs under `wallpapers/`:

```sh
python3 scripts/dev/generate_wallpaper_<slug>.py all wallpapers/
cp wallpapers/<slug>-<your-chosen-default>.png wallpapers/<slug>.png
```

Constraints checked by `tests/check_all_themes.py`: every
`wallpapers/<slug>-*.png` must be >= 1920x1080, truecolor RGB (PNG color
type 2, no alpha), and `wallpapers/<slug>.png` must be byte-identical to
one of your variants. Unlike monochrome, your palette does NOT need to be
grayscale — use your theme's real colors, just keep saturation/contrast
tasteful per your visual brief (busy/neon reads as a regression, not a
feature). Respect the `Canvas`'s built-in Waybar-strip/Rofi-box quiet
zones (pass your own `bg` color into `Canvas(w, h, bg=your_background)`)
so wallpapers don't fight the shell UI sitting on top of them.

## `docs/themes/<slug>.md`

Short, like the level of detail in this repo's own commit messages — not
a marketing page. Cover: one-paragraph identity statement, the palette
(hex values + what each is used for), what's structurally different from
monochrome (density/blur/rounding/border/opacity/transparency — name the
actual numbers), the wallpaper pack (variant names + one line each), the
motion tuning you chose and why (or "uses the shared defaults" if you
didn't override `motion`), and a short "manual verification" checklist
in the same style as the one in `README.md`'s own "Manual verification"
section (things to look at on a real Hyprland session, since this
environment cannot run one).

## Validating your work (this environment has no live Hyprland/lua/kitty)

Run from the repo root of YOUR worktree:

```sh
python3 scripts/dev/generate_wallpaper_<slug>.py all wallpapers/
python3 tests/check_all_themes.py
bash tests/run_tests.sh 2>&1 | tail -40   # full suite; ignore the single
  # pre-existing "user.lua still parses" failure — that's `lua` missing
  # from this container, unrelated to any theme
```

Also sanity-check your JSON/CSS by hand:

```sh
python3 -c "import json; json.load(open('themes/<slug>/brave/manifest.json'))"
```

There is no `lua` interpreter, no `hyprctl`, and no Waybar/Rofi/SwayNC/
Kitty binaries in this environment — say so plainly in your report rather
than claiming a live check you couldn't actually run. Static
structural/schema validation via the commands above is what you CAN
prove, and that's the bar.

## Commit

One commit (or a couple of small, clearly-scoped ones) on your own branch
(`feat/theme-<slug>`), touching only the files listed above. Do not
push — report back when done; the branches get merged centrally.
