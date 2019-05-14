#!/bin/zsh
for sysdevpath in $(find /sys/bus/usb/devices/usb*/ -name dev); do
    (

        syspath="${sysdevpath%/dev}"
        echo "syspath: $syspath"
        devname="$(udevadm info -q name -p $syspath)"
        echo "devname: $devname"
       # [[ "$devname" == "bus/"* ]] && continue
        udevadm info -q property --export -p $syspath --export-prefix=UDEV_
		[[ "$UDEV_ID_INPUT_MOUSE" == "1" ]] && continue
	#	[[ "$UDEV_SUBSYSTEM" == "" ]] && continue
        eval "$(udevadm info -q property --export -p $syspath)"
        [[ -z "$ID_SERIAL" ]] && continue
		[[ "$ID_" ]] 
        echo "/dev/$devname - $ID_SERIAL"
		echo ""
    )
done
