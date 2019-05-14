#!/bin/bash
name=$1
if [[ -z "$name" ]]; then
    echo "Usage: $0 image_name"
    exit 1
fi
adb shell screencap -p | perl -pe 's/\x0D\x0A/\x0A/g' > $name.png #&& mogrify -crop 1024x544+0+20 $name.png
