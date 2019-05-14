#!/bin/zsh
[[ ! -n "$ZSH_ALIAS_VER" ]] . $HOME/.zsh_aliases
if [[ "$1" != "-a" ]]; then
    ext=`getext "$1"`
    if [[ $ext == "apk" ]]; then
        #apkname=`basename $1`
        pkgname=$(getpkgname $1)
    else
        pkgname="$1"
    fi
    adb shell pm uninstall $pkgname
else
    for pkg in `adb shell pm list packages inbramed | cut -f2 -d: | tr -d '\r'`; do
        adb shell pm uninstall $pkg
    done
fi
