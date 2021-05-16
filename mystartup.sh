#!/bin/zsh
#notify-send -t 15000 "Starting $0 apps"
cd $0:P:h
if [[ $1 == 'post' ]]; then
	notify-send 'Resuming'
	sleep 2
	#if ! ping -i 0.2  -w 2 -W 0.1 -c 2 -rn 192.168.1.1; then
		#notify-send 'Restarting networking'
		#sudo service networking restart
		#sudo service network-manager restart
	#fi
else
	xhost +
	#$HOME/bin/set_def_sound_source.sh
	ssh-add ~/.ssh/id_rsa
	setopt extendedglob
	#if [[ "$(lspci | grep VGA)" != (#i)*nvidia*(#q) ]]; then
	#	include proc
	#	rpid=$(pidof radeon-profile) || {
	#		$HOME/xdata/radeon-profile/radeon-profile/radeon-profile &
	#		rpid=$!
	#		xdotool search --all --sync --onlyvisible --pid $rpid --name 'Radeon Profile'  mousemove --sync --window '%1' 20 265 click 1 key Down key Return mousemove --sync --window '%1' 20 170 click 1 #windowminimize
	#	}
	#fi
	pidof -q redshift-gtk || redshift-gtk &!
	pidof -q kdeconnect-indicator || kdeconnect-indicator &!
	if [[ $USER == 'sparc' ]]; then
		dropbox start &
		cpuconfig &
	fi
fi
brightness
