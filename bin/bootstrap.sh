#!/bin/sh
# bootstrap.sh: set up this workstation from a fresh clone.
#
#   1. render machine-specific fragments (detects the CPU temperature sensor)
#   2. symlink the configs into ~/.config with GNU Stow
#   3. install the default wallpaper if none is set yet
#   4. reload sway if it is already running
#
# Install the dependencies first (see packages.txt):
#   sudo pacman -S --needed - < packages.txt

set -eu

repo_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
cd "$repo_root"

echo "==> Rendering machine-specific fragments"
"$repo_root/bin/generate.sh"

echo "==> Stowing sway + waybar into \$HOME"
# --no-folding forces real ~/.config/{sway,waybar} dirs so real files (the
# wallpaper, the generated temperature.json) coexist with the symlinked configs.
# -R re-stows each run to stay idempotent: it unfolds any old single-symlink
# install and clears links to removed files, without ever touching real files.
#
# The repo's config takes precedence. Because stow refuses to clobber a real
# (non-symlink) file, any pre-existing config sitting on a target would abort
# the stow. So we detect those files first and, with a clear warning, ask
# before backing them up.
# Nothing is touched without an explicit "yes" (each conflict is renamed to a
# timestamped .bak, never deleted), and the symlinks from a previous install are
# never flagged, so re-runs stay silent.
if [ -t 2 ]; then
    c_red=$(printf '\033[1;31m'); c_bold=$(printf '\033[1m'); c_off=$(printf '\033[0m')
else
    c_red=''; c_bold=''; c_off=''
fi

conflicts=$(
    for pkg in sway waybar; do
        find "$pkg" ! -type d | while IFS= read -r src; do
            target="$HOME/${src#"$pkg"/}"
            # A real file (not one of our own symlinks) squatting on a target.
            if [ -f "$target" ] && [ ! -L "$target" ]; then
                printf '%s\n' "$target"
            fi
        done
    done
)

if [ -n "$conflicts" ]; then
    {
        printf '\n%s\n' "${c_red}==============================================================${c_off}"
        printf '%s\n'   "${c_red}  WARNING  real config files already exist at these targets:${c_off}"
        printf '%s\n'   "${c_red}==============================================================${c_off}"
        printf '%s\n' "$conflicts" | while IFS= read -r f; do
            printf '    %sx%s %s\n' "$c_red" "$c_off" "$f"
        done
        printf '%s\n'   "They are real files, not our symlinks, so stow will not overwrite"
        printf '%s\n'   "them. They will be renamed to timestamped .bak copies (never deleted)"
        printf '%s\n'   "so the repo's config can be linked in; restore one by moving it back."
        printf '\n%s'   "${c_bold}Back up the files listed above and install the repo's config? [y/N] ${c_off}"
    } >&2
    read -r reply 2>/dev/null < /dev/tty || read -r reply 2>/dev/null || reply=n
    case "$reply" in
        y | Y | yes | YES | Yes)
            stamp=$(date +%Y%m%d-%H%M%S)
            printf '%s\n' "$conflicts" | while IFS= read -r f; do
                bak="$f.bak-$stamp"
                mv -- "$f" "$bak"
                echo "==> backed up $f -> $bak"
            done
            ;;
        *)
            echo "Aborted: nothing was changed. Approve the prompt (or move them yourself) and re-run." >&2
            exit 1
            ;;
    esac
fi

if ! stow -R --no-folding --target="$HOME" sway waybar; then
    echo "stow failed unexpectedly; see the message above." >&2
    exit 1
fi

# Install the default wallpaper on first run (never overwrite a custom one).
wallpaper="$HOME/.config/sway/wallpaper"
if [ ! -e "$wallpaper" ]; then
    echo "==> Installing default wallpaper at $wallpaper"
    mkdir -p "$HOME/.config/sway"
    cp "$repo_root/wallpapers/SR-71-Blackbird-Night-grainy.jpg" "$wallpaper"
fi

if command -v swaymsg >/dev/null 2>&1 && [ -n "${SWAYSOCK:-}" ]; then
    echo "==> Reloading sway"
    swaymsg reload || true
fi

echo "Done."
