#!/bin/zsh
#notify-send -t 15000 "Starting $0 apps"
cd `dirname $0`
xhost +
#$HOME/bin/set_def_sound_source.sh
ssh-add ~/.ssh/id_rsa.1
setopt extendedglob
if [[ "$(lspci | grep VGA)" != (#i)*nvidia*(#q) ]]; then
	include proc
	rpid=$(pidof radeon-profile) || {
		$HOME/xdata/radeon-profile/radeon-profile/radeon-profile &
		rpid=$!
		xdotool search --all --sync --onlyvisible --pid $rpid --name 'Radeon Profile'  mousemove --sync --window '%1' 20 265 click 1 key Down key Return mousemove --sync --window '%1' 20 170 click 1 #windowminimize
	}
fi
