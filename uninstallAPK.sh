#!/bin/zsh
[[ ! -n "$ZSH_ALIAS_VER" ]] && . $ZSH_LIBS/zsh_aliases
include file
ext=`getext "$1"`
if [[ -n $ext ]] ; then
    if [[ $ext == "apk" ]]; then
        #apkname=`basename $1`
        pkgname=$(getpkgname $1)
    else
        pkgname="$1"
    fi
    adb shell pm uninstall $pkgname
else
    for pkg in `adb shell pm list packages $1  | cut -f2 -d: | tr -d '\r'`; do
        adb shell pm uninstall $pkg
    done
fi
