# ember-forge

Industrial/carbon. Where `monochrome` is a quiet neutral panel, `ember-forge`
reads as a serious tool: dense, solid, mechanical — charcoal/carbon and
near-black bases, dark warm browns, with copper/amber used only as a
sparing, well-measured accent (borders, focus, a handful of glows), never
as a bright-orange gamer fill. Surfaces are meant to feel material and
opaque, not glassy.

## Palette (`themes/ember-forge/hypr.lua` colors)

| Key | Hex | Use |
|---|---|---|
| `background` | `#0C0907` | App/compositor base, near-black warm carbon |
| `background_alt` | `#140F0B` | Waybar/SwayNC bar plate |
| `surface` | `#1D1610` | Rofi/notification card surface |
| `surface_alt` | `#281E16` | Secondary card/row surface |
| `foreground` | `#EAE0D5` | Body text |
| `foreground_strong` | `#FFF6EC` | Headlines, active tab text, clock |
| `muted` | `#9C8570` | Secondary text, rivet/node marks |
| `subtle` | `#4F3F32` | Disabled/faint text, structural lines |
| `border_inactive` | `#3D2E23` | Unfocused window/panel border |
| `border_active` | `#C97536` | Copper — focused window border, Rofi border |
| `accent` | `#E8973B` | Amber — cursor, highlights, small glows |

Copper (`border_active`) and amber (`accent`) are kept distinct on purpose:
copper is the structural/border color, amber is the "hot" highlight used
more sparingly (cursor, focal wallpaper glows, one lit truss node).

## What's structurally different from `monochrome`

Same schema, deliberately different numbers — this is meant to feel firmer
and less transparent than monochrome's glassy panel, not just re-tinted:

| Field | monochrome | ember-forge | direction |
|---|---|---|---|
| `border_size` | 1 | **2** | thicker, more present frame |
| `gaps_in` | 8 | **5** | tighter, denser |
| `gaps_out` | 16 | **10** | tighter, denser |
| `rounding` | 9 | **3** | smaller, tenser corners |
| `rounding_power` | 4 (softened squircle) | **2** (near-circular) | more geometric, less organic |
| `blur_size` | 6 | **3** | less blur |
| `blur_passes` | 2 | **1** | less blur |
| `blur_vibrancy` | 0 | **0.2** | faint copper undertone shows through blur |
| `active_opacity` | 1.0 | 1.0 | same |
| `inactive_opacity` | 0.97 | **0.99** | closer to opaque |

Net effect: less glass, more plate. Waybar/Rofi/SwayNC read as compact,
near-opaque panels (see each component's `colors.css`/`colors.rasi` —
alpha values there are all higher than monochrome's equivalents, e.g.
Rofi's background `0xEE` vs monochrome's `0xD6`, SwayNC's bg alpha `0.94`
vs `0.8`) rather than floating glass.

## Wallpaper pack (`scripts/dev/generate_wallpaper_ember_forge.py`)

Four procedural variants, carbon/copper (not grayscale). Hard geometry,
diagonals, and fractures carry the "heat/industrial control" feeling —
deliberately no flame silhouettes, no lava, no literal fire anywhere.

- **temper** (default/canonical) — large dark carbon planes on long
  diagonals with one or two thin copper seams cutting across them and a
  single small, contained amber glow where a seam ends.
- **truss** — an industrial diagonal truss/gantry structure (Warren-truss
  crossing beams) with rivet-like node marks and one lit copper diagonal
  beam plus one glowing node.
- **fissure** — jagged stress-fracture cracks radiating from two origin
  points across large carbon plates, copper near each origin fading to
  brown as the crack travels, with a small contained glow at each source.
- **plate** — the quietest variant: a single off-center carbon plate with
  riveted corners and one copper edge-seam, mostly empty canvas around it.

`wallpapers/ember-forge.png` is a byte-identical copy of `temper` (the
canonical default `hypr.lua` points at). Regenerate with:

```sh
python3 scripts/dev/generate_wallpaper_ember_forge.py all wallpapers/
cp wallpapers/ember-forge-temper.png wallpapers/ember-forge.png
```

## Motion tuning (`themes/ember-forge/hypr.lua` `motion`)

Overridden from the shared defaults in `config/hypr/animations.lua` to
read as firm/dry/terse — faster settle, pushed toward critical damping so
motion looks decisive and mechanical rather than springy:

| Spring | monochrome (shared default) | ember-forge | ratio |
|---|---|---|---|
| window | 310 / 31 (ratio ~0.88) | **420 / 38** | ~0.93 |
| workspace | 250 / 27 (ratio ~0.85) | **340 / 34** | ~0.92 |
| layer | 330 / 33 (ratio ~0.91) | **420 / 39** | ~0.95 |
| special_workspace | 250 / 23 (ratio ~0.73) | **300 / 32** | ~0.92 |

(ratio = `damping / (2*sqrt(stiffness))`, mass fixed at 1.) The special
workspace in particular is pushed much closer to critical damping than
monochrome's — it should read as a solid mechanical shift, not an
energetic bounce.

Speeds are also uniformly faster than the shared defaults (e.g.
`windows` 1.2 vs 1.6, `workspaces`/`special_workspace` 1.3 vs 2.0, `border`
0.5 vs 0.8 — see the `speeds` table in `hypr.lua` for the full set), and
`windows_popin` is tightened to `"popin 97%"` (vs the shared default's
`"popin 94%"`) so windows snap into place with less growth on arrival.

## Structure (v2 — structural pass)

This section documents the mockup composition and the exact override
files added to implement it. Nothing in the "Palette"/"What's
structurally different"/"Wallpaper pack"/"Motion tuning" sections above
changed in this pass — they're the approved v1 output. This pass adds
layout/orientation/anchor overrides on top of that.

### The mockup's quadrant, literally

```
[ LEFT VERTICAL DOCK ] [        large main area        ] [ right stack: system monitor card ]
[  (icons, stacked    ] [                                ] [ right stack: terminal card        ]
[   vertically)        ] [                                ] [                                    ]
```

Mapped onto the real shell surfaces this rice has (no fake apps — a
"system monitor card"/"terminal card" are not built; the mockup's
right-side stack is reproduced structurally via the one real component
that already lives there):

- **Left vertical dock -> Waybar**, restructured into an actual left-edge
  vertical bar (not a re-tinted top bar).
- **Large main area -> unchanged**: the normal Hyprland tiling area, gaps
  already tightened via `geometry.gaps_in`/`gaps_out` from v1 (unchanged
  this pass).
- **Right-side stack of compact, dense, technical cards -> SwayNC's
  notification/control-center cards**, restyled sharper/tighter/more
  bordered and kept docked top-right, since notification cards are the
  one real "stack of separate bordered cards" surface this rice has —
  building an actual fake system-monitor or terminal widget to fill that
  slot would violate the "no fake apps" rule, so density/border/corner
  language does the identity work here instead of literal card content.
- **Rofi** isn't named in the mockup's quadrant sketch above, but per the
  contract's launcher-anchor guidance it was moved to anchor near the
  dock (left edge) rather than dead center, for the same "launcher lives
  near the dock" reasoning called out in the theme-authoring-contract.

### Files added this pass (all OPTIONAL overrides per the v2 contract)

```
themes/ember-forge/waybar/config.jsonc   # NEW — left vertical dock, real Waybar structure change
themes/ember-forge/waybar/style.css      # NEW — narrow-column CSS to match
themes/ember-forge/rofi/config.rasi      # NEW — west-anchored launcher
themes/ember-forge/swaync/config.json    # NEW — tighter margins/narrower width, still top-right
themes/ember-forge/swaync/style.css      # NEW — sharp-cornered, bordered "card stack" styling
```

`themes/ember-forge/waybar/colors.css`, `rofi/colors.rasi`,
`swaync/colors.css` are untouched (same values as v1) — only structure
changed. `hypr.lua`'s `colors`/`geometry`/`motion` tables are also
unchanged; a new `layers` table was added (see below).

### Waybar: exact vertical-dock config shape used

Copied `config/waybar/config.jsonc` as the starting point and changed:

- `"position": "top"` -> `"position": "left"`
- `"height": 34` -> `"width": 52` (primary dimension flips from height to
  width for a side-docked bar — Waybar's own convention)
- `margin-top`/`margin-left`/`margin-right` -> `margin-top`/`margin-bottom`/
  `margin-left` (no `margin-right` needed pinned to the left screen edge)
- **Module grouping**: kept the same three keys (`modules-left`,
  `modules-center`, `modules-right`) rather than inventing new ones,
  because Waybar's own behavior for a `left`/`right`-positioned bar reuses
  these exact keys and stacks each group's modules top-to-bottom within
  it — `modules-left` becomes the TOP group of the column, `modules-center`
  the MIDDLE group, `modules-right` the BOTTOM group. This is Waybar's
  documented behavior for non-`top`/`bottom` bar positions, not a
  repurposing invented for this theme:
  - top group: `custom/launcher`, `hyprland/workspaces` (same modules,
    same order, as the shared bar's left group)
  - middle group: `clock`
  - bottom group: `pulseaudio`, `network`, `custom/cliphist`, `tray`,
    `custom/notification`, `custom/power` (same modules, same order, same
    `on-click`/`on-scroll`/`exec` commands as the shared bar's right group)
- Every module's functional fields (`on-click`, `on-scroll-up/down`,
  `exec`, `return-type`, `format-icons`) are byte-identical to the shared
  config — nothing was dropped or rewired, only the always-visible text
  for `pulseaudio`/`network` was trimmed to icon-only (percentage/
  ifname/essid detail moved into `tooltip-format`, still reachable on
  hover) because a 52px-wide column has no room for `"  75%"`-style
  strings. `clock`'s format changed from `"{:%H:%M · %a %d %b}"` to a
  stacked `"{:%H\n%M}"` with the full date moved to the tooltip, for the
  same reason.
- `style.css` was rewritten for a narrow, tall `window#waybar`: sharp
  corners (`border-radius: 4px` on the plate, 1-2px on rows/tooltips,
  matching `geometry.rounding = 3`), a visibly thicker 2px border, and
  vertical padding/spacing between module groups instead of horizontal.

### Rofi: anchor choice

Moved from the shared config's `location: center; anchor: center;` to
`location: west; anchor: west;` with a small `x-offset: 24px`, so the
launcher opens near the left dock rather than in the middle of the
screen — consistent with "the launcher lives near the dock." Also
dropped rounding to 2px (from the shared config's 14px) and doubled the
border to 2px, to read as more angular/technical than arctic-glass's
centered glass launcher. Because the anchor moved off-center,
`hypr.lua`'s new `layers.rofi.animation` is set to `"slide left"`
(replacing the v1-inherited default `"popin 96%"`, which only makes sense
for a centered popup).

### SwayNC: what changed vs. what didn't

`positionX`/`positionY` stay `"right"`/`"top"` — the v1 default — because
the mockup's right-side stack sits on the right, same as SwayNC's
existing dock edge; nothing about docking a left-side Waybar requires
moving it. What changed: `control-center-width` 400 -> 340 (narrower,
denser card), `control-center-margin-right`/`-top` tightened from
14/8 to 8/8 (a left-dock theme has no top bar to clear, so it can sit
closer to the corner), and `style.css` gives every card a full 1px
visible border + 2px corner radius (vs. the shared config's soft 11-14px
rounding and border-as-depth-hint-only), so each notification reads as a
separate bordered technical card in a stack, not rows inside one soft
panel.

### `hypr.lua` `layers` table (new this pass)

```lua
layers = {
  waybar = { animation = "slide left" },
  rofi   = { animation = "slide left" },
},
```

`swaync` is deliberately omitted — its edge didn't change (still
top-right, still the v1-inherited `"slide right"` default from
`config/hypr/layers.lua`), only its card styling did.

### Hyprlock: tightened composition

v1's hyprlock positions (clock at `0, 140`, date at `0, 40`, input at
`0, -120` — a ~260px vertical spread) were structurally identical to
monochrome's, just re-colored. This pass pulls the three blocks in to
clock `0, 60`, date `0, -8`, input `0, -90` (a ~150px spread), bumps the
clock to `font_size 92` (from 88) and the input's `outline_thickness` to
3 (from 2) with `rounding` dropped to 2 (from 6), so the whole stack
reads as denser/firmer/more industrial and distinct from monochrome's
airier layout, while keeping the same three required blocks
(`background`, two `label`s, one `input-field`) and the `@WALLPAPER@`
placeholder.

### Wallpaper

Not regenerated. The existing pack's quiet zones (a top strip + a
centered box, per `scripts/dev/wallpaper_lib.py`'s `Canvas` defaults)
don't overlap a left-edge vertical dock — the dock now sits where the
wallpaper was never made deliberately quiet, but none of the four
variants place important detail hard against the left edge either, so
there's no real visual conflict to fix. Confirmed by inspection of all
four variants' composition descriptions above (diagonals/truss/fractures/
off-center plate) — none of them anchor content to the left edge.

## Manual verification (real hardware only)

This environment has no live Hyprland/Wayland session, no `lua`, no
Waybar/Rofi/SwayNC/Kitty binaries — everything below was only checked
statically (`tests/check_all_themes.py`, `tests/run_tests.sh`, PNG header/
JSON parsing, and manually stripping `//` comments from
`waybar/config.jsonc` to confirm it's valid JSON). **This environment
cannot confirm Waybar actually renders a working vertical bar with this
exact config on the real installed Waybar version — that is a REQUIRED
manual runtime check before calling this theme done.** In particular,
verify on real hardware:

- **Waybar left dock (REQUIRED first check)**: after `./apply.sh
  ember-forge` (or `./apply.sh ember-forge waybar`), confirm Waybar
  actually docks to the left edge as a narrow vertical column — not a
  top bar, not a crash/fallback to defaults. Confirm every module still
  works: launcher click opens Rofi, workspace buttons switch/reflect the
  active workspace, the clock shows stacked HH/MM with the full date on
  hover, pulseaudio/network icons respond to click/scroll and show
  correct tooltips, cliphist/tray/notification/power icons are all
  present and clickable. If this version of Waybar handles vertical
  `modules-left`/`modules-center`/`modules-right` differently than
  documented here, this is the file to revisit.
- **Waybar entrance animation**: reload Waybar (or trigger a monitor
  hotplug) and confirm it slides in from the left edge, not the top.

On real hardware (Hyprland 0.56.2 / Wayland), after `./apply.sh` with
this theme selected:

- **Windows**: open/close a few apps — opening should read as a quick,
  tight snap into place (barely any growth, unlike monochrome's slightly
  larger pop-in), closing should be immediate with no rebound.
- **Borders**: focused-window border should show as a clearly thicker
  copper (`#C97536`) line than monochrome's thin white one; focus changes
  should feel effectively instant.
- **Blur**: windows/panels should look noticeably less "glassy" than
  monochrome — a hint of blur, not a translucent pane; wallpaper detail
  behind Kitty/Rofi should barely show through.
- **Gaps/rounding**: windows should sit closer together with less
  breathing room than monochrome, and corners should look close to
  square, not the soft squircle monochrome uses.
- **Rofi** (`SUPER+R`): panel should feel firm/opaque, not floating —
  confirm the copper border and near-opaque background read as a
  technical panel, AND confirm it opens anchored near the left edge
  (sliding in from the left), not centered on screen.
- **SwayNC**: cards should show clear stacked hierarchy
  (`surface`→`surface_alt`), feel more solid/less vaporous than
  monochrome's control center, AND each notification/card should show a
  clearly visible full border with sharp (near-square) corners — a stack
  of separate technical cards, not rows in one soft panel. Should still
  dock top-right and not overlap the left dock.
- **Hyprlock**: confirm the clock/date/input stack reads as visibly
  tighter/denser than monochrome's lock screen, with sharp (2px) input
  corners.
- **Wallpaper**: `wallpapers/ember-forge.png` (== `ember-forge-temper.png`)
  should render with visible copper/amber seams against the carbon base,
  and Waybar's strip / Rofi's usual position should sit over the
  deliberately-quieter zones baked into the image. Try the other three
  variants too (copy one over `wallpapers/ember-forge.png` and
  `./apply.sh`).
- **Special workspace** (`SUPER+S`): should feel like a firm, contained
  shift — no bounce, unlike monochrome's slightly livelier version.
