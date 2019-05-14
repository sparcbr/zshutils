#!/bin/zsh
set -x
apkpath=$1
apkname=`basename $apkpath`
pkgname=$(getpkgname $apkpath)
uninstallAPK.sh $pkgname
adb push $apkpath /data/local/tmp/$apkname && \
    adb shell pm install -t -r "/data/local/tmp/$apkname"
