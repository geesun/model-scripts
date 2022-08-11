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

RUN_SCRIPTS_DIR=$(dirname "$0")

#The help text.
#NOTE: The OPTIONS below are misaligned on purpose so that they appear aligned when the script is called.
help_text () {
	echo "<path_to_run_model.sh> [OPTIONS]"
	echo "OPTIONS:"
	echo "-m, --model				path to model"
	echo "-d, --distro				distro version, values supported [buildroot, android-swr]"
	echo "-a, --avb				[OPTIONAL] avb boot, values supported [true, false], DEFAULT: false"
	echo "-t, --tap-interface			[OPTIONAL] tap interface"
	echo "-e, --extra-model-params		[OPTIONAL] extra model parameters"
	exit 1
}

incorrect_script_use () {
	echo "Incorrect script use, call script as:"
	help_text
}

# check if directory exits and exit if it doesnt
check_dir_exists_and_exit () {
	if [ ! -d $1 ]
	then
		echo "directory for $2: $1 doesnt exist"
		exit 1
	fi
}

# check if first argument is a substring of 2nd argument and exit if thats not
# the case
check_substring_and_exit () {

	if [[ ! "$1" =~ "$2" ]]
	then
		echo "$1 does not contain $2"
		exit 1
	fi
}

# check if file exits and exit if it doesnt
check_file_exists_and_exit () {
	if [ ! -f $1 ]
	then
		echo "$1 does not exist"
		exit 1
	fi
}
check_android_images () {
	check_file_exists_and_exit $DEPLOY_DIR/system.img
	check_file_exists_and_exit $DEPLOY_DIR/userdata.img
	[ "$AVB" == true ] && check_file_exists_and_exit $DEPLOY_DIR/vbmeta.img
	[ "$AVB" == true ] && check_file_exists_and_exit $DEPLOY_DIR/boot.img
}

AVB=false

while [[ $# -gt 0 ]]
do
	key="$1"

	case $key in
	    -m|--model)
		    MODEL="$2"
		    shift
		    shift
		    ;;
	    -d|--distro)
		    DISTRO="$2"
		    shift
		    shift
		    ;;
	    -t|--tap-interface)
		    TAP_INTERFACE="$2"
		    shift
		    shift
		    ;;
	    -e|--extra-model-params)
		    EXTRA_MODEL_PARAMS="$2"
		    shift
		    shift
		    ;;
	    -a|--avb)
		    AVB="$2"
		    shift
		    shift
		    ;;
	    -h|--help)
		    help_text
		    ;;
		*)
			incorrect_script_use
	esac
done

[ -z "$MODEL" ] && incorrect_script_use || echo "MODEL=$MODEL"
[ -z "$DISTRO" ] && incorrect_script_use || echo "DISTRO=$DISTRO"
echo "TAP_INTERFACE=$TAP_INTERFACE"
echo "EXTRA_MODEL_PARAMS=$EXTRA_MODEL_PARAMS"
echo "AVB=$AVB"

if [ ! -f "$MODEL" ]; then
    echo "Path provided for model :$1 does not exist"
    exit 1
fi

DEPLOY_DIR=$RUN_SCRIPTS_DIR/../../build-scripts/output/deploy/tc2/

check_dir_exists_and_exit $DEPLOY_DIR "firmware and kernel images"

RSS_ROM_FILE="$DEPLOY_DIR/rss_rom.bin"
RSS_FLASH_FILE="$DEPLOY_DIR/rss_flash.bin"

case $DISTRO in
    buildroot)
		DISTRO_MODEL_PARAMS="--data board.dram=${DEPLOY_DIR}/tc-fitImage.bin@0x20000000"
        BL1_IMAGE_FILE="$DEPLOY_DIR/bl1-tc.bin"
        FIP_IMAGE_FILE="$DEPLOY_DIR/fip-tc.bin"
        ;;
    android-swr)
		DISTRO_MODEL_PARAMS="-C board.mmc.p_mmc_file=$DEPLOY_DIR/android.img"
		[ "$AVB" == true ] || DISTRO_MODEL_PARAMS="$DISTRO_MODEL_PARAMS \
			--data board.dram=$DEPLOY_DIR/ramdisk_uboot.img@0x8000000 \
			--data board.dram=$DEPLOY_DIR/Image@0x80000 "
        BL1_IMAGE_FILE="$DEPLOY_DIR/bl1-trusty-tc.bin"
        FIP_IMAGE_FILE="$DEPLOY_DIR/fip-trusty-tc.bin"

	DISTRO_MODEL_PARAMS="${DISTRO_MODEL_PARAMS} \
	-C board.smsc_91c111.enabled=1 \
	-C board.hostbridge.userNetworking=1 \
	-C board.hostbridge.userNetPorts=\"5555=5555,8080=80,8022=22\""
        ;;
    *) echo "bad option for distro $3"; incorrect_script_use
        ;;
esac

echo "DISTRO_MODEL_PARAMS=$DISTRO_MODEL_PARAMS"

if [ "$TAP_INTERFACE" ]
then
	echo "Enabling networking with interface $TAP_INTERFACE"
	TAP_INTERFACE_MODEL_PARAMS="-C board.hostbridge.interfaceName="$TAP_INTERFACE" \
	-C board.smsc_91c111.enabled=1 \
	"
fi

LOGS_DIR="$RUN_SCRIPTS_DIR"/logs
mkdir -p $LOGS_DIR

"$MODEL" \
    -C board.flashloader0.fname=${FIP_IMAGE_FILE} \
    -C soc.pl011_uart0.out_file=$LOGS_DIR/uart0_soc.log \
    -C soc.pl011_uart0.unbuffered_output=1 \
    -C soc.pl011_uart1.out_file=$LOGS_DIR/uart1_soc.log \
    -C soc.pl011_uart1.unbuffered_output=1 \
    -C css.pl011_uart_ap.out_file=$LOGS_DIR/uart_ap.log \
    -C css.pl011_uart_ap.unbuffered_output=1 \
    -C displayController=2 \
    --data css.rss.cpu=${RSS_ROM_FILE}@0x11000000 \
    --data css.rss.cpu=${RSS_FLASH_FILE}@0x31000000 \
    -C css.rss.VMADDRWIDTH=23 \
    -C css.scp.c0_pik.rvbaraddr_lw=0x1000 \
    -C css.scp.c0_pik.rvbaraddr_up=0x0000 \
    ${TAP_INTERFACE_MODEL_PARAMS} \
    ${DISTRO_MODEL_PARAMS} \
    ${EXTRA_MODEL_PARAMS}

exit $?
