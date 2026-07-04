#!/bin/sh
# detect-hwmon.sh: detect the boot-stable hwmon path for the CPU package
# temperature sensor, for Waybar's `temperature` module.
#
# Prints two eval-able lines on stdout (warnings go to stderr):
#   HWMON_PATH_ABS=/sys/devices/platform/coretemp.0/hwmon
#   HWMON_INPUT=temp1_input
#
# Waybar reads  <HWMON_PATH_ABS>/<hwmonN>/<HWMON_INPUT>.  The hwmonN number is
# not stable across boots, but its parent directory is, so we emit the parent
# (hwmon-path-abs) plus the input file name.

set -eu

# Preferred sensor drivers, best first: real CPU package sensors, then fallbacks.
CPU_DRIVERS='coretemp k10temp zenpower'
FALLBACK_DRIVERS='acpitz thinkpad cpu_thermal'

# Echo the /sys/class/hwmon/hwmonN dir whose `name` equals $1, or return 1.
hwmon_dir_for_driver() {
    _driver=$1
    for _h in /sys/class/hwmon/hwmon*; do
        [ -e "$_h/name" ] || continue
        if [ "$(cat "$_h/name")" = "$_driver" ]; then
            echo "$_h"
            return 0
        fi
    done
    return 1
}

# Echo the tempN_input basename to use, given a resolved hwmon dir ($1).
pick_input() {
    _dir=$1
    # Prefer a labelled package/die sensor.
    for _lbl in "$_dir"/temp*_label; do
        [ -e "$_lbl" ] || continue
        case "$(cat "$_lbl")" in
            'Package id 0'|'Tctl'|'Tdie')
                _base=$(basename "$_lbl")          # tempN_label
                echo "${_base%_label}_input"       # tempN_input
                return 0
                ;;
        esac
    done
    # Otherwise the first temperature input present, else a sane default.
    for _f in "$_dir"/temp*_input; do
        [ -e "$_f" ] || continue
        basename "$_f"
        return 0
    done
    echo temp1_input
}

_found=
for _driver in $CPU_DRIVERS $FALLBACK_DRIVERS; do
    if _hwmon=$(hwmon_dir_for_driver "$_driver"); then
        _real=$(readlink -f "$_hwmon")             # .../coretemp.0/hwmon/hwmon5
        _abs=$(dirname "$_real")                    # .../coretemp.0/hwmon
        _input=$(pick_input "$_real")
        _found=1
        break
    fi
done

if [ -z "$_found" ]; then
    echo "detect-hwmon: no CPU temperature sensor found; emitting safe default" >&2
    echo 'HWMON_PATH_ABS=/sys/class/hwmon/hwmon0'
    echo 'HWMON_INPUT=temp1_input'
    exit 1
fi

echo "HWMON_PATH_ABS=$_abs"
echo "HWMON_INPUT=$_input"
