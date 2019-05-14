#!/bin/sh
basedir=shop
dir=shop/v0
cd /var/www
sudo mkdir -p $dir
sudo chown www-data:www-data -R $basedir
sudo chmod g+w -R $basedir
cd $dir
mkdir hooks
sudo chown www-data:www-data -R hooks
sudo chmod g+w hooks

echo "#!/bin/sh
GIT_WORK_TREE=/var/www/$dir git checkout -f" > hooks/post-receive

chmod +x hooks/post-receive

git init --bare
sudo chmod -R g+w *

