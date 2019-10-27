#!/bin/zsh
cd $(dirname "$0")
if [ -z "$ZSH_MAIN_INFO" ] || [ -z "$ZSH_LIBS" ]; then
	[ -z "$ZSH_LIBS" ] && [ -f 'zsh_main' ] && ZSH_LIBS="$PWD"
	source $ZSH_LIBS/zsh_main || { echo "zsh_main not found" ; exit 127 }
fi
include -qr functions
include -qr file
include -qr android
include -ql debug

zparseopts -D -M - n=dryrun D::=debug d::=D i=interactive
if [[ -n $dryrun ]] || { [[ -n $DRYRUN ]] && ((DRYRUN)) }; then
	DRYRUN=-n
fi
if (($#debug)); then
	set -x
	DEBUG=${debug[1]:2}
	if [[ $DEBUG != [0-9]## ]]; then
		[[ -n $DEBUG ]] && set - $DEBUG "$@"
		DEBUG=1
	fi
	set +x
fi
((DEBUG)) && set -x

ABORT='sexit'
function sexit()
{
	((interactive)) && return
	#echo $ZSH_EVAL_CONTEXT
	[[ -o xtrace ]] && set +x
	exit $1
}
[[ -n $interactive ]] && interactive=1

cmds=(focuswindow\|focus focusactivity home en\|enable\|dis\|disable install\|inst list poweroff stop\|restart uninstallall\|removeall\|delall\|deleteall uninstall\|remove\|rm\|del\(ete\)\? wallpaper\|anim\|animation hidekeyb\|hidekeyboard start immersive log\|logcat)

(($# || interactive)) || { usage ; sexit 1 }

function usage()
{
	print -l ${(o)cmds}
}

function listPkg()
{
	local ret flags pkgs all sorted sortedPkgs pkg tmp n=1 date
	zparseopts -D -M - a=all d=date
	[[ -n $all ]] || flags="-3"
	sorted=() ; sortedPkgs=()
	pkgs=($(run $DRYRUN adb shell pm list packages $flags "$@" | tr -d '\r')) || return
	(($#pkgs)) || return 10
	pkgs=(${pkgs#package:})
	for pkg in $pkgs; do
		local _date=$(
			adb shell dumpsys package $pkg | \
				awk -F'=' '/lastUpdateTime/{print $2}' | \
				head -n1 | tr -d '\r\n'
		)
		sorted+=("${(f)_date} $n")
		((n++))
	done

	sorted=("${(@O)sorted}")

	for tmp in $sorted; do
		explode -v tmp "$tmp" ' '
		n=$tmp[3]
		if [[ -n $date ]]; then
			sortedPkgs+=("${pkgs[$n]} ${tmp[1,2]}")
		else
			sortedPkgs+=("${pkgs[$n]}")
		fi
	done
	print -l $sortedPkgs
}
function listRunningApk()
{
	run $DRYRUN adb shell ps | awk "\$9 ~ /${@:-.}/{print \$9}" | tr -d $'\r\t'
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
		act="$1"
   elif [ -n "$2" ]; then
		act="$1"/"$2"
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
    local cmd="$1"
    [ $cmd = 'en' ] && cmd='enable'
    [ $cmd = 'dis' ] && cmd='disable'
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

#@TODO
function getLocalApkVersion()
{
	local v
	chkCmdInst aapt || return
	v=$(aapt dump badging $1 | grep package:\ name | cut -f4,6 -d\')
	[[ -n $v ]] && explode $v "'"
}

function getPkgVersion()
{
	run $DRYRUN adb shell dumpsys package $1 | grep versionName
}
function uninstallApk()
{
    #if [[ "$1" = '-a' ]]; then
	#	shift 
	#	args=("${(@)$(listPkg -a $@)}")
    #else
		args=("${(@)$(chooser -s_ -f1 "${(@)$(listPkg -ad $@)}")}")
	#fi

function sendkey() {
	typeset -A keys=(
		# 1 'MENU'  <- ??
		2 'SOFT_RIGHT' 3 'HOME' 4 'BACK' 5 'CALL' 6 'ENDCALL'
		7 'KEY_0' 8 'KEY_1' 9 'KEY_2' 10 'KEY_3' 11 'KEY_4'
		12 'KEY_5' 13 'KEY_6' 14 'KEY_7' 15 'KEY_8' 16 'KEY_9'
		17 'STAR' 18 'POUND'
		19 'DPAD_UP' 20 'DPAD_DOWN' 21 'DPAD_LEFT' 22 'DPAD_RIGHT'
		23 'DPAD_CENTER'
		24 'VOLUME_UP' 25 'VOLUME_DOWN'
		26 'POWER' 27 'CAMERA' 28 'CLEAR'
		29 'A' 30 'B' 31 'C' 32 'D' 33 'E' 34 'F' 35 'G' 36 'H' 37 'I' 38 'J'
		39 'K' 40 'L' 41 'M' 42 'N' 43 'O' 44 'P' 45 'Q' 46 'R' 47 'S' 48 'T'
		49 'U' 50 'V' 51 'W' 52 'X' 53 'Y' 54 'Z'
		55 'COMMA' 56 'PERIOD'
		57 'ALT_LEFT' 58 'ALT_RIGHT'
		59 'SHIFT_LEFT' 60 'SHIFT_RIGHT'
		61 'TAB' 62 'SPACE' 63 'SYM'
		64 'EXPLORER' 65 'ENVELOPE'
		66 'ENTER' 67 'DEL'
		68 'GRAVE' 69 'MINUS' 70 'EQUALS'
		71 'LEFT_BRACKET' 72 'RIGHT_BRACKET'
		73 'BACKSLASH' 74 'SEMICOLON' 75 'APOSTROPHE' 76 'SLASH'
		77 'AT' 78 'NUM' 79 'HEADSETHOOK' 80 'FOCUS' 81 'PLUS' 82 'MENU'
		83 'NOTIFICATION' 84 'SEARCH' 85 'TAG_LAST_KEYCODE'
		111 'HIDEKEYBOARD'
	)
	local keycode key
	if [[ $1 == <-> ]]; then
		keycode=$1
		key=${keys[$keycode]:-Unknown}
	elif [[ $1 == 'list' ]]; then
		techo -c head ${(o)keys}
		return 0
	else 
		key=${(U)1}
		keycode=${(k)keys[(re)$key]}
		[[ -n $keycode ]] || abort 1 "Invalid key $C[warn]$key"
	fi
	run $DRYRUN -p "Sending key $key ($keycode)" adb shell input keyevent $keycode
}

# pm uninstall: removes a package from the system. Options:
#    -k: keep the data and cache directories around after package removal.
#
# pm clear: deletes all data associated with a package.
function uninstallPkg()
{
	local pkgs p keepData keep force
	zparseopts -D -M - k=keep f=force
	(($#1)) || return 10
	#@TODO -k: keep the data and cache directories around after package removal.
	for p; do
		if [[ -n $force ]] || confirm "Remove $p"; then
			if [[ -n $keep ]] || confirm "Delete app data as well"; then
				keepData='-k'
			else
				keepData=
			fi
			run $DRYRUN adb shell pm uninstall $keepData $p
		fi
	done
}

    [[ -n "$1" ]] || return 1
	pkgs=("$@")

    #@TODO -k: keep the data and cache directories around after package removal.
    for p in $pkgs; do
    	run adb shell pm uninstall -k "$p"
    done
}

function processLine()
{
	local cmd pkg
	cmd=$1 ; shift
	case $cmd in
		(*=*)
			verbose=${cmd#verbose=}
		;;
		(focuswindow|focus)
			#cur=$(adb shell dumpsys window windows | awk '/mCurrentFocus/{print $3}' | cut -d'}' -f1)
		;;
		(focusactivity)
			run $DRYRUN adb shell dumpsys activity activities | grep mFocusedActivity
		;;
		(immersive)
			local value imm setting
			((#)) || { usage ; return 10 }
			value=$1
			imm=(
				'default - Reset to normal config'
				'full - Hide both bars'
				'navigation - Hide navigation bar only'
				'status - Hide status bar only'
			)
			set -x
			if match_array -c -v value $value imm; then
				case $value in
					d*) setting='null*' ;;
					f*) setting=immersive.full='*' ;;
					n*) setting=immersive.navigation='*' ;;
					s*) setting=immersive.status='*' ;;
				esac
				setting g policy_control $setting
			fi
			set +x
		;;
		(logcat) logcat "$@" ;;
		(home)
			action=android.intent.action.MAIN
			category=android.intent.category.HOME
			run $DRYRUN adb shell am start -a $action -c $category
		;;
		(ps)
			#run $DRYRUN adb shell ps "$@"
			print -l $(listRunning $1)
		;;
		(en|enable|dis|disable) enDis $cmd "$@" ;;
		(install|inst)
			if [[ $(getext "$1") != "apk" ]]; then
				techo -c warn $1 is not a APK
				return 1
			fi
			install $1
		;;
		(list) listPkg "$@" ;;
		(stop|restart)
			chooser -v pkg -f1 $(listRunning "$@") || cancel 
			stop $pkg || abort 1 "Could not stop $C[cyan]$pkg"
			[[ $cmd == 'restart' ]] && start $pkg
		;;
		(start)
			chooser -v pkg -f1 $(listPkg -d "$@") || cancel
			start $pkg
		;;
		(uninstallall|removeall|delall|deleteall) uninstall -a "$@" ;;
		(uninstall|remove|rm|del(ete)?) uninstall "$@" ;;
		(clear) clearData "$@" ;;
		(info) selectPkg -v pkg "$@" && info $pkg ;;
		(wallpaper|anim|animation) #@TODO use rsync or md5
			ro=$(run $DRYRUN adb shell mount | awk '/^\/dev\/block\/mmcblk0p2/{print $4}') || abort
			if [ "${ro:0:2}" = 'ro' ]; then
				run $DRYRUN adb shell mount -o remount,rw /system || abort
			fi
			techo -c head Transfering wallpaper
			run $DRYRUN adb push $HOME/PeD/logo.png /data/system/users/0/wallpaper || abort

			techo -c head Transfering boot animation
			run $DRYRUN adb push $HOME/PeD/android/bootanimation.zip /system/media || abort
		;;
		(hidekeyb|hidekeyboard|keyb) sendkey 111 ;;
		(key|sendkey) sendkey $1 ;;
		(poweroff)
			run $DRYRUN adb shell am start -a android.intent.action.ACTION_REQUEST_SHUTDOWN
		;;
		(\\h|h|help) usage ;;
		(\q|exit|quit) running=0 ;;
		(version|ver|release) getprop ro.build.version.release ;;
		(getprop|prop) getprop "$@" ;;
		(*)
			techo -c warn type $C[lred]\h$_C or $C[lred]help$_C for usage
			return 1
		;;
	esac
}

integer running=1

(($#)) && { processLine "$@" ; ret=$? }

if ((interactive)); then
	trap 'throw 130' SIGINT
	while ((running)); do
		{
			((ret)) && c='err' || c='ok'
			if input -r -c lcyan -v line -p "app${C[$c]}❯$C_ "; then
				processLine $=line ; ret=$?
			else
				((ret=$? == 1)) && running=0
			fi
		} always {
			if catch '*'; then
				techo
				ret=$CAUGHT
				#((ret >127)) && running=0
			fi
		}
	done
fi

sexit $ret
