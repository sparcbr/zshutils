#!/bin/zsh
set -x
typeset -l arg # lowercase var
for m in "$@"; do
	arg=$m
	if [[ "$arg" =~ "usbexthd|usbext4?" ]]; then
		name=UsbExt4
	else
		name=$arg
	fi
	dev=`mount | grep $name | head -n 1 | cut -f1 -d' '`
	sudo eject $dev
done
set +x
