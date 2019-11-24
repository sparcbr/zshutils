#!/bin/zsh
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
	DEBUG=${debug[1]:2}
	if [[ $DEBUG != [0-9]## ]]; then
		[[ -n $DEBUG ]] && set - $DEBUG "$@" # not a number means it's not an argumento to -d
		DEBUG=1
	fi
fi

ABORT='sexit'
function sexit()
{
	((interactive)) && return
	#echo $ZSH_EVAL_CONTEXT
	[[ -o xtrace ]] && set +x
	exit $1
}
[[ -n $interactive ]] && interactive=1

cmds=(focuswindow\|focus focusactivity home en\|enable\|dis\|disable install\|inst list poweroff stop\|restart uninstallall\|removeall\|delall\|deleteall uninstall\|remove\|rm\|del\(ete\)\? wallpaper\|anim\|animation hidekeyb\|hidekeyboard start immersive log\|logcat reboot\|restart doc)

(($# || interactive)) || { usage ; sexit 1 }

docurl='https://developer.android.com/studio/command-line/adb'
function usage()
{
	print -l ${(o)cmds}
	print "\"app doc\" for online documentation ($docurl)"
}

function parseADBErrors()
{
	local line
	while read line; do
		[[ $line == 'EOF' ]] && return

		if [[ $line =~ '^(\[[0-9;]+m)?(adb: )?error: (.*)(\[0?m)?' ]]; then
		#if [[ $line =~ '^(\[[0-9;]+m)?error: (.*)' ]]; then
			case $match[3] in
				*'more than one device/emulator') echo EMultDev ;;
				'no devices/emulators found') echo EConn ;;
				*) ;;
			esac
		elif [[ $line =~ $'^adb: unknown command (.*)' ]]; then
		elif [[ $line == '- waiting for device -' ]]; then
			echo EConn
		elif [[ $line =~ $'^failed to connect to \'(.*)\': (.*)' ]]; then
			echo EConn $match[1] $match[2]
		else
			techo -c warn 'Unknown error:' $line
			continue
		fi
		techo -Pr "%F{9}${line}%f"
		#print -Pr ${(@q)match}
	done
}

connType=(-d)
function adb()
{
	local err line
	integer ret=0 pid

	coproc parseADBErrors
	#run $DRYRUN command adb $devOpts "$@" 2>&p & pid=$!
	#run -c 0 $DRYRUN command adb $devOpts "$@" 2>&p
	while ! run -Ae $DRYRUN command adb $devOpts "$@" 2>&p; do
	#@TODO sort errors by file before opening files
		while read -p line; do
			split=(${(z)line})
			case $split[1] in
				EMultDev)
					while ! chooseDevice; do
						techo -c warn Connect an android device
						sleep 2
					done
					continue
					;;
				EConn)
					connect $split[1] $split[2]
					continue
					;;
				*)
					;;
			esac
		done
		break
	done
	#wait $pid; ret=$?
	print -p EOF
	return $ret
}
#typeset -Tf adb

function shell()
{
	adb shell "$@" | stdbuf -o0 tr -d $'\r'
}

function chooseDevice()
{
	local devList=("${(f)$(adb devices -l)}")

	curDevice=
	#@TODO device usb:1-5.3 product:surnia_retbr_ds model:MotoE2_4G_LTE_ device:surnia_uds stdbuf -o0 transport_id:1
	deviceID=$(chooser -H 'Select device' -D $curDevice -f1 $devList) || return
	connType=(-s $deviceID)
}

function connect()
{
	local err line
	coproc parseADBErrors
	if ! adb connect "$@" 2>&p; then
	(
		#@TODO sort errors by file before opening files
		while read -p line; do
			split=(${(z)line})
			case $split[1] in
				EmultDev) ;;
				EConn) ;;
			esac
		done
	)
	fi
	print -p EOF
	failed to connect to '192.168.1.101:5555':
}

function netDevice()
{
	local family obj='addr' iface='wlan0'
	(($#family)) || family=(-f inet)
	shell ip $family $obj show ${1:-$iface}
}

function getDeviceIP()
{
	local iface val
	case $1 in
		''|wlan[0-9]|wifi) ;;
		lo) iface='lo' ;;
		*) techo -c warn "Invalid interface: \"$1\"" ;;
	esac
	val=$(netDevice $iface) || return 1
	[[  $val =~ 'inet ([0-9.]+)/[0-9]+' ]] && e $match[1]
}

function listPkg()
{
	local ret flags pkgs all sorted sortedPkgs pkg tmp n=1 date
	zparseopts -D -M - a=all d=date
	[[ -n $all ]] || flags="-3"
	sorted=() ; sortedPkgs=()
	pkgs=($(shell pm list packages $flags "$@" | stdbuf -o0 tr -d '\r')) || return
	(($#pkgs)) || return 10
	pkgs=(${pkgs#package:})
	for pkg in $pkgs; do
		local _date=$(
			shell dumpsys package $pkg | \
				awk -F'=' '/lastUpdateTime/{print $2}' | \
				head -n1 | stdbuf -o0 tr -d '\r\n'
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

function info()
{
	shell dumpsys package $1 | stdbuf -o0 tr -d '\r'
}

function listRunning()
{
	shell ps | awk "\$9 ~ /${@:-.}/{print \$9}" | stdbuf -o0 tr -d $'\r\t'
}

function getMainActivity()
{
	local arr=($(listActivities $1))
	echo ${arr[1]}
}

function listActivities()
{
	local pkg=$(choosePkg "$@")
	shell dumpsys package $pkg | \
		awk '/^Activity Resolver Table/,/^$/ { s = $0 } \
			match(s, /([^: =]+\/[^: ]+)$/, m) { print m[1]; s="" }'
}

function start()
{
	local act

	if [[ $1 =~ "/" ]]; then
		act=$1
	elif [[ -n $2 ]]; then
		act=$1/$2
	else
		chooser -H 'Start activity' -v act $(listActivities $1) || cancel
	fi
	shell am start $act && sendkey WAKEUP
}

function stop()
{
	local p
	for p; do
	    shell am force-stop $p
	done
}

function enDis()
{
	local cmd="$1"
	[ $cmd = 'en' ] && cmd='enable'
	[ $cmd = 'dis' ] && cmd='disable'
	shift
	foreach p; do
	    shell pm $cmd $p
	done
}

function apkinstall()
{
	#adb push $1 /data/local/tmp/$1
	#shell pm install -t -r /data/local/tmp/$1
	adb install $1
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
	shell dumpsys package $1 | grep versionName
}

function choosePkg()
{
	local running
	zparseopts -D -M - r=running
	if [[ -n $running ]]; then
		chooser -H 'Select package' -f1 --ifs $'\n' "$(listRunning "$@")"
	else
		chooser -H 'Select package' -f1 --ifs $'\n' "$(listPkg -d "$@")"
	fi
}

function clearData()
{
	local all arg args
	integer ret=0
	zparseopts -D -M - a=all
	args=($(choosePkg $all "$@"))
	for arg in $args; do
		if [[ "$(getext $arg)" = 'apk' ]]; then
			arg=$(getPkg $arg) || {
				techo -c err "Failed getting package name from $C[warn]$arg$_C. Ignoring."
				((ret++))
				continue
			}
		fi
		# run --confirm
		shell pm clear $arg
	done
	return $ret
}

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
		92 'PAGEUP' 93 'PAGEDOWN'
		111 'HIDEKEYBOARD'
		113 'CONTROL_LEFT' 114 'CONTROL_RIGHT'
		131 'F1' 132 'F2' 133 'F3' 134 'F4' 135 'F5'
		136 'F6' 137 'F7' 138 'F8' 139 'F9' 140 'F10' 141 'F11' 142 'F12'
		176 'SETTINGS'
		207 'CONTACTS' 208 'CALENDAR' 209 'MUSIC' 210 'CALCULATOR'
		220 'DEC_BRIGHT' 221 'INC_BRIGHT'
		223 'SLEEP' 224 'WAKEUP'
		277 'CUT' 278 'COPY' 279 'PASTE'
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
		keycode=${(k)keys[(r)(*\|)#($key)(\|*)#]}
		[[ -n $keycode ]] || abort 1 "Invalid key $C[warn]$key"
	fi
	run $DRYRUN -p "Sending key $key ($keycode)" shell input keyevent $keycode
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
			if [[ -z $keep ]] && confirm "Delete app data as well"; then
				keepData=
			else
				keepData='-k'
			fi
			shell pm uninstall $keepData $p
		fi
	done
}

function uninstall()
{
	local all arg args keepData
	zparseopts -D -M - a=all k=keepData
	args=("$@") ; args=(${(M)args:#*.apk})
	(($#args)) || args=($(choosePkg $all "$@")) || return
	for arg in $args; do
		if [[ "$(getext $arg)" = 'apk' ]]; then
			uninstallPkg $keepData $(getPkg $arg)
		else
			uninstallPkg $keepData $arg
		fi
	done
}

function logcat()
{
	local count follow args
	zparseopts -D -M - n:=count f=follow
	[[ -z $follow ]] && args+=(-d)
	if [[ -n $count ]]; then
		((count[2])) && args+=(-T $count[2]) || args+=(-T "$count[2]")
	fi
	adb logcat $args "$@"
}

function getprop()
{
	local name names val values tmp
	
	if (($# == 0)); then
		confirm "List all properties" && run shell getprop
		return
	fi
	
	names=() ; values=()
	for name; do
		if [[ $name != *'*'* ]]; then
			val=$(shell getprop $name | stdbuf -o0 tr -d $'\r')
			if [[ -n $val ]]; then
				names+=($name)
				values+=($val)
				continue
			fi
		fi
		explode -v val --ifs $'\n' "$(shell getprop | grep $name | stdbuf -o0 tr -d $'\r')" $'\n'
		for line in $val; do
			explode -v tmp $line ':'
			names+=("${${tmp[1]#\[}%\]}")
			values+=("${${tmp[2]# \[}%\]}")
		done
	done

	if (($#names == 1)); then
		echo $values[1]
	else
		integer i
		for ((i=1; i<=$#names; i++)); do
			echo "$names[$i]=$values[$i]"
		done
	fi
}

function setting()
{
	local nspace nspace_m nspaces=(system secure global)
	local setting value nspace_m
	integer n
	zparseopts -D -M - g=nspace s=nspace S=nspace
	if [[ -n $nspace ]]; then
		nspace=${nspace[1]:1:1}
	else
		nspace=$1 ; shift
	fi
	typeset -Tf in_array
	in_array -v nspace_m $nspace nspaces
	n=$#nspace_m
	((n)) || abort 10 namespace: ${C_}$nspaces
	chooser -H 'Setting namespace:' -v nspace $nspace_m || cancel
	setting=$1
	value=$2
	if [[ -n $value ]]; then
		oper='put'
	elif [[ -n $setting ]]; then
		oper='get'
	else
		oper='list'
	fi
	shell settings put $nspace $setting $value
}

function screenshot()
{
	local name=$(uniqfile -P screenshot -S png "$@")

	adb exec-out 'screencap -p' > $name
}

devOpts=()
function processLine()
{
	local cmd pkg tmp
	zparseopts -D -M - t:=devOpts s:=devOpts e=devOpts d=devOpts
	cmd=${(L)1} ; shift
	case $cmd in
		(*=*)
			verbose=${cmd#verbose=}
		;;
		(clear) clearData "$@" ;;
		(en|enable|dis|disable) enDis $cmd "$@" ;;
		(focusactivity)
			shell dumpsys activity activities | grep mFocusedActivity
		;;
		(focuswindow|focus)
			#cur=$(shell dumpsys window windows | awk '/mCurrentFocus/{print $3}' | cut -d'}' -f1)
		;;
		(getprop|prop) getprop "$@" ;;
		(home) sendkey HOME
			#action=android.intent.action.MAIN
			#category=android.intent.category.HOME
			#shell am start -a $action -c $category
		;;
		(immersive) immersive "$@"
			local value options setting
			options=(
				'default - Reset to normal config'		'null*'					 
				'full - Hide both bars'					'immersive.full=*'		 
				'navigation - Hide navigation bar only' 'immersive.navigation=*' 
				'status - Hide status bar only'			'immersive.status=*'	 
			)
			(($#)) || { techo $0 $cmd ${options} ; return 0 }
			if match_array -c -v tmp --array $1 options; then
				setting g policy_control $setting
			fi
		;;
		(info) pkg=$(choosePkg "$@") && info $pkg ;;
		(install|inst)
			if [[ $(getext "$1") != "apk" ]]; then
				techo -c warn $1 is not a APK
				return 1
			fi
			apkinstall $1
		;;
		(keyb|hidekeyb|hidekeyboard) sendkey 111 ;;
		(key|sendkey) sendkey "$@" ;;
		(logcat) logcat "$@" ;;
		(wifi)  ;;
		(net) getDeviceIP  ;;
		(list) listPkg "$@" ;;
		(listactivities|listact|listacts|activities) listActivities "$@" ;;
		(view|open|openurl|url)
			shell am start -W -a android.intent.action.VIEW -d $1 $2
		;;
		(poweroff)
			shell am start -a android.intent.action.ACTION_REQUEST_SHUTDOWN
		;;
		(ps) listRunning $1 ;;
		(pull|get) apull "$@" ;;
		(push|send) apush "$@" ;;
		(reboot) chooser -f1 -p "Reboot device"  && adb reboot ;;
		(ss|screenshot|screencap) screenshot "$@" ;;
		(setting|settings) set -x; setting "$@" ; set +x;;
		(shell) shell "$@" ;;
		(start)
			pkg=$(choosePkg "$@") || cancel
			start $pkg
		;;
		(stop|restart)
			if pkg=$(choosePkg -r "$@"); then
				stop $pkg || abort 1 "Could not stop $C[cyan]$pkg"
			elif [[ $? -ne 10 ]]; then
				cancel
			fi
			if [[ $cmd == 'restart' ]]; then
				if [[ -z $pkg ]]; then
					pkg=$(choosePkg "$@") || return
				fi
				start $pkg
			fi
		;;
		(\q|exit|quit) running=0 ;;
		(swipeup|unlock) shell input swipe 30 600 30 300 ;;
		(swipetop) shell input swipe 30 0 30 300 ;;
		(swipedown) shell input swipe 30 300 30 600 ;;
		(swipeleft) shell input swipe 300 400 30 400 ;;
		(swiperight) shell input swipe 30 400 300 400 ;;
		(uninstallall|removeall|delall|deleteall) uninstall -a "$@" ;;
		(uninstall|remove|rm|del(ete)?) uninstall "$@" ;;
		(version|ver|release) getprop ro.build.version. ;;
		(edit)
			pull "$@"
			v -f $f
			push $f "$@"
			v /system/etc/hosts
			v $file/system/etc/hosts
		;;
		(wallpaper|anim|animation) #@TODO use rsync or md5
			ro=$(shell mount | awk '/^\/dev\/block\/mmcblk0p2/{print $4}') || abort
			if [ "${ro:0:2}" = 'ro' ]; then
				shell mount -o remount,rw /system || abort
			fi
			techo -c head Transfering wallpaper
			adb push $HOME/PeD/logo.png /data/system/users/0/wallpaper || abort

			techo -c head Transfering boot animation
			adb push $HOME/PeD/android/bootanimation.zip /system/media || abort
		;;
		(\\h|h|help) usage ;;
		(doc) open $docurl ;;
		(*)
			techo -c warn type $C[lred]\h$_C or $C[lred]help$_C for usage
			return 1
		;;
	esac
}

if ((DEBUG)); then
	set -x
	debug -k adb processLine choosePkg sendkey
	set +x
fi

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
