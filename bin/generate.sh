#!/bin/sh
# generate.sh: render machine-specific Waybar fragments from templates.
#
# Currently renders the `temperature` module: the CPU sensor path is detected
# per machine (see detect-hwmon.sh) and written to a machine-local fragment that
# the main Waybar config pulls in via "include". The fragment lives in
# ~/.config (outside the repo) so it is never committed.

set -eu

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH='' cd -- "$script_dir/.." && pwd)

# Detect the CPU temperature sensor for this machine.
eval "$("$script_dir/detect-hwmon.sh")"
export HWMON_PATH_ABS HWMON_INPUT

# Render the temperature fragment. The single-quoted list is envsubst's
# SHELL-FORMAT argument (variable *names*, not shell expansions), so only these
# two vars are substituted; anything else in the template is left untouched.
mkdir -p "$HOME/.config/waybar"
# shellcheck disable=SC2016
envsubst '${HWMON_PATH_ABS} ${HWMON_INPUT}' \
    < "$repo_root/templates/waybar/temperature.json.in" \
    > "$HOME/.config/waybar/temperature.json"

echo "generated ~/.config/waybar/temperature.json"
echo "  hwmon-path-abs = $HWMON_PATH_ABS"
echo "  input-filename = $HWMON_INPUT"
