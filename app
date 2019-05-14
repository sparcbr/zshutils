#!/bin/zsh
source ../zsh_main
include -r functions

ABORT='sexit'
function sexit()
{
    set +x
    exit $1
}
[[ "$1" == '-d' ]] && { set -x; shift }
[[ $# -lt 1 ]] && { print commands: home wallpaper focuswindow focusactivity uninstall install; sexit 1 }

function findApk()
{
	#@TODO find most recent apk in case more than one returns
    local result=("${(@f)$(run adb shell pm list packages -3 $1 | cut -f2 -d: | tr -d '\r')}")
    echo $result[1]
}
function listPkg()
{
    local flags pkgs sorted sortedPkgs pkg tmp n=1
    if [[ "$1" == "-a" ]]; then
        shift
        flags=""
    else
		flags="-3"
    fi
	sorted=() ; sortedPkgs=()
	pkgs=$(run adb shell pm list packages $flags "$@")
	tmp=$?
	[[ -n $pkgs ]] || return $tmp
	pkgs=(${(@f)$(echo $pkgs | cut -f2 -d: | tr -d '\r')})
	for pkg in $pkgs; do
		tmp=$(
			adb shell dumpsys package $pkg | awk -F'=' '/lastUpdateTime/{print $2}' | tr -d '\r\n'
		)
		sorted+=("${(@f)tmp}¬$n")
		((n++))
	done
	sorted=("${(@O)sorted}")
	for tmp in $sorted; do
		explode "$tmp" '¬'
		timestamps+=("${s[1]}")
		n=$s[2]
		sortedPkgs+=("${pkgs[$n]}")
	done
	echo ${sortedPkgs}
}
function listRunningApk()
{
	apks=$(run adb shell ps | awk "\$9 ~ /${@:-.}/{print \$9}" | tr -d "\r" | tr -d "\t")
	echo "${(@f)apks}"
}

function getMainActivity()
{
	local arr=($(listApkActivities $1))
	echo ${arr[1]}
}

function listApkActivities()
{
	adb shell dumpsys package $1 | grep -B 10 category\.LAUNCHER | grep -o '[^ ]*/[^ ]*'
}

function startApk()
{
	local act

	if [[ "$1" =~ "/" ]]; then
		act=$1
   elif [[ -n "$2" ]]; then
		act=$1/$2
	else
		act=$(chooser $(listApkActivities $apk))
	fi
	run adb shell am start -n $act
}
function stopApk()
{
    foreach p; do
	    run adb shell am force-stop $p
    done
}
function enDisApk()
{
    local cmd=$1
    [[ $cmd == 'en' ]] && cmd='enable'
    [[ $cmd == 'dis' ]] && cmd='disable'
    shift
    foreach p; do
	    run adb shell pm $cmd $p
    done
}
function installApk()
{
    run adb push $1 /data/local/tmp/$1
    run adb shell pm install -t -r /data/local/tmp/$1
}
# Get package name from apk file
function getPkg()
{
    chkCmdInst aapt
    aapt dump badging $1 | grep package:\ name  | cut -f2 -d\'
}

#@TODO
function getLocalApkVersion()
{
    chkCmdInst aapt
    aapt dump badging $1 | grep package:\ name  | cut -f4,6 -d\'
}
function getPkgVersion()
{
    run adb shell dumpsys package $pkg | grep versionName
}
function uninstallApk()
{
    if [[ "$1" == "-a" ]]; then
		  shift 
		  args=$(listPkg "$@")
    elif [[ -n "$1" ]]; then
        args="$@"
    else
        chosen=$(chooser $(listPkg))
        args=$chosen
    fi

    for arg in $args; do
        if [[ $(getext "$arg") == "apk" ]]; then
            uninstallPkg $(getPkg $arg)
        else
            uninstallPkg "$arg"
        fi
    done
}

# pm uninstall: removes a package from the system. Options:
#    -k: keep the data and cache directories around after package removal.
#
# pm clear: deletes all data associated with a package.
function uninstallPkg()
{
    local pkgs

    if [[ -n "$1" ]]; then
        pkgs="$@"
    else
        pkgs=$(listPkg)
    fi

    #@TODO -k: keep the data and cache directories around after package removal.
    for p in ${=pkgs}; do
    	run adb shell pm uninstall -k $p
    done
}

cmd=$1
shift
case "$cmd" in
	(focuswindow|focus)
        #cur=$(adb shell dumpsys window windows | awk '/mCurrentFocus/{print $3}' | cut -d'}' -f1)
	;;
	(focusactivity)
		#run adb shell dumpsys activity activities | grep mFocusedActivity
	;;
	(home)
		action=android.intent.action.MAIN
		category=android.intent.category.HOME
		run adb shell am start -a $action -c $category
	;;
	(en|enable|dis|disable)
        enDisApk $cmd $@
	;;
	(install|inst)
        if [[ $(getext "$1") != "apk" ]]; then
            echo needs a APK
            sexit 1
        fi

        installApk $1
	;;
	(list) listPkg "$@" | tr ' ' '\n'
	;;
	(poweroff)
        run adb shell am start -a android.intent.action.ACTION_REQUEST_SHUTDOWN
   ;;
	(ps) lnecho $(listRunningApk ${1:-inbramed}) 
	;;
	(stop|restart)
		apk=$(listRunningApk ${1:-inbramed})
		stopApk $apk
		if [[ "$cmd" == "restart" ]]; then
				startApk $apk
		fi
	;;
	(uninstallall|removeall|delall|deleteall)
        uninstallApk -a
	;;
	(uninstall|remove|rm|del(ete)?)
        if [[ "$1" == "-a" ]]; then
            shift
            uninstallApk -a
        else
            uninstallApk "$@"
        fi
	;;
	(wallpaper|anim|animation) #@TODO use rsync or md5
        ro=$(run adb shell mount | awk '/^\/dev\/block\/mmcblk0p2/{print $4}') || abort
        if [[ ${ro:0:2} == 'ro' ]]; then
            run adb shell mount -o remount,rw /system || abort
        fi
		techo -c head Transfering wallpaper
		run adb push $HOME/PeD/logo.png /data/system/users/0/wallpaper || abort

		techo -c head Transfering boot animation
		run adb push $HOME/PeD/android/bootanimation.zip /system/media || abort
	;;
	(hidekeyb|hidekeyboard)
		adb shell input keyevent 111
	;;
	(start|*)
		#apk=${1:-$(findApk "inbramed.")}
		#search=${1:-"inbramed."}
      apks=$(listPkg $1)
      apk=$(chooser ${=apks})
		#activity=${2:-$(getMainActivity $apk)}
		startApk $apk
	;;
esac

sexit $?
