# cesarmanzocode-rice

A modular, reusable Hyprland rice. The first appearance is **monochrome** —
black and white, high contrast, almost no color.

*(screenshot placeholder — add one here after your first install)*

This is not "just dotfiles". It's a small, deterministic installer plus a
clear separation between:

- **shared functionality** — layout, navigation, structure (`config/`)
- **theme** — colors, geometry, wallpaper (`themes/<name>/`)
- **your preferences** — apps, keybinds, machine overrides (kept outside
  the repo, in `~/.config/cesarmanzocode-rice/`)

Switching themes never changes your apps or keybinds. Pulling new commits
never overwrites your preferences.

## Requirements

- Arch Linux (automatic package installation; other distros can still use
  `--skip-packages` and install the stack manually)
- Hyprland >= 0.55 (native Lua config — see [Why Lua?](#why-lua) below),
  ideally run under UWSM
- Bash — no Python/Node/Ansible/Nix/Stow/chezmoi required at runtime, and
  no standalone `lua` interpreter either: Hyprland's own embedded Lua
  parses everything this rice installs

Stack this rice targets: Hyprland, UWSM, Waybar, Rofi, SwayNC, hyprpaper,
hyprlock, hypridle, hyprpolkitagent, Kitty, PipeWire/WirePlumber, grim,
slurp, cliphist, libnotify, JetBrains Mono Nerd Font, Noto fonts. Where a component
ships a systemd `--user` unit (waybar, swaync, hyprpaper, hypridle,
hyprpolkitagent), that unit — not Hyprland's own config — is what starts
it; see [Autostart & UWSM](#autostart--uwsm) below.

## Quick install

```sh
git clone https://github.com/CesarManzoCode/cesarmanzocode-rice.git
cd cesarmanzocode-rice
./install.sh --defaults
```

This installs the author's own configuration exactly: theme `monochrome`,
every component, Kitty/Brave/Dolphin/Rofi as apps, and the default
keybinds below — no prompts, packages installed via `pacman --needed`,
existing configs backed up first.

## Interactive install

```sh
./install.sh
```

Every prompt shows its default in brackets; press Enter to accept it.
Answering Enter at every single prompt reproduces the exact same result
as `--defaults`. You'll be asked, in order:

1. theme
2. which components to install (Hyprland config, Waybar, Rofi, SwayNC,
   Kitty, Hyprlock, Hypridle, wallpaper) — each optional
3. which applications to use (terminal, browser, file manager, launcher —
   any can be `none`)
4. keybinds for those apps and a few actions (floating, special
   workspace); type `--advanced` beforehand, or answer "yes" when asked,
   to also customize workspace/navigation binds
5. whether to install missing packages and take a backup
6. a final summary + confirmation

Other flags:

```sh
./install.sh --advanced      # also prompts for navigation/workspace binds
./install.sh --skip-packages # never touches pacman
./install.sh --dry-run       # print what would happen, change nothing
```

## Components are independent

Say no to a component and this rice leaves it alone entirely: nothing is
installed, no config is written, nothing is autostarted for it. Say no to
Waybar and `~/.config/waybar` is never touched; say no to Kitty and
`~/.config/kitty` is never touched (you can still set `kitty` — or
anything else — as your terminal app).

## Applications & keybinds

Your app choices and keybinds are **not** hardcoded anywhere in a theme or
in `config/`. They live in `~/.config/cesarmanzocode-rice/user.lua`,
written by `install.sh` and read by Hyprland itself every time it (re)loads
`~/.config/hypr/hyprland.lua`. See
[`user/user.lua.example`](user/user.lua.example) for the full schema — you
can hand-edit your copy directly instead of re-running the installer.

Keybind syntax is the obvious one: `SUPER+T`, `SUPER+SHIFT+S`,
`ALT+RETURN`. The installer validates it, rejects empty binds, and
detects conflicts:

```
Conflict:
  SUPER+B -> browser
  SUPER+B -> another action
```

`--defaults` never conflicts by construction.

### Author's defaults

| App          | Command             |
|--------------|----------------------|
| terminal     | `kitty`              |
| browser      | `brave`               |
| file manager | `dolphin`             |
| launcher     | `rofi -show drun`     |

| Action                     | Bind             |
|-----------------------------|------------------|
| open terminal                | `SUPER+T`        |
| close window                 | `SUPER+X`        |
| open browser                 | `SUPER+B`        |
| open file manager            | `SUPER+E`        |
| open launcher                 | `SUPER+R`        |
| toggle floating               | `SUPER+V`        |
| special workspace              | `SUPER+S`        |
| move window to special workspace | `SUPER+SHIFT+S` |
| clipboard picker (if cliphist) | `SUPER+period`   |
| focus direction                | `SUPER+arrows`   |
| workspace 1-10                  | `SUPER+1..0`     |
| move to workspace 1-10          | `SUPER+SHIFT+1..0` |
| move/resize window              | `SUPER+mouse L/R` |
| screenshot (full)               | `Print`          |
| screenshot (region)             | `SUPER+Print`    |

## Themes

Five themes ship today. Each is a self-contained visual package — palette,
geometry, wallpaper pack, motion tuning, Brave chrome — deliberately
differentiated in more than color (density, blur, borders, rounding,
transparency, and motion character all vary too), never a fork of the
shared install/apply/binds machinery.

| theme           | identity                                                        | docs                                            |
|-----------------|------------------------------------------------------------------|--------------------------------------------------|
| `monochrome`    | pure black/white/gray, no color at all — the original, closed    | (this README)                                     |
| `arctic-glass`  | cold, airy, translucent glass — heavy blur, floating panels, glide motion | [docs/themes/arctic-glass.md](docs/themes/arctic-glass.md) |
| `ember-forge`   | industrial, dense, warm carbon/copper — firmer edges, less blur, terse motion | [docs/themes/ember-forge.md](docs/themes/ember-forge.md) |
| `ivory-paper`   | the one light theme — editorial ivory/ink, minimal blur, precise motion | [docs/themes/ivory-paper.md](docs/themes/ivory-paper.md) |
| `violet-night`  | deep violet/blue-black, atmospheric, cinematic — expressive motion | [docs/themes/violet-night.md](docs/themes/violet-night.md) |

Switch with `./apply.sh <theme>` (see "Reapplying after `git pull`" below),
or pick one at install time (`./install.sh`, or `--defaults` for
`monochrome`).

Adding a theme never requires touching shared functionality — a theme is
just:

```
themes/<name>/hypr.lua          # colors + geometry (+ optional motion) for Hyprland
themes/<name>/waybar/colors.css
themes/<name>/rofi/colors.rasi
themes/<name>/swaync/colors.css
themes/<name>/kitty/colors.conf
themes/<name>/hyprlock.conf
themes/<name>/brave/manifest.json   # optional — see "Brave theme" below
wallpapers/<name>.png                     # canonical default
wallpapers/<name>-<variant>.png           # >= 3 variants, see "Wallpaper pack"
scripts/dev/generate_wallpaper_<name>.py  # dev-time generator, see below
```

No binds, no app choices, nothing functional belongs in a theme.
`tests/check_all_themes.py` enforces this contract generically for every
theme it finds under `themes/`, so a new theme is checked automatically
without editing the test suite.

`hypr.lua`'s optional `motion` table (read by `config/hypr/animations.lua`)
is how a theme gets its own animation character — spring
stiffness/damping and a couple of style percentages — without
re-implementing the animation tree. Omitting it (as `monochrome` does)
keeps the original hardcoded curves exactly as they were.

## Wallpaper pack

`wallpapers/` ships a small procedural pack per theme (>= 3 variants each),
generated entirely by code committed in this repo — no AI image
generation, no external service, no binary asset pipeline. Every theme's
generator (`scripts/dev/generate_wallpaper*.py`) shares its raster/PNG
plumbing from `scripts/dev/wallpaper_lib.py` (Python standard library
only — no Pillow, no ImageMagick, no network access) and is dev-time only:
never invoked by `install.sh`/`apply.sh`/`uninstall.sh`, so Python is not a
runtime dependency of the rice.

`monochrome`'s four variants:

| file                              | feel                                                    |
|------------------------------------|----------------------------------------------------------|
| `monochrome-fracture.png`          | hero/default — large dark diagonal planes, one or two thin white cuts |
| `monochrome-grid.png`              | a subtle technical perspective floor grid                |
| `monochrome-signal.png`            | abstract trajectories with precise turns and intersections |
| `monochrome-void.png`              | the most minimal of the four — a single off-center focal shape |

`wallpapers/monochrome.png` is a byte-identical copy of the chosen
default (`monochrome-fracture.png`) — the canonical name every install
path (`apply.sh`, `themes/<name>/hyprlock.conf`, tests) actually looks
for, so the four named variants above are additive and never break an
existing install. There is no wallpaper switcher/CLI/rotation — swapping
`wallpapers/monochrome.png` for one of the other three variants (and
re-running `./apply.sh`) is a manual, one-time choice.

Every variant uses a fixed seed, so `python3 scripts/dev/generate_wallpaper.py
<variant> <out.png>` is fully reproducible — the same script, variant and
resolution always produce byte-identical output (verified by
`tests/check_wallpapers.py`). Regenerate the whole pack with:

```
python3 scripts/dev/generate_wallpaper.py all wallpapers/
```

## Brave theme (browser chrome, not web content)

`themes/monochrome/brave/manifest.json` is a real Chromium/Brave
**theme** — a manifest-only extension (`manifest_version: 3`, a `theme`
key, no JavaScript, no `permissions`/`host_permissions`/`content_scripts`/
`background`) that recolors the browser's own chrome — frame, toolbar,
omnibox, tab strip — to match Waybar/Kitty/Rofi/SwayNC. It does **not**
theme web pages, does not make Brave transparent (web content stays
100% opaque; Hyprland's window opacity/blur rules never target Brave),
and never touches anything under `~/.config/BraveSoftware/` — no
`Preferences`, no `Local State`, no profile data of any kind, no
enterprise policy, no third-party extension.

Colors used (verified against Chromium's current
`chrome/browser/themes/browser_theme_pack.cc` `kOverwritableColorTable` —
every key below is live upstream, none are guessed or legacy):

| Key                              | Color     | Meaning                          |
|-----------------------------------|-----------|-----------------------------------|
| `frame` / `frame_inactive`         | `#0B0B0B` / `#050505` | window frame, focused/unfocused |
| `toolbar`                          | `#181818` | toolbar **and** the active tab (Chromium ties these together — there is no separate "active tab background" key; the active tab is drawn as a seamless continuation of the toolbar) |
| `toolbar_text` / `toolbar_button_icon` | `#F4F4F4` | toolbar text/icons |
| `omnibox_background` / `omnibox_text`  | `#101010` / `#F4F4F4` | address bar |
| `tab_text`                          | `#FFFFFF` | active tab's text |
| `background_tab` / `background_tab_inactive` | `#0B0B0B` / `#050505` | inactive tabs |
| `tab_background_text(_inactive)`    | `#9A9A9A` | inactive tabs' text |
| `bookmark_text`                     | `#F4F4F4` | bookmarks bar |
| `ntp_background` / `ntp_header` / `ntp_link` / `ntp_text` | `#050505` / `#0B0B0B` / `#F4F4F4` / `#F4F4F4` | new-tab page — Brave largely replaces the stock NTP with its own UI (News feed, stats, background image), so most of this may simply be overridden and invisible; that's a Brave-side limitation, not a bug in this theme. |

**Installed path.** `./apply.sh` stages the theme (unpacked, ready to
load) at:

```
~/.local/share/cesarmanzocode-rice/brave/monochrome/manifest.json
```

— under `$XDG_DATA_HOME/cesarmanzocode-rice/`, the same data root this
rice already uses for backups, so nothing depends on this git clone
staying at a fixed path. It is tracked like any other component
(`~/.config/cesarmanzocode-rice/manifest.d/brave.list`), so
`./uninstall.sh brave` removes exactly that staged copy and nothing
inside your Brave profile.

**Loading it into Brave is a manual, one-time step** — Brave has no
CLI/policy path to load an unpacked theme into a running profile
automatically, and this rice will not manipulate the profile to fake
one:

1. Open `brave://extensions`.
2. Enable **Developer mode** (top-right toggle).
3. Click **Load unpacked** and select
   `~/.local/share/cesarmanzocode-rice/brave/monochrome/`.
4. Open `brave://settings/appearance` and check that no Brave-side
   **color/theme variation** (e.g. a "Solarized"/preset accent, or "Use
   system theme") is overriding it — if the picker there is set to
   anything but "Use classic theme"/default, that setting can visually
   stomp this custom theme. (Exact wording depends on your installed
   Brave version — verify against your own `brave://settings/appearance`
   rather than this description.)

Optional, purely cosmetic: `brave://settings/appearance` also lets you
hide toolbar buttons you don't use (Leo, Rewards, VPN, Wallet, Sidebar,
Home, Cast, Share) for a cleaner bar — entirely up to you, never forced
by this rice.

Re-running `./apply.sh` after a theme color change just re-stages the
updated `manifest.json`; Brave only re-reads it after you reload the
extension from `brave://extensions` (or relaunch Brave).

## Local overrides (per machine)

`~/.config/cesarmanzocode-rice/local.lua` is never versioned and is
entirely optional. Use it for anything specific to one machine — monitor
layout, input device quirks:

```lua
return {
  monitors = {
    { output = "HDMI-A-1", mode = "1920x1080@75", position = "0x0", scale = "1" },
  },
  input = {
    kb_layout = "us",
  },
}
```

Without it, the default monitor rule is fully generic
(`hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })`)
and nothing is hardcoded to any specific output, resolution, refresh rate,
or username.

## Reapplying after `git pull`

```sh
git pull
./apply.sh
```

This reinstalls everything from the current repo + your existing
`user.lua`/`local.lua` — apps, binds, and local overrides all survive.
Also the safe way to pick up this project's Hyprland-runtime migration if
you installed an older version of this rice: it backs up whatever
`~/.config/hypr/hyprland.lua` currently exists, removes only the
`hyprland.conf` that a previous version of this rice generated (verified
against its own manifest, never a same-named file you wrote yourself), and
restores the previous config automatically if `hyprctl configerrors`
reports problems after reload.

```sh
./apply.sh monochrome          # switch theme, keep your apps/binds
./apply.sh monochrome waybar   # reapply just one component
```

`~/.config/cesarmanzocode-rice/state.sh` (which components + theme a bare
`./apply.sh` should reapply) is versioned via `STATE_SCHEMA_VERSION`.
When a new component is added in a later version of this rice, `apply.sh`
migrates an older, un-versioned `state.sh` forward once: it adds the new
component only if the file simply predates it and never had an opinion on
it either way, matching what a brand-new `install.sh` run would default
to — an explicit choice you already made (on *or* off) is never touched,
and once a `state.sh` carries a `STATE_SCHEMA_VERSION`, that guarantee is
exact (no more of the pre-versioning ambiguity). If a component you don't
want gets enabled by such a one-time migration, remove it from
`SELECTED_COMPONENTS` in `state.sh` — it stays off for good from then on.

## Uninstalling

```sh
./uninstall.sh              # remove everything this rice installed
./uninstall.sh waybar rofi  # remove just those components
```

Only removes files this rice actually wrote (tracked per-component under
`~/.config/cesarmanzocode-rice/manifest.d/`), offers to restore the most
recent backup for each, and never deletes `user.lua`/`local.lua`/
`state.sh` — remove those by hand if you want a completely clean slate.

## Backups

Before overwriting anything, existing files are copied to
`~/.local/share/cesarmanzocode-rice/backups/<timestamp>-{install,apply}/`,
preserving their original path underneath. Nothing is ever silently
deleted.

## Autostart & UWSM

Under UWSM, a daemon that ships a systemd `--user` unit should be started
by that unit, not by the compositor — running both would spawn a
duplicate instance on every login. So:

| Component        | Started by                    |
|-------------------|-------------------------------|
| Waybar            | `waybar.service`               |
| SwayNC             | `swaync.service`                |
| hyprpaper           | `hyprpaper.service`              |
| hypridle             | `hypridle.service`                |
| hyprpolkitagent       | `hyprpolkitagent.service`           |
| cliphist watchers      | Hyprland's `hyprland.start` hook (no upstream unit), via `uwsm app --` when available |

`apply.sh` enables each selected component's service the first time (never
touching one you already had enabled yourself) and restarts it on later
re-applies to pick up config changes; `uninstall.sh` disables only the
services it enabled.

## Project structure

```
config/            shared, theme-agnostic app configs + the Hyprland
                    Lua runtime modules (config/hypr/)
themes/<name>/     colors, geometry, motion, wallpaper — visual only, one
                    directory per theme (monochrome, arctic-glass, ...)
wallpapers/        committed PNG wallpapers, per theme (+ dev-only generators)
docs/themes/       one page per theme: identity, palette, motion, manual QA
scripts/           installer library code (bash), no code generation;
                    scripts/dev/ holds the (dev-time-only) wallpaper generators
user/              user.lua.example (schema for your real, unversioned copy)
tests/             bash -n / shellcheck / end-to-end checks, no framework
install.sh apply.sh uninstall.sh
```

## Why Lua?

Hyprland >= 0.55 reads `~/.config/hypr/hyprland.lua` as native Lua —
hyprlang (the older, hyprlang-text config format) is deprecated. `apply.sh`
installs a small entrypoint at that path
([`config/hypr/entrypoint.lua`](config/hypr/entrypoint.lua)) that just
`require()`s the real modules — `core`, `input`, `animations`, `windows`,
`layers`, `monitors`, `binds`, `autostart` — installed alongside it under
`~/.config/hypr/cesarmanzocode-rice/`, plus the active theme
(`theme.lua`, copied from `themes/<name>/hypr.lua`). Those modules call
Hyprland's own `hl.config()` / `hl.bind()` / `hl.dsp.*` / `hl.monitor()` /
`hl.window_rule()` API directly — there is no code generator, and no
separate `lua` interpreter involved; Hyprland parses and runs this Lua
itself. `user.lua`/`local.lua` are read from
`~/.config/cesarmanzocode-rice/` at that point, same as before the
migration.

## Testing

```sh
bash tests/run_tests.sh
```

Runs `bash -n` + `shellcheck` over every script, checks for
machine-specific hardcoding, and exercises `--dry-run`, `--defaults`,
component isolation, persistence, idempotence, and duplicate-bind
detection — all against throwaway `$HOME` directories, never your real
one.

## Known limitations

- No wallpaper switcher/CLI/rotation across a theme's own variants — see
  "Wallpaper pack".
- Waybar's clipboard/power buttons assume `cliphist`/`rofi` are present;
  if you disabled those components the buttons simply no-op instead of
  being removed from the bar.
- Automatic package installation only supports Arch/pacman.
- The Brave theme must be loaded manually via `brave://extensions`
  (see "Brave theme" above) — Brave has no automatable path to apply an
  unpacked theme to a running profile, and this rice intentionally never
  writes into `~/.config/BraveSoftware/`. Its new-tab-page colors may
  also be partly invisible, since Brave largely replaces the stock
  Chromium NTP with its own UI.
- This final polish pass's animation/motion changes (springs, per-layer
  `animation` styles, the new wallpaper pack, the SwayNC empty-icon CSS
  transform, and the Rofi listview border removal) are verified
  statically only (Lua parse + mock, JSON/CSS structure, PNG invariants) —
  this development environment is headless, with no real Hyprland/GTK/
  Rofi session to render against. See "Manual verification" below for
  what to actually look at on real hardware before calling this closed.

## Manual verification (real hardware only)

For `arctic-glass`/`ember-forge`/`ivory-paper`/`violet-night`, see each
theme's own "manual verification" section in `docs/themes/<name>.md` —
this section below is `monochrome`'s own, from when it was the only theme.

Everything below passed static checks (Lua mock, JSON/CSS structure, PNG
decoding) but needs eyes on the actual target machine (Hyprland 0.56.2 /
Wayland / 1920x1080@75Hz) to confirm it feels/looks right:

```sh
git pull && ./apply.sh
hyprctl configerrors   # expect: clean
```

- **Windows**: open/close a few apps — opening should read as a small,
  fast pop-in with a hint of physicality (never "grows from half size");
  closing should feel quicker and clean, no rebound. Drag/resize a window
  — it should track the cursor with no perceptible lag.
- **Workspaces**: `SUPER+1..0` — a short, clearly-directional slide+fade,
  not a full-screen slide, and fast even at 75Hz.
- **Special workspace**: `SUPER+S` — should feel like a distinct gesture
  from a normal workspace switch, with a touch more personality, but no
  obvious bounce.
- **Rofi** (`SUPER+R`): should pop in centered, no lateral slide, and
  confirm the dashed line reported around the selected result in the V3
  screenshot is actually gone (removed via `listview { border: 0; }` —
  see `config/rofi/config.rasi`) without losing any visual indication of
  which row is selected.
- **SwayNC** (its toggle bind): control center should slide in from the
  right edge; open it with an empty notification list and confirm the
  placeholder bell icon now reads as small (~32-40px, was much larger)
  with less dead vertical space around it.
- **Waybar**: unaffected by anything in this pass except its own layer
  popping in from the top on startup/reload — confirm that's not jarring
  and that nothing about it looks or feels different during normal use.
- **Wallpaper**: `wallpapers/monochrome.png` (== `monochrome-fracture.png`)
  is now the default — confirm it renders correctly behind Kitty/Rofi's
  blur, and that Waybar's strip and Rofi's usual position both sit over
  the deliberately-quieter zones baked into the image. Try the other
  three variants too (copy one over `wallpapers/monochrome.png` and
  `./apply.sh`) if you want to compare.
- **Border**: focus should switch between windows near-instantly; no
  animated/rotating border should be visible anywhere (there's no
  gradient border in this theme to animate).
