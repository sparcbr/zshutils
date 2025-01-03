#!/bin/zsh
log=/tmp/udev.log
touch $log
#app port
echo action=$ACTION "$@" >> $log
echo "0=$0" >> $log
echo adb_user=$adb_user >> $log
echo 'env:' >> $log
/usr/bin/printenv >> $log
echo "adb_user=$adb_user" >> $log
echo "DEVICE=$DEVICE" >> $log
echo "ACTION=$ACTION" >> $log
exit
