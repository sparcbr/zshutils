#!/bin/zsh
cmd=echo
for deb in $(apt-cache depends python | grep -E 'Depends|Recommends|Suggests' | cut -d ':' -f 2,3 | sed -e s/'<'/''/ -e s/'>'/''/); do
	$cmd $deb
	#sudo apt-get download $i 2>>errors.txt; done
done
