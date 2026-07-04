# sway-workstation

Reproducible Arch Linux workstation setup built around Sway, Waybar, iwd, and a
minimal terminal-first workflow.

Tested on a ThinkPad (Arch Linux + Sway); it should work on other hardware too,
since the one machine-specific value (the CPU temperature sensor path) is
detected best-effort with Intel/AMD/ACPI fallbacks.

![The Sway desktop: the Waybar status bar across the top, over the SR-71 Blackbird wallpaper](assets/screenshot.png)

Dotfiles are managed with [GNU Stow](https://www.gnu.org/software/stow/): each
top-level package directory mirrors `$HOME`, so deploying is a single `stow`
command that symlinks everything into place. The **one** hardware-specific value
(the CPU temperature sensor path) is detected per machine and rendered into a
small fragment that Waybar includes, so the same repo works on any machine with
no paths to edit by hand.

## Highlights

- **Stow-managed dotfiles**: each package mirrors `$HOME`, so deploying is just symlinks. Reversible, and every change shows up in Git.
- **Machine facts are detected, not hardcoded**: the CPU temperature sensor path is auto-detected per machine and rendered into a generated fragment kept out of the repo.
- **Keyboard-first Sway**: home-row navigation, plus binds for screenshots, volume, brightness, lock, and notifications.
- **Two-layer workspaces**: 1-10 on `$mod`, 11-20 on `$mod`+Alt.
- **Reproducible from scratch**: `packages.txt` and an idempotent `bootstrap.sh` (detect, stow, reload), with no hidden manual steps.

## Keybindings

`$mod` is the Super (logo) key. These are the custom binds layered on top of the
stock Sway defaults; for the defaults (`$mod+Return` terminal, `$mod+Shift+q`
kill, `$mod`+`h`/`j`/`k`/`l` focus, `$mod+r` resize, `$mod+Shift+c` reload) see
`man 5 sway`.

| Keys | Action |
| --- | --- |
| `$mod+d` / `$mod+t` | Launcher: run / app (`drun`) |
| `$mod+n` / `$mod+m` | Keyboard layout latam / us (remembered across reloads) |
| `$mod+Shift+x` | Lock screen |
| `$mod+u` / `$mod+i` | Screenshot region / whole screen (also copied to clipboard) |
| `$mod+Shift+p` / `$mod+Shift+o` | Volume up / down |
| `$mod+Shift+m` | Mute toggle |
| `$mod+Shift+b` / `$mod+Shift+n` | Brightness -10% / +10% |
| `$mod+Shift+f` / `$mod+Shift+g` | Brightness -5% / +5% |
| `$mod+o` / `$mod+p` | Notifications: restore last / dismiss all |
| `$mod+1`…`0` | Workspaces 1-10 |
| `$mod+Alt+1`…`0` | Workspaces 11-20 |
| `$mod+Shift+`(number) | Move focused window to that workspace |
| `$mod+Tab` | Toggle last-used workspace |
| `$mod+Ctrl+h` / `$mod+Ctrl+l` | Previous / next workspace on this output |
| `$mod`+scroll | Cycle workspaces on this output |

Volume, brightness, and mute also work on the physical `XF86` media keys,
including on the lock screen.

## Layout

```
.
├── bin/
│   ├── detect-hwmon.sh    # find the boot-stable CPU temp sensor (Intel/AMD/fallback)
│   ├── generate.sh        # render machine-local fragments from templates/
│   └── bootstrap.sh       # generate + stow + reload, in one shot
├── templates/
│   └── waybar/
│       └── temperature.json.in   # temperature module with ${HWMON_*} placeholders
├── wallpapers/            # default wallpaper (installed to ~/.config/sway/wallpaper on setup)
│   └── SR-71-Blackbird-Night-grainy.jpg
├── sway/                  # stow package "sway"
│   └── .config/sway/config
├── waybar/                # stow package "waybar"
│   └── .config/waybar/
│       ├── config         # includes ~/.config/waybar/temperature.json
│       └── style.css
└── packages.txt
```

## Install

```sh
git clone https://github.com/carlosplanchon/sway-workstation ~/sway-workstation
cd ~/sway-workstation

# 1. dependencies (official repos)
sudo pacman -S --needed - < packages.txt
# ...plus one AUR package, the iwd Wi-Fi GUI:
#    yay -S iwgtk        # or: paru -S iwgtk

# 2. detect hardware, render fragments, symlink everything, reload sway
./bin/bootstrap.sh
```

`bootstrap.sh` is idempotent. If a config already exists as a **real file**
(not a symlink), it warns and offers to back it up (renamed to a timestamped
`.bak`, never deleted) before linking the repo's config in. Decline the prompt
to leave everything untouched.

To remove all symlinks: `stow -D --target="$HOME" sway waybar`.

## How it works

Everything in the repo is static and stowed as-is, **except** two machine-local
pieces: the wallpaper (see Notes) and the Waybar `temperature` module, whose
sensor path differs per machine:

1. `bin/detect-hwmon.sh` scans `/sys/class/hwmon` for the CPU package sensor
   (`coretemp` on Intel, `k10temp`/`zenpower` on AMD, with `acpitz`/`thinkpad`
   fallbacks) and prints the boot-stable `hwmon-path-abs` + `input-filename`.
2. `bin/generate.sh` fills `templates/waybar/temperature.json.in` with those
   values (via `envsubst`) and writes `~/.config/waybar/temperature.json`.
3. The main Waybar config pulls it in with
   `"include": ["~/.config/waybar/temperature.json"]`.

The generated fragment lives in `~/.config` (outside the repo) and is
`.gitignore`d, so hardware paths are never committed.

## Editing

- **Config/style**: edit the files under `sway/` or `waybar/` directly; they
  are symlinked live.
- **Temperature module**: edit `templates/waybar/temperature.json.in`, then
  re-run `./bin/generate.sh` and reload Waybar (`pkill -SIGUSR2 waybar`).

## Notes

- **Wallpaper** is a local file at `~/.config/sway/wallpaper` (no extension:
  swaybg reads the format from the file itself, so any JPG or PNG works without
  renaming). `bootstrap.sh` installs the repo default (`wallpapers/`) there on
  first run and never overwrites it. To use your own:
  `cp your-image ~/.config/sway/wallpaper`, then reload Sway (`$mod+Shift+c`).
- **Keyboard layout** is persisted to `~/.local/state/sway-kb-layout` and
  re-applied on every reload; toggle with `$mod+n` (latam) / `$mod+m` (us).
- **Fonts**: `cantarell-fonts` + `otf-font-awesome` + `ttf-nerd-fonts-symbols`.
  If glyphs render as boxes, check the family names in `style.css`.
