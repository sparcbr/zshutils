#!/bin/zsh
compaudits=($(compaudit))
echo "comps=$compaudits[@]"
for f in $compaudits; do chmod 755 -R $f; done
