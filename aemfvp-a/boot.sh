#!/bin/bash

# Copyright (c) 2021, ARM Limited and Contributors. All rights reserved.
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

readonly bootloader_options=(
"uefi"
"u-boot"
)

#Set default bootloader
bootloader="uefi"

#Set default platform
platform="aemfvp-a"

#Network disabled by default
net_enable="false"

__print_examples()
{
	echo "Example 1: ./boot.sh"
	echo "  Starts the execution of the $1 model and the software boots upto the"
	echo "  busybox prompt. Here the default platform and bootloader"
	echo "  selections are \"aemfvp-a\" and \"uefi\""
	echo ""
	echo "Example 2: ./boot.sh -p $1"
	echo "  Starts the execution of the $1 model and the software boots upto the"
	echo "  busybox prompt. Here the default bootloader selection is \"uefi\""
	echo ""
	echo "Example 3: ./boot.sh -p $1 -b [uefi|u-boot]"
	echo "  Starts the execution of the $1 model and the software boots upto the"
	echo "  busybox prompt. The selection of the bootloader to be either uefi or u-boot"
	echo "  is based on command line parameters."
	echo ""
	echo "Example 4: ./boot.sh -p $1 -b [uefi|u-boot] -n true"
	echo "  Starts the execution of the $1 model and the software boots upto the"
	echo "  busybox prompt. The selection of the bootloader to be either uefi or u-boot"
	echo "  is based on command line parameters. The model supports networking allowing"
	echo "  the software running within the model to access the network."
	echo ""
}

print_usage ()
{
	echo ""
	echo "Boots upto busybox console on a specified platform."
	echo "Usage: ./boot.sh -p <platform> [-b <uefi|u-boot>] [-n <true|false>]"
	echo ""
	echo "Supported command line parameters - "
	echo "  -p   Specifies the platform to be selected \(default/optional\)"
	echo "		Supported platform is -"
	echo "	     	aemfvp-a"
	echo "  -b   Specifies the bootloader to be selected \(optional\)"
	echo "		Supported bootloader options are -"
	echo "		${bootloader_options[@]}"
	echo "  -n   Enable or disable network controller support on the platform \(optional\)."
	echo "       If not specified, network support is disabled by default."
	echo ""
	__print_examples "aemfvp-a"
	echo ""
}

while getopts "p:b:n:h" opt; do
	case $opt in
		p)
			platform=$OPTARG
			;;
		b)
			bootloader=$OPTARG
			;;
		n)
			net_enable=$OPTARG
			;;
		*)
			print_usage
			exit 1
			;;
	esac
done

__parse_params_validate()
{
	#Ensure that the platform is supported
	if [ -z "$platform" ] ; then
		print_usage
		exit 1
	fi
	if [ "$platform" != "aemfvp-a" ]; then
		echo "[ERROR] Could not deduce which platform to execute on."
		echo "Supported platform is -"
		echo "aemfvp-a"
		exit 1
	fi
}

#Ensure that the platform is supported
__parse_params_validate

if [ "${bootloader}" != "uefi" ] && [ "${bootloader}" != "u-boot" ] ;then
	echo "[ERROR] Invalid bootloader selection"
	print_usage
	exit 1

fi

if [ "${net_enable}" != "true" ] && [ "${net_enable}" != "false" ]; then
	echo "[ERROR] Unsupported <network_enabled> selected"
	print_usage
	exit 1;
fi

out_dir="output/$platform"

BL1="$out_dir/$platform/tf-bl1.bin"

if [ "$bootloader" == "u-boot" ]; then
	FIP="$out_dir/$platform/fip-uboot.bin"
	IMAGE="$out_dir/$platform/Image"
	DTB="$out_dir/$platform/fvp-base-revc.dtb"
else
	FIP="$out_dir/$platform/fip-uefi.bin"
fi

if  [ "${net_enable}" == "true" ]; then
	NET=1
fi

DISK="$out_dir/components/$platform/grub-busybox.img"

source ./model-scripts/$platform/run_model.sh
