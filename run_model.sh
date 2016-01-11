#!/bin/bash

# Copyright (c) 2015, ARM Limited and Contributors. All rights reserved.
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

# $1 - the output dir to run in the model
rundir=$1

# If the run dir is not set, use the current dir
if [ "$rundir" != "" ]; then
	if [ -e $rundir ]; then
		cd $rundir
	else
		echo "ERROR: you set the run directory to $rundir, however that path does not exist"
		exit 1
	fi
fi

# Check for obvious errors and set err=1 if we encounter one
if [ ! -e "$MODEL" ]; then
	echo "ERROR: you should set variable MODEL to point to a valid FVP model binary, currently it is set to \"$MODEL\""
	err=1
else
	# Check if we are running the foundation model or the AEMv8 model
	if [[ $($MODEL --version) == *Foundation* ]]; then
		FOUNDATION=1
	else
		FOUNDATION=0
	fi

fi

# Set some sane defaults before continuing to error check
BL1=${BL1:-bl1.bin}
FIP=${FIP:-fip.bin}
IMAGE=${IMAGE:-Image}
INITRD=${INITRD:-ramdisk.img}
CLUSTER0_NUM_CORES=${CLUSTER0_NUM_CORES:-1}
CLUSTER1_NUM_CORES=${CLUSTER1_NUM_CORES:-1}

# Set defaults based on model type
if [ "$FOUNDATION" == "1" ]; then
	DTB=${DTB:-fvp-foundation-gicv2-psci.dtb}
else
	DTB=${DTB:-fvp-base-gicv2-psci.dtb}
fi

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
	echo "ERROR: you should set variable IMAGE to point to a valid kernel image, currently it is set to \"$IMAGE\""
	err=1
fi
if [ ! -e "$INITRD" ]; then
	echo "ERROR: you should set variable INITRD to point to a valid initrd/ramdisk image, currently it is set to \"$INITRD\""
	err=1
fi
if [ ! -e "$DTB" ]; then
	echo "ERROR: you should set variable DTB to point to a valid device tree binary (.dtb), currently it is set to \"$DTB\""
	err=1
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

kern_addr=0x80080000
dtb_addr=0x83000000
initrd_addr=0x84000000

if [ "$FOUNDATION" == "1" ]; then
	GICV3=${GICV3:-1}
	echo "GICV3=$GICV3"

	if [ "$DISK" != "" ]; then
		disk_param=" --block-device=$DISK " 
	fi

	if [ "$SECURE_MEMORY" == "1" ]; then
		secure_memory_param=" --secure-memory"
	else
		secure_memory_param=" --no-secure-memory"
	fi

	if [ "$GICV3" == "1" ]; then
		gic_param=" --gicv3"
	else
		gic_param=" --no-gicv3"
	fi

	cmd="$MODEL \
	--cores=$CLUSTER0_NUM_CORES \
	$secure_memory_param \
	--visualization \
	$gic_param \
	--data=${BL1}@0x0 \
	--data=${FIP}@0x8000000 \
	--data=${IMAGE}@${kern_addr} \
	--data=${DTB}@${dtb_addr} \
	--data=${INITRD}@${initrd_addr} \
	$disk_param \
	"
else
	CACHE_STATE_MODELLED=${CACHE_STATE_MODELLED:=0}
	echo "CACHE_STATE_MODELLED=$CACHE_STATE_MODELLED"

	if [ "$DISK" != "" ]; then
		disk_param=" -C bp.virtioblockdevice.image_path=$DISK "
	fi

	cmd="$MODEL \
	-C pctl.startup=0.0.0.0 \
	-C bp.secure_memory=$SECURE_MEMORY \
	-C cluster0.NUM_CORES=$CLUSTER0_NUM_CORES \
	-C cluster1.NUM_CORES=$CLUSTER1_NUM_CORES \
	-C cache_state_modelled=$CACHE_STATE_MODELLED \
	-C bp.pl011_uart0.untimed_fifos=1 \
	-C bp.secureflashloader.fname=$BL1 \
	-C bp.flashloader0.fname=$FIP \
	--data cluster0.cpu0=${IMAGE}@${kern_addr} \
	--data cluster0.cpu0=${DTB}@${dtb_addr} \
	--data cluster0.cpu0=${INITRD}@${initrd_addr} \
	-C bp.ve_sysregs.mmbSiteDefault=0 \
	$disk_param \
	$VARS \
	"
fi

echo "Executing Model Command:"
echo "  $cmd"

$cmd
