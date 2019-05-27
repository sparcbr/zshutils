#!/bin/zsh
notify-send -t 15000 "Starting $0 apps"
cd `dirname $0`
./set_def_sound_source.sh
$HOME/xdata/radeon-profile/radeon-profile/radeon-profile &
rpid=$!
sleep 2
xdotool search --all --sync --onlyvisible --pid $! --name 'Radeon Profile'  mousemove --sync --window '%1' 20 265 click 1 key Down key Return mousemove --sync --window '%1' 20 170 click 1 windowminimize

