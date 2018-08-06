#!/usr/bin/env bash

# This proprietary software may be used only as authorised by a licensing
# agreement from ARM Limited
# (C) COPYRIGHT 2015 ARM Limited
# The entire notice above must be reproduced on all authorised copies and
# copies may only be made to the extent permitted by a licensing agreement from
# ARM Limited.

# Set your ARMLMD_LICENSE_FILE License path for FVP licenses before running this script
# Either copy the model to this folder or fix for your FVP_CSS_SGI-575 path below
#


NORMAL_FONT="\e[0m"
RED_FONT="\e[31;1m"
GREEN_FONT="\e[32;1m"
YELLOW_FONT="\e[33;1m"
CURRENT_DATE="`date +%Y%m%d_%H-%M-%S`"
MYPID=$$

# Check that a path to the model has been provided
if [ ! -e "$MODEL" ]; then
	echo "ERROR: you should set variable MODEL to point to a valid SGI575
model binary, currently it is set to \"$MODEL\""
	exit 1
fi

#Path to the binary models
PATH_TO_MODEL=$(dirname "${MODEL}")

UART0_ARMTF_OUTPUT_FILE_NAME=sgi-${MYPID}-uart-0-armtf_$CURRENT_DATE
UART1_MM_OUTPUT_FILE_NAME=sgi-${MYPID}-uart-1-mm_$CURRENT_DATE
UART0_CONSOLE_OUTPUT_FILE_NAME=sgi-${MYPID}-uart-0-console_$CURRENT_DATE
UART0_SCP_OUTPUT_FILE_NAME=sgi-${MYPID}-uart-0-scp_$CURRENT_DATE
UART0_MCP_OUTPUT_FILE_NAME=sgi-${MYPID}-uart-0-mcp_$CURRENT_DATE


if [ $# -eq 0 ]; then
	echo -e "$YELLOW_FONT Warning!!!!!: Continuing with Default : -t sgi575 -f busybox <no network enabled> -v <no custom virtio image>" >&2
	echo -e "$YELLOW_FONT Use for more option  ${0##*/} -h|-- help $NORMAL_FONT" >&2
	MODEL_TYPE="sgi575";
	FS_TYPE="busybox";
	NTW_ENABLE="false";
	VIRT_IMG="false";
fi

# Display usage message and exit
function usage_help {
	echo -e "$GREEN_FONT usage: ${0##*/} -t <model_type> -n <interface_name> -f <fs_type> -v <virtio_image_path>" >&2
	echo -e "$GREEN_FONT model_type = $RED_FONT sgi575" >&2
	echo -e "$GREEN_FONT fs_type = $RED_FONT busybox $GREEN_FONT or $RED_FONT oe $GREEN_FONT lamp $RED_FONT" >&2
	echo -e "$GREEN_FONT network_enabled = $RED_FONT true $GREEN_FONT or $RED_FONT false $NORMAL_FONT" >&2
	echo -e "$GREEN_FONT virtio_imag_path = Please input virtio image path $NORMAL_FONT" >&2
}

while test $# -gt 0; do
	case "$1" in
		-h|--help)
			usage_help
			exit 1
			;;
		-t)
			shift
			if test $# -gt 0; then
				MODEL_TYPE=$1
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
		-d)
			shift
			if test $# -gt 0; then
				SATADISK_IMAGE_PATH=$1
			fi
			shift
			;;
		*)
			usage_help
			exit 1
			;;
esac
done

declare -r flavour=$(echo $MODEL_TYPE | cut -f1 -d_)
ROOTDIR="../../output/sgi575"
OUTDIR=${ROOTDIR}/enterprise

if [[ -z $MODEL_TYPE ]]; then
	echo -e "$RED_FONT Continue with <model_type> as sgi575 !!! $NORMAL_FONT" >&2
	MODEL_TYPE="sgi575";
fi

if [[ -z $NTW_ENABLE ]]; then
	echo -e "$RED_FONT Continue with <network_enabled> as false !!! $NORMAL_FONT" >&2
	NTW_ENABLE="false";
fi

if [ ${NTW_ENABLE,,} == "true" ]; then
	echo -e "$YELLOW_FONT Please input a unique bridge interface name for network setup $NORMAL_FONT" >&2
	read INTERFACE_NAME
	if [[ -z $INTERFACE_NAME ]]; then
		echo -e "$RED_FONT network interface name is empty $NORMAL_FONT" >&2
		exit 1;
	fi
fi

if [ ${NTW_ENABLE,,} != "true" ] && [ ${NTW_ENABLE,,} != "false" ]; then
	echo -e "$RED_FONT Unsupported <network_enabled> selected  $NORMAL_FONT" >&2
	usage_help
	exit 1;
fi

if [[ -z $BL1_IMAGE ]]; then
	echo -e "$RED_FONT Continue with <BL1_IMAGE> as tf-bl1.bin !!! $NORMAL_FONT" >&2
	BL1_IMAGE="tf-bl1.bin";
fi

if [[ -z $FIP_IMAGE ]]; then
	echo -e "$RED_FONT Continue with <FIP_IMAGE> as fip-uefi.bin !!! $NORMAL_FONT" >&2
	FIP_IMAGE="fip-uefi.bin";
fi

if [[ -z $VIRTIO_IMAGE_PATH && -z $SATADISK_IMAGE_PATH ]]; then
	if [[ "$TEST_NAME" == "sataboot" ]]; then
		IMAGE_DEV="pci.ahci.ahci"
		IMAGE_NAME_OE="grub-oe-sata.img"
		IMAGE_NAME_LAMP="grub-oe-lamp-sata.img"
	elif [[ "$TEST_NAME" == "ras" ]]; then
		IMAGE_DEV="board.virtioblockdevice"
		IMAGE_NAME_OE="grub-oe-ras.img"
		IMAGE_NAME_LAMP="grub-oe-lamp-ras.img"
	else
		IMAGE_DEV="board.virtioblockdevice"
		IMAGE_NAME_OE="grub-oe.img"
		IMAGE_NAME_LAMP="grub-oe-lamp.img"
	fi

	if [[ -z $FS_TYPE ]]; then
		echo -e "$RED_FONT Continue with <fs_type> as busybox !!! $NORMAL_FONT" >&2
		FS_TYPE="busybox";
	fi
	echo -e "$RED_FONT Continue with $FS_TYPE virtio image> !!! $NORMAL_FONT" >&2

	#Load supported FS type Virtio Image
	if [ ${FS_TYPE,,} == "oe" ]; then
		KERNEL_ARGS="-C ${IMAGE_DEV}.image_path=${ROOTDIR}/${IMAGE_NAME_OE}"
	elif [ ${FS_TYPE,,} == "lamp" ]; then
                KERNEL_ARGS="-C ${IMAGE_DEV}.image_path=${ROOTDIR}/${IMAGE_NAME_LAMP}"
	elif [ ${FS_TYPE,,} == "busybox" ]; then
		KERNEL_ARGS="-C board.virtioblockdevice.image_path=${ROOTDIR}/grub-busybox.img"
	else
		echo -e "$RED_FONT Unsupported <fs_type> selected $NORMAL_FONT" >&2
		usage_help
		exit 1;
	fi

else
	if [[ -n "$VIRTIO_IMAGE_PATH" ]]; then
		#To load customized Virtio images
		echo -e "$RED_FONT Continue with custom virtio image: $VIRTIO_IMAGE_PATH> !!! $NORMAL_FONT" >&2
		KERNEL_ARGS="-C board.virtioblockdevice.image_path=${VIRTIO_IMAGE_PATH}"
	fi
	if [[ -n "$SATADISK_IMAGE_PATH" ]]; then
		echo -e "$RED_FONT Continue with sata disk image: $SATADISK_IMAGE_PATH> !!! $NORMAL_FONT" >&2
		KERNEL_ARGS="$KERNEL_ARGS \
					-C pci.ahci.ahci.image_path="${SATADISK_IMAGE_PATH}""
	fi

fi

#For distribution installation and boot, ensure that the virtio devices
#behind the PCIe RC are not enumerated.
if [ ${FS_TYPE,,} == "distro" ]; then
	KERNEL_ARGS="$KERNEL_ARGS \
		-C pci.pcidevice0.bus=0xFF \
		-C pci.pcidevice1.bus=0xFF"
fi

if [ ${MODEL_TYPE} == "sgi575" ]; then
	mkdir -p ./$MODEL_TYPE
else
	echo -e "$RED_FONT Unsupported <model_type> selected $NORMAL_FONT" >&2
	usage_help
	exit 1;
fi

if [ ${NTW_ENABLE,,} == "true" ]; then
	BOOT_ARGS="$BOOT_ARGS \
		   -C board.hostbridge.interfaceName="$INTERFACE_NAME" \
		   -C board.smsc_91c111.enabled=1"
fi

#check whether crypto plugin exists
if [ -e $PATH_TO_MODEL_ROOT/plugins/Linux64_GCC-4.9/Crypto.so ]; then
	BOOT_ARGS="$BOOT_ARGS \
		   --plugin $PATH_TO_MODEL_ROOT/plugins/Linux64_GCC-4.9/Crypto.so"
fi
if [ ${MODEL_TYPE,,} == "sgi575" ]; then
	${MODEL} \
                -C css.cmn600.mesh_config_file="$PATH_TO_MODEL/SGI-575_cmn600.yml" \
		-C css.cmn600.force_on_from_start=1 \
                --data css.scp.armcortexm7ct=$OUTDIR/scp-ram.bin@0x0BD80000 \
                -C css.mcp.ROMloader.fname="$OUTDIR/mcp-rom.bin" \
                -C css.scp.ROMloader.fname="$OUTDIR/scp-rom.bin" \
                -C css.trustedBootROMloader.fname="$OUTDIR/$BL1_IMAGE" \
                -C board.flashloader0.fname="$OUTDIR/$FIP_IMAGE" \
                ${KERNEL_ARGS} \
                -S -R \
                -C css.scp.pl011_uart_scp.out_file=${MODEL_TYPE,,}/${UART0_SCP_OUTPUT_FILE_NAME} \
                -C css.pl011_uart_ap.out_file=${MODEL_TYPE,,}/${UART0_CONSOLE_OUTPUT_FILE_NAME} \
                -C soc.pl011_uart_mcp.out_file=${MODEL_TYPE,,}/${UART0_MCP_OUTPUT_FILE_NAME} \
                -C soc.pl011_uart0.out_file=${MODEL_TYPE,,}/${UART0_ARMTF_OUTPUT_FILE_NAME} \
                -C soc.pl011_uart0.unbuffered_output=1 \
                -C soc.pl011_uart1.out_file=${MODEL_TYPE,,}/${UART1_MM_OUTPUT_FILE_NAME} \
                -C soc.pl011_uart1.unbuffered_output=1 \
                -C css.pl011_uart_ap.unbuffered_output=1 \
               ${BOOT_ARGS}
else
	:
fi
