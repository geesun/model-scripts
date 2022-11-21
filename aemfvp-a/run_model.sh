#!/bin/bash

# Copyright (c) 2015-2021, ARM Limited and Contributors. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# Redistributions of source code must retain the above copyright notice, this
# list of conditions and the following disclaimer.
#
# Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# Neither the name of ARM nor the names of its contributors may be used
# to endorse or promote products derived from this software without specific
# prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

err=0

MODEL_TYPE="aemfvp-a"

# Set default fs_type
FS_TYPE="busybox"

while [ "$1" != "" ]; do
	case $1 in
		"--aarch64" | "--Aarch64" | "--AARCH64" )
			model_arch=aarch64
			;;
		-f)
			shift
			if test $# -gt 0; then
				FS_TYPE=$1
			fi
			shift
			;;
	esac
	shift
done

model_arch=${model_arch:-aarch64}


CLUSTER0_NUM_CORES=${CLUSTER0_NUM_CORES:-4}
CLUSTER1_NUM_CORES=${CLUSTER1_NUM_CORES:-4}

# Check for obvious errors and set err=1 if we encounter one
if [ ! -e "$MODEL" ]; then
	echo "ERROR: you should set variable MODEL to point to a valid FVP model binary, currently it is set to \"$MODEL\""
	err=1
else
	# Check if we are running the foundation model or the AEMv8 model
	case $MODEL in
		*Foundation* )
			err=1
			;;
		*Cortex-A* )

			;;
		* )
			model_type=aemv8
			DTB=${DTB:-fvp-base-aemv8a-aemv8a.dtb}

			cores="-C cluster0.NUM_CORES=$CLUSTER0_NUM_CORES \
				-C cluster1.NUM_CORES=$CLUSTER1_NUM_CORES"
			;;
	esac
fi

# Set some sane defaults before continuing to error check
BL1=${BL1:-bl1.bin}
FIP=${FIP:-fip.bin}
IMAGE=${IMAGE:-Image}
INITRD=${INITRD:-ramdisk.img}

# Continue error checking...
if [ ! -e "$BL1" ]; then
	echo "ERROR: you should set variable BL1 to point to a valid BL1 binary, currently it is set to \"$BL1\""
	err=1
fi

if [ ! -e "$FIP" ]; then
	echo "ERROR: you should set variable FIP to point to a valid FIP binary, currently it is set to \"$FIP\""
	err=1
fi

if [ ! -e "$IMAGE" ]; then
	echo "WARNING: you should set variable IMAGE to point to a valid kernel image, currently it is set to \"$IMAGE\""
	IMAGE=
	warn=1
fi
if [ ! -e "$INITRD" ]; then
	echo "WARNING: you should set variable INITRD to point to a valid initrd/ramdisk image, currently it is set to \"$INITRD\""
	INITRD=
	warn=1
fi
if [ ! -e "$DTB" ]; then
	echo "WARNING: you should set variable DTB to point to a valid device tree binary (.dtb), currently it is set to \"$DTB\""
	DTB=
	warn=1
fi

# Exit if any obvious errors happened
if [ $err == 1 ]; then
	exit 1
fi

# check for warnings, like no disk specified.
# note: busybox variants don't need a disk, so it may be OK for DISK to be empty/missing
if [ ! -e "$DISK" ]; then
	echo "WARNING: you should set variable DISK to point to a valid disk image, currently it is set to \"$DISK\""
	warn=1
fi

# Optional VARS arg.
# If a filename is given in the VARS variable, use it to set the contents of the
# 2nd bank of NOR flash: where UEFI stores it's config
if [ "$VARS" != "" ]; then
	# if the $VARS file doesn't exist, create it
	touch $VARS
	VARS="-C bp.flashloader1.fname=$VARS -C bp.flashloader1.fnameWrite=$VARS"
else
	VARS=""
fi

SECURE_MEMORY=${SECURE_MEMORY:-0}

echo "Running FVP Base Model with these parameters:"
echo "MODEL=$MODEL"
echo "model_arch=$model_arch"
echo "BL1=$BL1"
echo "FIP=$FIP"
echo "IMAGE=$IMAGE"
echo "INITRD=$INITRD"
echo "DTB=$DTB"
echo "VARS=$VARS"
echo "DISK=$DISK"
echo "CLUSTER0_NUM_CORES=$CLUSTER0_NUM_CORES"
echo "CLUSTER1_NUM_CORES=$CLUSTER1_NUM_CORES"
echo "SECURE_MEMORY=$SECURE_MEMORY"
echo "NET=$NET"
echo "TAP_INTERFACE=$TAP_INTERFACE"
echo "SATADISK_IMAGE_PATH=$SATADISK_IMAGE_PATH"

kern_addr=0x80080000
dtb_addr=0x83000000
initrd_addr=0x84000000

CACHE_STATE_MODELLED=${CACHE_STATE_MODELLED:=0}
echo "CACHE_STATE_MODELLED=$CACHE_STATE_MODELLED"

# search all the available network interfaces and find an available tap
# network interface to use.
find_tap_interface()
{
	echo -e "\n[INFO] Finding available TAP interface..."
	if [[ -n "$TAP_NAME" ]]; then
		TAP_INTERFACE=$TAP_NAME
	else
		echo -e "\n[WARN] Environment variable TAP_NAME is not defined."
		echo -e "[INFO] If you want to use a particular interface then please export TAP_NAME with the interface name."
		echo -e "[INFO] Searching for available TAP device(s)..."
		ALL_INTERFACES=`ifconfig -a | sed 's/[ \t].*//;/^\(lo\|\)$/d'`
		while read -r line; do
			last_char="${line: -1}"
			#On machines with ubuntu 18.04+, the interface name ends with ":" character.
			#Strip this character from the network interface name.
			if [ "$last_char" == ":" ]; then
				TAP_INTERFACE=${line::-1}
			else
				TAP_INTERFACE=$line
			fi
			# The file tun_flags will only be available under tap interface directory.
			# Incase of multiple tap interfaces, only the first available tap interface will be used.
			if [ -f "/sys/class/net/$TAP_INTERFACE/tun_flags" ];then
				break;
			fi
		done <<< "$ALL_INTERFACES"
	fi
	if [[ -z "$TAP_INTERFACE" ]]; then
		echo -e "[WARN] No TAP interface found !!! Please create a new tap interface for network to work inside the model."
		return 1
	else
		echo -e "[INFO] Interface Found : $TAP_INTERFACE"
	fi
	return 0
}

if [ "$NET" == "1" ]; then
	find_tap_interface
	if [[ -z $TAP_INTERFACE ]]; then
		echo "[ERROR] network interface name is empty"
		exit 1;
	fi

	if [ "$MACADDR" == "" ]; then
		# if the user didn't supply a MAC address, generate one
		MACADDR=`echo -n 00:02:F7; dd bs=1 count=3 if=/dev/random 2>/dev/null |hexdump -v -e '/1 ":%02X"'`
		echo MACADDR=$MACADDR
	fi

	net="-C bp.hostbridge.interfaceName=$TAP_INTERFACE \
		-C bp.smsc_91c111.enabled=true \
		-C bp.smsc_91c111.mac_address=${MACADDR}"
fi

if [[ ! -z $FS_TYPE ]] && [ ${FS_TYPE,,} == "distro" ]; then

	if [[ -n "$SATADISK_IMAGE_PATH" ]]; then
		sata_disk_path="-C pci.ahci_pci.ahci.image_path=${SATADISK_IMAGE_PATH}"
	else
		echo "Error:Valid SATA hard disk image required to install the distribution image."
		echo "Please create sata disk image and export using SATADISK_IMAGE_PATH variable"
		exit 1
	fi
	remove_unused_virtio="-C pci.pcidevice0.bus=0xFF \
		-C pci.pcidevice1.bus=0xFF "
fi

if [ "$DISK" != "" ]; then
	disk_param=" -C bp.virtioblockdevice.image_path=$DISK "
fi

if [ "$IMAGE" != "" ]; then
	image_param="--data cluster0.cpu0=${IMAGE}@${kern_addr}"
fi
if [ "$INITRD" != "" ]; then
	initrd_param="--data cluster0.cpu0=${INITRD}@${initrd_addr}"
fi
if [ "$DTB" != "" ]; then
	dtb_param="--data cluster0.cpu0=${DTB}@${dtb_addr}"
fi

# Create log files with date stamps in the filename
# also create a softlink to these files with a static filename, eg, uart0.log
mkdir -p ./$MODEL_TYPE
datestamp=`date +%s%N`

UART0_LOG=uart0-${datestamp}.log
touch $MODEL_TYPE/$UART0_LOG
uart0log=uart0.log
rm -f $MODEL_TYPE/$uart0log
ln -s $UART0_LOG $MODEL_TYPE/$uart0log

UART1_LOG=uart1-${datestamp}.log
touch $MODEL_TYPE/$UART1_LOG
uart1log=uart1.log
rm -f $MODEL_TYPE/$uart1log
ln -s $UART1_LOG $MODEL_TYPE/$uart1log

echo "UART0_LOG=$PWD/$MODEL_TYPE/$UART0_LOG"
echo "UART1_LOG=$PWD/$MODEL_TYPE/$UART1_LOG"

cmd="$MODEL \
	-C pctl.startup=0.0.0.0 \
	-C bp.secure_memory=$SECURE_MEMORY \
	$cores \
	-C cache_state_modelled=$CACHE_STATE_MODELLED \
	-C bp.pl011_uart0.untimed_fifos=1 \
	-C bp.pl011_uart0.unbuffered_output=1 \
	-C bp.pl011_uart0.out_file=$MODEL_TYPE/$UART0_LOG \
	-C bp.pl011_uart1.out_file=$MODEL_TYPE/$UART1_LOG \
	-C bp.secureflashloader.fname=$BL1 \
	-C bp.flashloader0.fname=$FIP \
	$image_param \
	$dtb_param \
	$initrd_param \
	-C bp.ve_sysregs.mmbSiteDefault=0 \
	-C bp.ve_sysregs.exit_on_shutdown=1 \
	$disk_param \
	$VARS \
	$net \
	$arch_params \
	$sata_disk_path \
	$remove_unused_virtio
"


echo "Executing Model Command:"
echo $cmd


if [[ -v DISPLAY ]]; then
	$cmd
	exit
else

	tmp="$(mktemp -d)"
	$cmd >$tmp/port &
	sleep 1
	port=$(cat $tmp/port | grep -oPm1 "port\s+\K\w+")
	echo $port
	telnet localhost $port
	rm -rf $tmp/port
	kill -INT %%
	wait
	exit
fi
