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
- Hyprland, `lua` (used to generate `hyprland.conf` from the Lua modules —
  see [Why Lua?](#why-lua) below)
- Bash — no Python/Node/Ansible/Nix/Stow/chezmoi required at runtime

Stack this rice targets: Hyprland, Waybar, Rofi, SwayNC, hyprpaper,
hyprlock, hypridle, hyprpolkitagent, Kitty, PipeWire/WirePlumber, grim,
slurp, cliphist, JetBrains Mono Nerd Font, Noto fonts.

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
written by `install.sh` and read every time `apply.sh` regenerates
`hyprland.conf`. See [`user/user.lua.example`](user/user.lua.example) for
the full schema — you can hand-edit your copy directly instead of
re-running the installer.

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

Only `monochrome` ships today, but adding another theme never requires
touching shared functionality — a theme is just:

```
themes/<name>/hypr.lua          # colors + geometry for Hyprland
themes/<name>/waybar/colors.css
themes/<name>/rofi/colors.rasi
themes/<name>/swaync/colors.css
themes/<name>/kitty/colors.conf
themes/<name>/hyprlock.conf
wallpapers/<name>.png
```

No binds, no app choices, nothing functional belongs in a theme.

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
(`monitor = ,preferred,auto,auto`) and nothing is hardcoded to any
specific output, resolution, refresh rate, or username.

## Reapplying after `git pull`

```sh
git pull
./apply.sh
```

This regenerates everything from the current repo + your existing
`user.lua`/`local.lua` — apps, binds, and local overrides all survive.

```sh
./apply.sh monochrome          # switch theme, keep your apps/binds
./apply.sh monochrome waybar   # reapply just one component
```

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

## Project structure

```
config/            shared, theme-agnostic app configs
themes/monochrome/ colors, geometry, wallpaper — visual only
wallpapers/        committed PNG wallpapers (+ dev-only generator script)
scripts/           installer library code, the Hyprland-conf generator
user/              user.lua.example (schema for your real, unversioned copy)
tests/             bash -n / shellcheck / end-to-end checks, no framework
install.sh apply.sh uninstall.sh
```

## Why Lua?

Hyprland reads a config format called hyprlang, not Lua. What lives under
`config/hypr/*.lua` is a small DSL (`config/hypr/hl.lua`) that lets the
Hyprland config be *written* in Lua while still being *read* by Hyprland
as a normal, generated `hyprland.conf`. `scripts/generate-hyprland-conf.lua`
composes core/input/animations/windows/monitors/binds/autostart modules
plus the active theme and your `user.lua`/`local.lua` into one file — run
automatically by `apply.sh`. This keeps the config maintainable and
modular without inventing a new runtime dependency beyond the `lua`
interpreter itself.

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

- Only the `monochrome` theme exists so far.
- Waybar's clipboard/power buttons assume `cliphist`/`rofi` are present;
  if you disabled those components the buttons simply no-op instead of
  being removed from the bar.
- Automatic package installation only supports Arch/pacman.
