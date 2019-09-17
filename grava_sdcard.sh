#!/bin/zsh
# Format an SD card for Android on BeagleBone Black

setopt extendedglob pipefail nomultios
#cd $(dirname "$0")
cd $HOME/PeD/android

if [ -z "$ZSH_MAIN_VER" ] || [ -z "$ZSH_LIBS" ]; then
	[ -z "$ZSH_LIBS" ] && [ -f 'zsh_main' ] && ZSH_LIBS=$PWD
	source $ZSH_LIBS/zsh_main || { echo "zsh_main not found" ; set +x; exit 127 }
fi

include -r functions || exit 127
include -r device || exit 127
include -r file || exit 127
#var=2
#input -p teste var
#echo var=$var

EXIT=1
ABORT=end
function end()
{
	set+x
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

function makeExt4()
{
	local device features='^64bit'
	device=$1
	label=$2
	#androidmnt=$3
	#size=$4
	#[[ -n $size ]] || { echo size error ; exit 1 }
	if grep -q "metadata_csum" /etc/mke2fs.conf; then
		features+=",^metadata_csum"
	fi
	run -s mkfs.ext4 -L $label -O $features $device

	#./mkuserimg.sh $srcdir $outimgfile ext4 $androidmnt $size
	#SRC_DIR OUTPUT_FILE EXT_VARIANT MOUNT_POINT SIZE
}

function get_size_from_image()
{
	echo $(ls -l $1.img | cut -f5 -d' ')
}

function setupPartNames()
{
	SDDRIVE=${SDDEVICE#/dev/}
	if [ "$SDDRIVE" = 'mmcblk0' ]; then
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
	run -s sfdisk $devname <<- EOF
		,${sizes[1]},0x0c,*
		,${sizes[2]},,,
		,${sizes[3]},,,
		,${sizes[4]},,,
	EOF

	_sync
	#sleep 1
	#@ sudo partprobe $devname

	#@ automount sucks, is it off?
	umountAll
}

function copy_from_dir()
{
	local from_dir sd_part err sdmnt
	from_dir=$1 ; sd_part=$2
	sdmnt='mnt/sdpart'
	{
set -x
		deviceMount $sd_part $sdmnt || throw $?
		syncDirs -s $dryrun "$from_dir" "$sdmnt" || throw $?
	} always {
	set -x
		#DEBUG=1 run -p "Umounting $sd_part" deviceUnmount $sd_part
		echo "return=$?"
		if catch '*'; then
			[ "$CAUGHT" -eq 130 ] && cancel $CAUGHT
			set +x
			return $CAUGHT
		fi
		set +x
		return 0
	}
}

function copy_from_image()
{
	local from_img sddev err imgmnt sdmnt ret
	from_img=$1 ; sddev=$2
	imgmnt='mnt/image' ; sdmnt='mnt/sdpart'
	
	{
		imageMount $from_img $imgmnt || throw $?
		deviceMount $sddev $sdmnt || throw $?
		syncDirs -s "$imgmnt" "$sdmnt" || throw $?
	} always {
		local ret cmd print
		set -x
		unloop --img $from_img
		set +x
		deviceUnmount $sddev
		if catch '*'; then
			CAUGHT=($=CAUGHT)
			ret=$CAUGHT[1]
			[[ $ret -eq 130 ]] && cancel ${CAUGHT:1}
			techo -c err ${CAUGHT:1} $FAIL
			return $CAUGHT
		fi
	}
}

#function syncDirs()
#{
#	local perms dryrun info from="$1" to="$2"
#	zparseopts -M -D - n=dryrun q=quiet 
#	[ "$3" = "ext" ] && perms='-a' || perms='-r'
#	[ -z "$quiet" ] && info='--info=progress2'
#	run -s rsync $dryRun $perms -chil $info --delete $from/ $to && _sync
#}

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

zparseopts -M -D - n=dryrun q=quiet -skip-parts:=skipParts h=help -help=h
if [ -n "$help" ]; then
	techo -c head "Usage: $0 [--skip-parts '1 3 n' ] [drive]"
	techo -c head "		drive is 'sdb', 'mmcblk0'"
	exit 1
fi

# SD device
if [ -n "$1" ]; then
	isSD "$1" && SDDEVICE="$1" || techo -c warn "Device $1 does not exist or have no media"
fi
typeset -a SDDEVICEDATA SDPartitionSizes SDPartitionTypes
if [ -z "$SDDEVICE" ]; then
	SDDEVICEDATA=("${(f)$(findSD -l \
		--cmd 'techo -c warn "Remove SD card and plug it in again."')}") || abort $?
	SDDEVICE=$SDDEVICEDATA[1]
	shift SDDEVICEDATA
	techo -c warn "Found SD device: $SDDEVICE"
	for var in $SDDEVICEDATA; do
		eval $var
		SDPartitionSizes+=($SIZE)
		SDPartitionTypes+=($FSTYPE)
	done
	if [ "$#SDDEVICEDATA" -gt 0 ]; then
		techo "Partitions:"
		for ((i=1; i <= $#SDDEVICEDATA; i++)); do
			techo ${SDDEVICE}$i $SDPartitionSizes[$i] $SDPartitionTypes[$i]
		done
	fi
fi
setupPartNames

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
if [ -n "$skipParts" ]; then
	skipParts=($=skipParts[2])
	typeset -a skipPart
	for i in $skipParts; do
		skipPart[$i]=1
	done
fi

###################
# make partitions #
###################
partitionSizes=('64M' '512M' '900M' '900M')
partitionTypes=('vfat' 'ext4' 'ext4' 'ext4')
if [ "$SDPartitionSizes" != "$partitionSizes" ] || [ "SDPartitionTypes" != "$partitionTypes" ]; then
	techo -c warn "\nPartitioning SD ($SDDEVICE)"
	if confirm -c lblue "Partition SD"; then
		makePartitions $SDDEVICE $partitionSizes
		run -s -p "Ejecting $C[warn]$SDDEVICE$_C" - eject $SDDEVICE
		#@disk identifier

		SDDEVICE=$(findSD -d --loop -o $SDDEVICE \
			--cmd 'techo -c warn "Remove SD card and plug it in again."') || abort $?
		#TODO verify
		setupPartNames
		partitioningOK=1
		techo -c warn SD=$SDDEVICE
	fi
fi
[ -n "$partitioningOK" ] || techo -c warn "Skiped partitioning"
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
set -x
if [ -z "${skipPart[1]}" ]; then
	techo -c warn "\nFormatting $name ($part) SD partition (FAT)"
	run -s mkfs.vfat -F 16 -n $name $part || abort
else
	deviceUnmount --used $part
	run -s -p "\nChecking $name ($part: vfat)" fsck.vfat $part || abort
fi
dir=${IMAGES_DIR}/$name
techo -c warn "Copying $name data to SD ($dir => $part)"
copy_from_dir $dir $part || abort
set +x
#run -s mkimage -A arm -O linux -T ramdisk -d ${IMAGES_DIR}/ramdisk.img uRamdisk

##########
# System #
##########
name="system" ; part=$SYSTEM_PART
if [ -z "${skipPart[2]}" ]; then
	techo -c warn "\nFormatting $name ($part) SD partition (EXT4)"
	makeExt4 $part $name || abort
else
	deviceUnmount --used $part
	run -s -p "\nChecking $name ($part: EXT4)" fsck.ext4 $part || abort
	#@TODO ext
fi
img=$(findImage $name $version $IMAGES_DIR)
techo -c warn "Copying $name data to SD ($img => $part)"
copy_from_image $img $part ext || abort

############
# Userdata #
############
name="userdata" ; part=$USER_PART
if [ -z "${skipPart[3]}" ]; then
	if [ -z "${skip_format[3]}" ]; then
		techo -c warn "\nFormatting $name ($part) SD partition (EXT4)"
		makeExt4 $part $name #@@@|| abort
	fi
else
	deviceUnmount --used $part
	run -s -p "\nChecking $name ($part: EXT4)" fsck.ext4 $part || abort
fi
img=$(findImage $name $version $IMAGES_DIR)
techo -c warn "Copying $name data to SD ($img => $part)"
copy_from_image $img $part ext || abort

#########
# Cache #
#########
name="cache" ; part=$CACHE_PART
if [ -z "${skipPart[4]}" ]; then
	techo -c warn "Formatting $name ($part) SD partition (EXT4)"
	makeExt4 $part $name || abort
fi

##########
# Ending #
##########
_sync

techo -c ok "SUCCESS! SD card written"
if confirm "Eject SD card"; then
    run -s eject $SDDEVICE
fi
