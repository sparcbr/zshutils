#!/bin/zsh
#include git
#include android
include functions

autoload is-at-least

function versionLast()
{
	git tag -l --sort version:refname 2>/dev/null | tail -n1
}
function abort()
{
	techo -c err "$@"
	exit 1
}
function versionIncrement()
{
	local s v="$1" prefix
	s=($(explode "$1" '.'))
	set -x
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
curVersion=$(versionLast)
techo "Current version: $curVersion"
version=$(versionIncrement "$curVersion")
version=$(input -p "New version" $version)
if [[ -n "$version" ]]; then
	[[ "${version:0:1}" =~ "[0-9]" ]] && version="v$version"

	{ 
		[[ "$version" != "$curVersion" ]] && is-at-least $curVersion $version
	} || abort "Version must be higher than $curVersion (given: $version <= $curVersion)"

	git tag -a $version
fi
