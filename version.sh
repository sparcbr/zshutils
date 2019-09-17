#!/bin/zsh
include git
include file
#include android
include functions

autoload is-at-least

function versionCurrent()
{
	#git tag -l --sort version:refname 2>/dev/null | tail -n1
}

function versionIncrement()
{
	local s v="$1" prefix
	explode -v s "$1" '.'
	# no dots
	if [[ $#s -eq 1 ]] && [[ $v[1] =~ [^0-9] ]]; then
		v=${v:1}
		prefix='v'
	else
		v=$s[-1]
	fi
	s[-1]=$prefix$(($v + 1))
	echo ${(j/./)s}
	set +x
}
integer isRelease=$1 versionMajor=$2 versionMinor=$3 versionPatch=$4
integer versionCode
#if [[ $# -eq 0 || $1 = 'cc' ]]; then
	gitState=$(git describe --tags)
	#git rev-list master 2>/dev/null | wc -l)
	(( gitstate > versionCode)) && versionCode++
	echo $versionCode 
	return
#fi

curVersion=$(git version )
if [[ -n $curVersion ]]; then
	techo "Current git version: $curVersion"
	input -v version -p "Current version $curVersion.\nEnter new version" $(versionIncrement "$curVersion")
elif confirm 'No version found. Use version 1.0'; then
	version=1.0
else
	cancel
fi

if [[ -n "$version" ]]; then
	[[ "${version:0:1}" =~ "[0-9]" ]] && version="v$version"

	{ 
		[[ "$version" != "$curVersion" ]] && is-at-least $curVersion $version
	} || abort "Version must be higher than $curVersion (given: $version)"

	file= # app/build.gradle
	local integer versionCode newVersionCode

	file=
	if [[ -f $file ]]; then

		ver=($(awk  '/versionCode|versionName/{print $1"="$2}')) # <- ???
		for line in $ver; do
			eval $line
			[[ $versionCode -gt 0 && -n $versionName ]] && break
		done
		newVersionCode=$(($version * 100))
		while (( $newVersionCode <= $versionCode )); do
			((newVersionCode*=10))
		done
		techo -c warn versionCode: $versionCode -> $newVersionCode
		techo -c warn versionName: $versionName -> $version
		sed --in-place=.sed "s/versionName '$versionName'/versionName '$version'/" $file
	fi
	git tag -a $version
fi
