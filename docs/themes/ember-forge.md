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

## Manual verification (real hardware only)

This environment has no live Hyprland/Wayland session, no `lua`, no
Waybar/Rofi/SwayNC/Kitty binaries — everything below was only checked
statically (`tests/check_all_themes.py`, `tests/run_tests.sh`, PNG header/
JSON parsing). On real hardware (Hyprland 0.56.2 / Wayland), after
`./apply.sh` with this theme selected:

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
  technical panel, not glass.
- **SwayNC**: cards should show clear stacked hierarchy
  (`surface`→`surface_alt`) and feel more solid/less vaporous than
  monochrome's control center.
- **Wallpaper**: `wallpapers/ember-forge.png` (== `ember-forge-temper.png`)
  should render with visible copper/amber seams against the carbon base,
  and Waybar's strip / Rofi's usual position should sit over the
  deliberately-quieter zones baked into the image. Try the other three
  variants too (copy one over `wallpapers/ember-forge.png` and
  `./apply.sh`).
- **Special workspace** (`SUPER+S`): should feel like a firm, contained
  shift — no bounce, unlike monochrome's slightly livelier version.
