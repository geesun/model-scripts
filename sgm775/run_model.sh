#!/bin/bash
# This proprietary software may be used only as authorised by a licensing
# agreement from ARM Limited
# (C) COPYRIGHT 2015 ARM Limited
# The entire notice above must be reproduced on all authorised copies and
# copies may only be made to the extent permitted by a licensing agreement from
# ARM Limited.

# Set your ARMLMD_LICENSE_FILE License path for FVP licenses before running this script
# Copy the required model binary and the shared libraries to the buzz/collins/armstrong folder

# To setup Network
# Add these lines in your /etc/network/interfaces
#################################################
# auto lo
# iface lo inet loopback

# The primary network interface
# auto eth0
# iface eth0 inet dhcp

# auto virbr0
# iface virbr0 inet dhcp
# bridge_ports eth0 virbr0
# bridge_stp off
# bridge_fd 0
# bridge_maxwait 0
################################################

# Add these in the command line before running this script
################################################
#$ sudo ip tuntap add dev {interface name} mode tap user {your system loginId e.g oobtwin is our case}
#$ sudo ifconfig {interface name} 0.0.0.0 promisc up
#$ sudo brctl addif virbr0 {interface name}
#$ iptables -F
################################################

NORMAL_FONT="\e[0m"
RED_FONT="\e[31;1m"
GREEN_FONT="\e[32;1m"
YELLOW_FONT="\e[33;1m"
CURRENT_DATE="`date +%Y%m%d_%H-%M-%S`"
MYPID=$$

# Check that a path to the model has been provided
if [ ! -e "$MODEL" ]; then
	echo "ERROR: you should set variable MODEL to point to a valid SGM775
model binary, currently it is set to \"$MODEL\""
	exit 1
fi

#Path to the binary models
PATH_TO_MODEL=$(dirname "${MODEL}")

PATH_TO_MODEL_ROOT="${PATH_TO_MODEL}/../../"

# Check that a path to the model has been provided
if [ ! -e "$MODEL" ]; then
	echo "ERROR: you should set variable MODEL to point to a valid SGM775
model binary, currently it is set to \"$MODEL\""
	exit 1
fi

# GGA/GRM specific
PATH_TO_SIDECHANNEL_LIB="$PATH_TO_MODEL_ROOT/plugins/Linux64_GCC-4.9/Sidechannel.so"
PATH_TO_RECONCILER_LIB="$PATH_TO_MODEL_ROOT/GGA/reconciler/linux-x86_64/gcc-4.9.2/rel/libReconciler.so"
PATH_TO_SETTINGS_INI_GENERATOR="settings_generator.sh"

UART0_OUTPUT_FILE_NAME=sgm775-${MYPID}-uart-0_$CURRENT_DATE
UART1_OUTPUT_FILE_NAME=sgm775-${MYPID}-uart-1_$CURRENT_DATE

#Remove the old settings.ini file if any
if [ -f "./settings.ini" ]; then
    rm -f "./settings.ini"
fi

if [ $# -eq 0 ]; then
	MODEL_TYPE="sgm775";
	DISPLAY_SEL="dp";
	FS_TYPE="busybox";
	BOOT_LOADER="uboot";
	RENDERING="gpu";
	NTW_ENABLE="false";
	EMULATOR_RUN="false";
	VIRT_IMG="false";

	echo -e "$YELLOW_FONT Warning!!!!!: Continuing with Default : -t $MODEL_TYPE -d $DISPLAY_SEL -f $FS_TYPE -b $BOOT_LOADER -s $RENDERING -n $NTW_ENABLE -e $EMULATOR_RUN" >&2
	echo -e "$YELLOW_FONT Use for more option  ${0##*/} -h | --help $NORMAL_FONT" >&2
fi

# Display usage message
function usage_help {
	echo -e "$GREEN_FONT usage: ${0##*/} -t <model_type> -d <display> -f <fs_type> -b <boot_loader_type> -n <network_enabled> -e <emulator_run> -s <rendering> -v <virtio_image_path>" >&2
	echo -e "$GREEN_FONT model_type = $RED_FONT sgm775" >&2
	echo -e "$GREEN_FONT display = $RED_FONT dp $GREEN_FONT or $RED_FONT hdlcd" >&2
	echo -e "$GREEN_FONT fs_type = $RED_FONT android $GREEN_FONT or $RED_FONT busybox $GREEN_FONT or $RED_FONT oe $GREEN_FONT or $RED_FONT lamp" >&2
	echo -e "$GREEN_FONT boot_loader_type = $RED_FONT uboot $GREEN_FONT or $RED_FONT uefi" >&2
	echo -e "$GREEN_FONT network_enabled = $RED_FONT true $GREEN_FONT or $RED_FONT false $NORMAL_FONT" >&2
	echo -e "$GREEN_FONT emulator_run = $RED_FONT true $GREEN_FONT or $RED_FONT false $NORMAL_FONT" >&2
	echo -e "$GREEN_FONT rendering = $RED_FONT gpu $GREEN_FONT or $RED_FONT swr (software renderer) $NORMAL_FONT" >&2
	echo -e "$GREEN_FONT virtio_imag_path = Please input virtio image path $NORMAL_FONT" >&2
}

while test $# -gt 0; do
	case "$1" in
		-h|--help)
			shift
			usage_help
			exit 1
			shift
			;;
		-t)
			shift
			if test $# -gt 0; then
				MODEL_TYPE=$1
			fi
			shift
			;;
		-m)
			shift
			if test $# -gt 0; then
				MODEL_MEM_VARIANT=$1
			fi
			shift
			;;
		-d)
			shift
			if test $# -gt 0; then
				DISPLAY_SEL=$1
			fi
			shift
			;;
		-f)
			shift
			if test $# -gt 0; then
				FS_TYPE=$1
			fi
			shift
			;;
		-b)
			shift
			if test $# -gt 0; then
				BOOT_LOADER=$1
			fi
			shift
			;;
		-n)
			shift
			if test $# -gt 0; then
				NTW_ENABLE=$1
			fi
			shift
			;;
		-v)
			shift
			if test $# -gt 0; then
				VIRTIO_IMAGE_PATH=$1
			fi
			shift
			;;
		-e)
			shift
			if test $# -gt 0; then
				EMULATOR_RUN=$1
			fi
			shift
			;;
		-s)
			shift
			if test $# -gt 0; then
				RENDERING=$1
			fi
			shift
			;;
		*)
			echo -e "$RED_FONT Unknown option $1 $NORMAL_FONT" >&2
			usage_help
			exit 1
			break
			;;
esac
done

if [[ -z $MODEL_TYPE ]]; then
	echo -e "$RED_FONT Continue with <model_type> as sgm775 !!! $NORMAL_FONT" >&2
	MODEL_TYPE="sgm775";
fi
if [[ -z $DISPLAY_SEL ]]; then
	echo -e "$RED_FONT Continue with <display> as dp !!! $NORMAL_FONT" >&2
	DISPLAY_SEL="dp";
fi
if [[ -z $FS_TYPE ]]; then
	echo -e "$RED_FONT Continue with <fs_type> as busybox !!! $NORMAL_FONT" >&2
	FS_TYPE="busybox";
fi
if [[ -z $BOOT_LOADER ]]; then
	echo -e "$RED_FONT Continue with <boot_loader_type> as uboot !!! $NORMAL_FONT" >&2
	BOOT_LOADER="uboot";
fi

if [[ -z $BL1_IMAGE ]]; then
        echo -e "$RED_FONT Continue with <BL1_IMAGE> as tf-bl1.bin !!! $NORMAL_FONT" >&2
        BL1_IMAGE="tf-bl1.bin";
fi

if [[ -z $FIP_IMAGE ]]; then
	if [ ${BOOT_LOADER,,} == "uboot" ]; then
		echo -e "$RED_FONT Continue with <FIP_IMAGE> as fip-uboot.bin !!! $NORMAL_FONT" >&2
		FIP_IMAGE="fip-uboot.bin";
	else
		echo -e "$RED_FONT Continue with <FIP_IMAGE> as fip-uefi.bin !!! $NORMAL_FONT" >&2
		FIP_IMAGE="fip-uefi.bin";
	fi
fi

if [[ -z $NTW_ENABLE ]]; then
	echo -e "$RED_FONT Continue with <network_enabled> as false !!! $NORMAL_FONT" >&2
	NTW_ENABLE="false";
fi
if [[ -z $EMULATOR_RUN ]]; then
	echo -e "$RED_FONT Continue with <emulator_run> as false !!! $NORMAL_FONT" >&2
	EMULATOR_RUN="false";
fi
if [[ -z $RENDERING ]]; then
    if [[ $FS_TYPE == "android" ]]
    then
	echo -e "$RED_FONT Continue with <rendering> as gpu !!! $NORMAL_FONT" >&2
	RENDERING="gpu";
    fi
fi
if [ ${NTW_ENABLE,,} != "true" ] && [ ${NTW_ENABLE,,} != "false" ]; then
	echo -e "$RED_FONT Unsupported <network_enabled> selected  $NORMAL_FONT" >&2
	usage_help
	exit 1;
fi
if [[ ${RENDERING,,} != "swr" && ${RENDERING,,} != "gga" && ${RENDERING,,} != "gpu" ]]; then
	if [[ $FS_TYPE == "android" ]]
	then
		echo -e "$RED_FONT Unsupported <rendering> selected  $NORMAL_FONT" >&2
		usage_help
		exit 1;
	fi
fi
if [ ${NTW_ENABLE,,} == "true" ]; then
	echo -e "$YELLOW_FONT Please input a unique bridge interface name for network setup $NORMAL_FONT" >&2
	read INTERFACE_NAME
	if [[ -z $INTERFACE_NAME ]]; then
		echo -e "$RED_FONT network interface name is empty $NORMAL_FONT" >&2
		exit 1;
	fi
fi

if [[ -z $VIRTIO_IMAGE_PATH ]]; then
	VIRT_IMG="false";
else
	VIRT_IMG="true";
fi

# Set model options:
# -S, --cadi-server                                   start CADI server allowing debuggers to connect to targets in the simulation
# -R, --run                                           run simulation immediately after load even with CADI server
# -p, --print-port-number                             print port number CADI server is listening to
# See "./sgm775-model/FVP_CSS_SGM-775 --help" for more option
BOOT_ARGS="$BOOT_ARGS \
	  -RSp"

# Model Type and Configuration
if [ ${MODEL_TYPE} == "sgm775" ]; then
	MODEL_NAME="$PATH_TO_MODEL"/FVP_CSS_SGM-775
	mkdir -p ./$MODEL_TYPE
else
	echo -e "$RED_FONT Unsupported <model_type> selected $NORMAL_FONT" >&2
	usage_help
	exit 1;
fi

# Display Controller
if [ ${DISPLAY_SEL,,} == "dp" ]; then
	Controller=2;
elif [ ${DISPLAY_SEL,,} == "hdlcd" ]; then
	Controller=0;
else
	echo -e "$RED_FONT Unsupported <display> selected $NORMAL_FONT" >&2
	usage_help
	exit 1;
fi

ADDRESS_RAMDISK=0x88000000
ADDRESS_KERNEL=0x80080000
ADDRESS_DTB=0x83000000
ROOTDIR="../../output/sgm775"
OUTDIR=${ROOTDIR}/sgm775
PREBUILT_DIR=../../../../prebuilts

# Virtio Kernel
if [ ${VIRT_IMG,,} == "true" ]; then
	if [ -e ${VIRTIO_IMAGE_PATH} ]; then
		KERNEL_ARGS="-C board.virtioblockdevice.image_path=${VIRTIO_IMAGE_PATH}"
	else
		echo -e "$RED_FONT Invalid Virtio Image path - File does not exist $NORMAL_FONT" >&2
		usage_help
		exit 1;
	fi
else
	if [ ${FS_TYPE,,} == "android" ]; then
		KERNEL_ARGS="-C board.virtioblockdevice.image_path=${ROOTDIR}/sgm775-android.img"
	elif [ ${FS_TYPE,,} == "oe" ]; then
    		KERNEL_ARGS="-C board.virtioblockdevice.image_path=${PREBUILT_DIR}/oe/oe-minimal.img"
	elif [ ${FS_TYPE,,} == "lamp" ]; then
		KERNEL_ARGS="-C board.virtioblockdevice.image_path=${PREBUILT_DIR}/oe/oe-lamp.img"
	elif [ ${FS_TYPE,,} == "busybox" ]; then
		KERNEL_ARGS="--data css.cluster0.cpu0=${OUTDIR}/Image.mobile_bb@${ADDRESS_KERNEL}"
	else
		KERNEL_ARGS=""
	fi
fi


# File system Type
# Android
if [ ${FS_TYPE,,} == "android" ]; then

	# Check for Emulator Run only affects Android
	if [ ${EMULATOR_RUN,,} == "true" ]; then
		LINUX_BIN_NAME="android_emu_64"
		BOOT_ARGS="$BOOT_ARGS --data css.cluster0.cpu0=${ROOTDIR}/sgm775-android.img@0x880000000 "
	else
		LINUX_BIN_NAME="android_64"
		BOOT_ARGS="$BOOT_ARGS ${KERNEL_ARGS}"

		# Only do the include of the libraries for Android.
		if [ ${RENDERING,,} == "gga" ] || [ ${RENDERING,,} == "gpu" ]; then
			if [ ! -f "$PATH_TO_SIDECHANNEL_LIB" ]; then
				echo -e "$RED_FONT Side Channel library could not be found at \"$PATH_TO_SIDECHANNEL_LIB\"!$NORMAL_FONT" >&2
				exit 1
			fi

			if [ ! -f "$PATH_TO_RECONCILER_LIB" ]; then
				echo -e "$RED_FONT Reconciler library could not be found at \"$PATH_TO_RECONCILER_LIB\"!$NORMAL_FONT" >&2
				exit 1
			fi

			BOOT_ARGS="$BOOT_ARGS \
				   --plugin $PATH_TO_SIDECHANNEL_LIB \
				   -C DEBUG.Sidechannel.interceptor=$PATH_TO_RECONCILER_LIB"

			if [ ! -f "$PATH_TO_SETTINGS_INI_GENERATOR" ]; then
				echo -e "$RED_FONT Script settings_generator.sh could not be found at \"$PATH_TO_SETTINGS_INI_GENERATOR\"!$NORMAL_FONT" >&2
				exit 1
			fi

			# Creation of the settings.ini file only for GGA - GRM
			"./$PATH_TO_SETTINGS_INI_GENERATOR" $RENDERING "`pwd`"
		fi
	fi

	if [ ${BOOT_LOADER,,} == "uboot" ]; then
		BOOT_ARGS="$BOOT_ARGS -C css.cache_state_modelled=0 \
		--data css.cluster0.cpu0=${ROOTDIR}/sgm775-uInitrd-android.${ADDRESS_RAMDISK}@${ADDRESS_RAMDISK} \
		-C board.flashloader0.fname=${OUTDIR}/$FIP_IMAGE \
		--data css.cluster0.cpu0=${OUTDIR}/uImage.${ADDRESS_KERNEL}.${LINUX_BIN_NAME}@${ADDRESS_KERNEL}"
	else
		BOOT_ARGS="$BOOT_ARGS -C css.cache_state_modelled=0 \
		--data css.cluster0.cpu0=${ROOTDIR}/sgm775-ramdisk-android.img@${ADDRESS_RAMDISK} \
		-C board.flashloader0.fname=${OUTDIR}/$FIP_IMAGE \
		--data css.cluster0.cpu0=${OUTDIR}/Image.${LINUX_BIN_NAME}@${ADDRESS_KERNEL}"
	fi

# OE
elif [ ${FS_TYPE,,} == "oe" ]; then
	if [ ${BOOT_LOADER,,} == "uboot" ]; then
		BOOT_ARGS="$BOOT_ARGS -C css.cache_state_modelled=0 \
		--data css.cluster0.cpu0=${ROOTDIR}/uInitrd-oe.${ADDRESS_RAMDISK}@${ADDRESS_RAMDISK} \
		${KERNEL_ARGS} \
		-C board.flashloader0.fname=${OUTDIR}/$FIP_IMAGE \
		--data css.cluster0.cpu0=${OUTDIR}/uImage.${ADDRESS_KERNEL}.sgm775_oe_64@${ADDRESS_KERNEL}"

	else
		BOOT_ARGS="$BOOT_ARGS -C css.cache_state_modelled=0 \
		--data css.cluster0.cpu0=${ROOTDIR}/ramdisk-oe.img@${ADDRESS_RAMDISK} \
		${KERNEL_ARGS} \
		-C board.flashloader0.fname=${OUTDIR}/$FIP_IMAGE \
		--data css.cluster0.cpu0=${OUTDIR}/Image.sgm775_oe_64@${ADDRESS_KERNEL}"
	fi
# Lamp
elif [ ${FS_TYPE,,} == "lamp" ]; then
	if [ ${BOOT_LOADER,,} == "uboot" ]; then
		BOOT_ARGS="$BOOT_ARGS -C css.cache_state_modelled=0 \
		--data css.cluster0.cpu0=${ROOTDIR}/uInitrd-oe.${ADDRESS_RAMDISK}@${ADDRESS_RAMDISK} \
		${KERNEL_ARGS} \
		-C board.flashloader0.fname=${OUTDIR}/$FIP_IMAGE \
		--data css.cluster0.cpu0=${OUTDIR}/uImage.${ADDRESS_KERNEL}.sgm775_oe_64@${ADDRESS_KERNEL}"
	else
		BOOT_ARGS="$BOOT_ARGS -C css.cache_state_modelled=0 \
		--data css.cluster0.cpu0=${ROOTDIR}/ramdisk-oe.img@${ADDRESS_RAMDISK} \
		${KERNEL_ARGS} \
		-C board.flashloader0.fname=${OUTDIR}/$FIP_IMAGE \
		--data css.cluster0.cpu0=${OUTDIR}/Image.sgm775_oe_64@${ADDRESS_KERNEL}"
	fi
# Busybox
elif [ ${FS_TYPE,,} == "busybox" ]; then
	if [ ${BOOT_LOADER,,} == "uboot" ]; then
		BOOT_ARGS="$BOOT_ARGS -C css.cache_state_modelled=0 \
		--data css.cluster0.cpu0=${ROOTDIR}/uInitrd-busybox.${ADDRESS_RAMDISK}@${ADDRESS_RAMDISK} \
		-C board.flashloader0.fname=${OUTDIR}/$FIP_IMAGE \
		--data css.cluster0.cpu0=${OUTDIR}/uImage.${ADDRESS_KERNEL}.mobile_bb@${ADDRESS_KERNEL}"
	else
		BOOT_ARGS="$BOOT_ARGS -C css.cache_state_modelled=0 \
		--data css.cluster0.cpu0=${ROOTDIR}/ramdisk-busybox.img@${ADDRESS_RAMDISK} \
		${KERNEL_ARGS} \
		-C board.flashloader0.fname=${OUTDIR}/$FIP_IMAGE"
	fi
else
	echo -e "$RED_FONT Unsupported <fs_type> selected $NORMAL_FONT" >&2
	usage_help
	exit 1;
fi

if [ ${NTW_ENABLE,,} == "true" ]; then
	BOOT_ARGS="$BOOT_ARGS \
		   -C board.hostbridge.interfaceName="$INTERFACE_NAME" \
		   -C board.smsc_91c111.enabled=1"
fi

${MODEL_NAME} \
	-C css.trustedBootROMloader.fname="${OUTDIR}/$BL1_IMAGE" \
	-C css.scp.ROMloader.fname="${OUTDIR}/scp-rom.bin" \
	-C soc.pl011_uart0.out_file="${MODEL_TYPE,,}/$UART0_OUTPUT_FILE_NAME" \
	-C soc.pl011_uart1.out_file="${MODEL_TYPE,,}/$UART1_OUTPUT_FILE_NAME" \
	-C soc.pl011_uart0.unbuffered_output=1 \
	-C config_id=0 \
	-C displayController=$Controller \
	${BOOT_ARGS}
