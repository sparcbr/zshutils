#!/bin/zsh
# Format an SD card for Android on BeagleBone Black

setopt extendedglob pipefail nomultios
cd $(dirname $(readlink -f "$0"))

if [ -z "$ZSH_MAIN_VERSION" ] || [ -z "$ZSH_LIBS" ]; then
	[ -z "$ZSH_LIBS" ] && [ -f 'zsh_main' ] && ZSH_LIBS=$PWD
	source $ZSH_LIBS/zsh_main || { echo "zsh_main not found" ; exit 127 }
fi
include -r functions || exit 127
include -r device || exit 127
include -r file || exit 127

EXIT=1
ABORT=end
function end()
{
	techo "$@"
	ABORT=return
	umountAll
	exit $1
}

function umountAll()
{
	local p parts=($BOOT_PART $SYSTEM_PART $USER_PART $CACHE_PART)
	techo -c warn "Umounting partitions"
	run deviceUnmount $parts
	run dirUnmount mnt/*
}

if [ $# -gt 1 ] || [ "$1" = '-h' ] || [ "$1" = '--help' ]; then
	techo -c head "Usage: $0 [drive]"
	techo -c head "		drive is 'sdb', 'mmcblk0'"
	exit 1
fi

function make_ext4()
{
	local device
	device=$1
	label=$2
	#androidmnt=$3
	#size=$4
	#[[ -n $size ]] || { echo size error ; exit 1 }
	run -s mkfs.ext4 -L $label -O '^metadata_csum,^64bit' $device

	#./mkuserimg.sh $srcdir $outimgfile ext4 $androidmnt $size
	#SRC_DIR OUTPUT_FILE EXT_VARIANT MOUNT_POINT SIZE
}

function get_size_from_image()
{
	echo $(ls -l $1.img | cut -f5 -d' ')
}

function setupPartNames()
{
	if [ "$SDDRIVE" == 'mmcblk0' ]; then
		BOOT_PART=${SDDEVICE}p1
		SYSTEM_PART=${SDDEVICE}p2
		USER_PART=${SDDEVICE}p3
		CACHE_PART=${SDDEVICE}p4
	else
		BOOT_PART=${SDDEVICE}1
		SYSTEM_PART=${SDDEVICE}2
		USER_PART=${SDDEVICE}3
		CACHE_PART=${SDDEVICE}4
	fi
}

# sfdisk > v2.26
# Create 4 primary partitons on the sd card
#  1: boot:   FAT32, boot flag
#  2: system: Linux,
#  3: data:   Linux,
#  4: cache:  Linux,
#
# @param1: device name (ie /dev/sdc)
# @params: sizes in megabytes
function makePartitions()
{
	local sizes devname
	devname=$1 ; shift
	sizes=($*)
	run -s sfdisk $devname << EOF
,${sizes[1]}M,0x0c,*
,${sizes[2]}M,,,
,${sizes[3]}M,,,
,${sizes[4]}M,,,
EOF

	run sync
	#sleep 1
	#@ sudo partprobe $devname

	#@ automount sucks, is it off?
	umountAll
}

function copy_from_dir()
{
	local from_dir sd_part err perms sdmnt
	from_dir=$1 ; sd_part=$2
	[[ "$3" == "ext" ]] && perms='-a' || perms='-rv'
	sdmnt='mnt/sdpart'
	run -s mount $sd_part $sdmnt || return $?
	run -s rsync $perms --delete --info=progress2 $from_dir/ $sdmnt || return $?
	run -c warn -p "Syncing caches to disk. Please wait." sync || return $?
	run -p "Umounting $sd_part" deviceUnmount $sd_part
}

function copy_from_image()
{
	local from_img sddev err imgmnt sdmnt
	from_img=$1 ; sddev=$2
	imgmnt='mnt/image' ; sdmnt='mnt/sdpart'
	
	{
		if ! isDeviceMounted $from_img; then
			run -s mount -o loop $from_img $imgmnt || throw $?
		fi

		deviceUnmount $sddev || throw $?
		dirUnmount $sdmnt || throw $?
		run -s mount $sddev $sdmnt || throw $?

		syncDirs "$imgmnt" "$sdmnt" $3 || throw $?
	#	run -s rsync $perms --delete --info=progress2 $imgmnt/ $sdmnt || err=1
		run -p "Umounting $sddev" deviceUnmount $sddev || throw $?
	} always {
		unloop --img $from_img
		if noglob catch *; then
			#CAUGHT=(${=CAUGHT})
			#ret=$CAUGHT[1]
			#CAUGHT=$CAUGHT[2]
			ret=$CAUGHT
			if [[ $ret -eq 130 ]]; then
				[[ -z "$quiet" ]] && techo "$cmd $CANCEL" || cancel
				return $ret
			fi
			[[ -z "$quiet" ]] && techo "$cmd $FAIL (caught $CAUGHT)"
			[[ -n "$alert" ]] && error "$cmd error: caught $CAUGHT"
			return $ret
		fi
	}
}

function syncDirs()
{
	local perms dryrun info from="$1" to="$2"
	zparseopts -M -D -- n=dryrun q=quiet 
	[[ "$3" == "ext" ]] && perms='-a' || perms='-r'
	[[ -z "$quiet" ]] && info='--info=progress2'
	run -s rsync $dryRun $perms -chil $info --delete $from/ $to && \
		run -c warn -p "Flushing caches to disk. Please wait." sync
}

#srcdir=$1 ; outimgfile=$2 ; androidmnt=$3
#size=${4:-$(ls -l $1.img | cut -f5 -d' ')}
#size=$4
#[[ -n $size ]] || { echo size error ; exit 1 }

# grab latest version
function findLastVersion()
{
	ls -drv v[0-9]## | head -1
}

function findImage()
{
	local name=$1 version=$2 basedir
	basedir=${3:-$version}
	ls -drv $basedir/$name.$version.([0-9]##.)#img | head -1
}

# SD device
if [ -n "$1" ]; then
	[ -b "$1" ] && SDDEVICE=$1 || techo -c warn "Device $1 does not exist or have no media"
fi
if [ -z "$SDDEVICE" ]; then
	techo -c warn 'No SD card found'
	set -x
	SDDEVICE=$(findSD -d -l \
		--cmd 'techo -c warn "Remove SD card and plug it in again."') || abort $?
fi
SDDRIVE=${SDDEVICE#/dev/}

# Version
version=${2:-$(findLastVersion)}
if [ ! -d "$version" ]; then
	techo -c err "version $version not found"
	exit 1
fi
IMAGES_DIR=$version

BOOT_FILES=$IMAGES_DIR/boot

# Unmount any partitions that have been automounted
umountAll

skip_make_partitions=

zparseopts -M -D - n=dryrun q=quiet -skip-parts:=skipParts
if [[ -n "$skipParts" ]]; then
	skipParts=($=skipParts[2])
	typeset -a skipPart
	for i in $skipParts; do
		skipPart[$i]=1
	done
fi
###################
# make partitions #
###################
if [[ "$skipPart" != '1 1 1 1' ]]; then
	techo -c warn "\nPartitioning SD ($SDDEVICE)"
	makePartitions $SDDEVICE 64 512 900 512
	set -x
	run -s -p "Ejecting $C[warn]$SDDEVICE$_C" - eject $SDDEVICE
	while true; do
		[ -n "$(lsblk -o SIZE $SDDEVICE)" ] || break
		sleep 0.6
	done

	SDDEVICE=$(findSD -d -l -o $SDDEVICE \
		--cmd 'techo -c warn "Remove SD card and plug it in again."') || abort $?
else
	techo -c warn "Skipping partitioning SD ($SDDEVICE)"
fi
techo -c lyellow SD=$SDDEVICE
#ptbl=$(cat "$IMAGES_DIR/android.$version.ptbl")
#diskptbl=$(sudo sfdisk --dump $SDDEVICE)
#if [[ "$ptbl" != "$diskptbl" ]]; then
#	techo -c err "Error: partition tables differ."
#	techo "Saved partition table dump:"
#	techo $ptbl
#	techo "Disk partition table:"
#	techo $diskptbl
#	abort
#fi

##################################
# make filesystems and copy data #
##################################

########
# Boot #
########
name="boot" ; part=$BOOT_PART
if [[ -z "${skip_part[1]}" ]]; then
	techo -c warn "\nFormatting $name ($part) SD partition (FAT)"
	run -s mkfs.vfat -F 16 -n $name $part || abort
	dir=${IMAGES_DIR}/$name
	techo -c warn "Copying $name data to SD ($dir => $part)"
	copy_from_dir $dir $part fat || abort
fi
#run -s mkimage -A arm -O linux -T ramdisk -d ${IMAGES_DIR}/ramdisk.img uRamdisk
##########
# System #
##########
name="system" ; part=$SYSTEM_PART
if [[ -z "${skip_part[2]}" ]]; then
	techo -c warn "\nFormatting $name ($part) SD partition (EXT4)"
	make_ext4 $part $name || abort
	img=$(findImage $name $version $IMAGES_DIR)
	techo -c warn "Copying $name data to SD ($img => $part)"
	copy_from_image $img $part ext || abort
fi

############
# Userdata #
############
name="userdata" ; part=$USER_PART
if [[ -z "${skip_part[3]}" ]]; then
	if [[ -z "${skip_format[3]}" ]]; then
		techo -c warn "\nFormatting $name ($part) SD partition (EXT4)"
		make_ext4 $part $name #@@@|| abort
	fi
	img=$(findImage $name $version $IMAGES_DIR)
	techo -c warn "Copying $name data to SD ($img => $part)"
	copy_from_image $img $part ext || abort
fi

#########
# Cache #
#########
name="cache" ; part=$CACHE_PART
if [[ -z "${skip_part[4]}" ]]; then
	techo -c warn "Formatting $name ($part) SD partition (EXT4)"
	make_ext4 $part $name || abort
fi

##########
# Ending #
##########
sync

techo -c ok "SUCCESS! SD card written"
if confirm "Eject SD card"; then
    run -s eject $SDDEVICE
fi
