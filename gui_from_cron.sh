#!/bin/sh
[ "$#" -lt 1 ] && echo "Usage: $0 program options" && exit 1

program="$1"
shift

user=$(whoami)
env_reference_process=$( pgrep -u "$user" xfce4-session || pgrep -u "$user" ciannamon-session || pgrep -u "$user" gnome-session || pgrep -u "$user" gnome-shell || pgrep -u "$user" kdeinit | head -1 )

export DBUS_SESSION_BUS_ADDRESS=$(cat /proc/"$env_reference_process"/environ | grep --null-data ^DBUS_SESSION_BUS_ADDRESS= | sed 's/DBUS_SESSION_BUS_ADDRESS=//')
export DISPLAY=$(cat /proc/"$env_reference_process"/environ | grep --null-data ^DISPLAY= | sed 's/DISPLAY=//')
"$program" "$@"

