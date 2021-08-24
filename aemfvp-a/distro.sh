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

installer_image=""
disk_size=""
mode=""

#Set default platform
platform="aemfvp-a"

#Network disabled by default
net_enable="false"

install ()
{

	#Sata disk output directory
	mkdir -p "$PWD/satadisk"

	export SATADISK_IMAGE_PATH="$PWD/satadisk/$RANDOM.satadisk"

	# Create a disk of $disk_size GB
	dd if=/dev/zero of=$SATADISK_IMAGE_PATH bs=1G count=$disk_size

	echo "Created $SATADISK_IMAGE_PATH of size $disk_size GB, proceeding to install $installer_image ..."

	./model-scripts/$platform/run_model.sh  -f distro
}


boot ()
{
	# Check if an installed sata disk image is supplied. If yes, boot from it.
	if [ ! -z "$disk_image" ] ; then
		dir_name="$(dirname $disk_image)"
		if [ $dir_name == "." ] ; then
			disk_image="$PWD/$disk_image"
		fi
		echo "Proceeding to boot supplied disk image name: $disk_image ..."
		export SATADISK_IMAGE_PATH=$disk_image
		./model-scripts/$platform/run_model.sh -f distro
		exit 0
	fi

	# If $disk_image is not specified, see if there are more than one
	# .satadisk files, if so, prompt the user to pick one with -d.
	# If there is exactly one available, boot it. If there are none, prompt
	# the user to install with -i/-s

	available_images=$(find . -name "*.satadisk")
	num_available_images=$(echo $available_images | wc -w)

	case $num_available_images in
		1)
			# In the case of exactly one, the list of images will
			# be the image name so just use it
			echo "Found $available_images, proceeding to boot ..."
			available_images=$PWD/$available_images
			export SATADISK_IMAGE_PATH=$available_images

			./model-scripts/$platform/run_model.sh -f distro
			;;
		*)
			if [[ -z "$disk_image" ]]; then
				echo "Found several available images:"
				echo ""
				echo $available_images | sed 's/\.\///g' | tr ' ' '\n'
				echo ""
				echo "Please choose one using distro_boot -d [disk_image]"
				echo ""
			fi
			;;
	esac
}

__print_examples()
{
	echo "Example 1: ./distro.sh -p $1 -i Fedora-Server-dvd-aarch64-34-1.2.iso -s 16"
	echo "  Installs Fedora 34 on to a 16 GB disk."
	echo ""
	echo "Example 2: ./distro.sh -p $1"
	echo "  Finds an available installed disk image and boots from it."
	echo ""
	echo "Example 3: ./distro.sh -p $1 -d fedora34.satadisk"
	echo "  Boot from an existing installed disk image"
}

print_usage ()
{
	echo ""
	echo "Install or boot linux distribution."
	echo "Usage: ./distro.sh -p <platform> -i <image> -s <disk size> [-d <disk image>] [-n <true|false>]"
	echo ""
	echo "Supported command line parameters:"
	echo "  -p   platform name (optional)"
	echo "		Supported platform is -"
	echo "		aemfvp-a"
	echo "  -i   Image, takes a path to an iso installer image (mandatory for installation)"
	echo "  -s   Disk size in GB (mandatory for installation)"
	echo "  -d   Disk image with previously installed distro, used for"
	echo "       disambiguation if there are more than one installed"
	echo "       concurrently."
	echo "  -n   Enable network: true or false (default: false)"
	echo ""
	__print_examples "aemfvp-a"
	echo ""
}

while getopts "p:i:s:d:n:h" opt; do
	case $opt in
		p)
			platform=$OPTARG
			;;
		i)
			installer_image=$OPTARG
			;;
		s)
			disk_size=$OPTARG
			;;
		d)
			disk_image=$OPTARG
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

# Either an installer and a disk size is specified or neither.
# If they are specified, create a new disk and boot the model with those params
# if not, check for an existing .satadisk file and use that to boot from
# otherwise throw an error

if [[ ! -z $disk_size ]] && [[ ! -z $installer_image ]]; then
	mode="install"
elif [[ -z $disk_size ]] && [[ -z $installer_image ]]; then

	# There is no need to separate the boot from single / multiple images
	# at this stage, we can handle that in boot()
	mode="boot"
else
	print_usage
	exit 1
fi

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

out_dir="output/$platform"
export BL1="$out_dir/$platform/tf-bl1.bin"
export FIP="$out_dir/$platform/fip-uefi.bin"
export DISK=$installer_image

if [ "${net_enable}" != "true" ] && [ "${net_enable}" != "false" ]; then
	echo "[ERROR] Unsupported <network_enabled> selected"
	print_usage
	exit 1;
fi

if  [ "${net_enable}" == "true" ]; then
	export NET=1
fi

case $mode in
	install)
		install
		;;
	boot)
		boot
		;;
	*)
		echo "Unknown mode"
		exit 1
		;;
esac
