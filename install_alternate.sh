#!/bin/zsh
include aliases
include functions
set -x
#info=.java-1.6.0-oracle-amd64.jinfo
jinfo=($(f -sb /usr/lib/jvm \*.jinfo 2>/dev/null))
#
chooser -v info $jinfo || cancel
grep jvm $info | while read -r f ; do
	name=`echo $f | /usr/bin/cut -d' ' -f2`
	_path=`echo $f | /usr/bin/cut -d' ' -f3`
	linkname=`/usr/bin/basename $_path`

	altfile=/var/lib/dpkg/alternatives/$linkname
	linkpath=/usr/bin/$linkname
	if [[ -f $altfile ]]; then
		altpath=$(cat $altfile | awk 'NR == 2')
		if [[ $altpath != $linkpath ]]; then
			echo path set in $altfile is $altpath
			linkpath=$altpath
		fi

	else
		echo "$altfile does not exist"
	fi
	#sudo update-alternatives --install $linkpath $name $_path 1061
	sudo update-alternatives --set $name $_path
done
