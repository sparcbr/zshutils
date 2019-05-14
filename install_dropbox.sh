#!/bin/zsh

sudo apt install dolphin-plugins python-gpg
url=$(wget -qO- https://www.dropbox.com/install-linux | grep -Eoi '<a [^>]+>' |  grep -Eo 'href="[^\"]+"'  | grep -E 'ubuntu/.*amd64.deb' | cut -f2 -d'"')
url="https://www.dropbox.com${url}"
savedir="$HOME/Downloads"
filename=$(basename $url)
deb_file="$savedir/$filename"
wget --directory-prefix=$savedir -O $filename --show-progress $url
xdg-open $deb_file
echo Waiting for dropbox
dropbox_started=1
while [[ $dropbox_started -ne 0 ]]; do
	sleep 2
	ps -x | grep -w dropbox | grep -vw grep
	dropbox_started=$?
done

echo dropbox started
