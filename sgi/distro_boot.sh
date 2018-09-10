#!/bin/bash

installer_image=""
disk_size=""
mode=""
platform_dir=""
network=false
extra_param=""

declare -A sgi_platforms
sgi_platforms[sgi575]=1

__print_supported_sgi_platforms()
{
	echo "Supported platforms are -"
	for plat in "${!sgi_platforms[@]}" ;
		do
			printf "\t $plat \n"
		done
	echo
}

install ()
{
	disk_name="$PWD/$RANDOM.satadisk"

	# Create a disk of $disk_size GB
	dd if=/dev/zero of=$disk_name bs=1G count=$disk_size

	echo "Created $disk_name of size $disk_size GB, proceeding to install $installer_image ..."

	pushd $platform_dir
	./run_model.sh -v $installer_image -d $disk_name -n $network -a "$extra_param"
}

# This script allows a user to create a virtual satadisk and install either
# Fedora 27 or Debian 9.3 on to it or boot an existing install.

boot ()
{
	# Check if a installed sata disk image is supplied. If yes, boot from it.
	if [ ! -z "$disk_image" ] ; then
		dir_name="$(dirname $disk_image)"
		if [ $dir_name == "." ] ; then
			disk_image="$PWD/$disk_image"
		fi
		echo "Proceeding to boot supplied disk image name: $disk_image ..."
		pushd $platform_dir
		./run_model.sh -d $disk_image -n $network -a "$extra_param"
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
			pushd $platform_dir
			./run_model.sh -d $available_images -n $network -a "$extra_param"
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

print_usage ()
{
	echo "distro_boot:"
	echo ""
	echo " Install or boot Linux distos on System Guidance Models."
	echo ""
	echo "distro_boot -p [platform] -i [image] -s [disk size] -d [ disk image]"
	echo "	-p - SGI platform name"
	echo "	-i - Image, takes a path to an iso installer image"
	echo "	-s - Disk size in GB."
	echo "	-d - Disk image with previously installed distro, used for"
	echo "	     disambiguation if there are more than one installed"
	echo "	     concurrently"
	echo "  -n - Enable network: true or (default)false"
	echo "  -a - Additional model parameters, if any"
	echo ""
	echo " distro_boot must be called either with both -i and -s options or"
	echo " with neither, please see examples below"
	echo ""
	echo "Examples:"
	echo ""
	echo "	Install Fedora 27 on to a 16 GB disk"
	echo ""
	echo "		distro_boot -p sgi575 -i Fedora-Server-dvd-aarch64-27-1.6.iso -s 16"
	echo ""
	echo "	Boot existing single install"
	echo ""
	echo "		distro_boot -p sgi575"
	echo ""
	echo "	Boot existing install from a set of intalled disks"
	echo ""
	echo "		distro_boot -p sgi575 -d bluepeter.satadisk"
	echo ""
}

while getopts "p:i:s:d:n:a:h" opt; do
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
			network=$OPTARG
			;;
		a)
			extra_param=$OPTARG
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

#Ensure that the platform is supported
if [ -z "$platform" ] ; then
	print_usage
	exit 1
fi
if [ -z "${sgi_platforms[$platform]}" ] ; then
	echo "[ERROR] Could not deduce the selected platform."
	__print_supported_sgi_platforms
	exit 1
fi

platform_dir="platforms/$platform"

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
