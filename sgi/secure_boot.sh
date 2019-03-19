#!/bin/bash
###############################################################################
# Copyright (c) 2019, ARM Limited and Contributors. All rights reserved.
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
#################################################################################

platform_dir=""

source $PWD/../sgi/sgi_common_util.sh

# List of all the supported platforms.
declare -A platforms_sgi
platforms_sgi[sgi575]=1
declare -A platforms_rdinfra
platforms_rdinfra[rdn1edge]=1
platforms_rdinfra[rde1edge]=1

__print_examples()
{
	echo "Example 1: ./secure_boot.sh -p $1"
	echo "  Validates UEFI secure boot on $1 platform."
	echo
	echo "Example 2: ./secure_boot.sh -p $1 -j true"
	echo "  Validates UEFI secure boot on $1 platform and terminates the fvp model"
	echo "  automatically when the test ends."
}

print_usage ()
{
	echo ""
	echo "Validate secure boot with busybox"
	echo "Usage: ./secure_boot.sh -p <platform> [-n <true|false>] [-j <true|false>] [-a \"model params\"]"
	echo ""
	echo "Supported command line parameters - "
	echo "  -p   Platform name (mandatory)"
	echo "  -n   Enable network: true or false (default: false)"
	echo "  -j   Automate ras test: true or false (default: false)"
	echo "  -a   Additional model parameters, if any"
	echo ""
	__print_supported_platforms_$refinfra
	__print_examples_$refinfra
	echo ""
}

while getopts "p:n:a:j:h" opt; do
	case $opt in
		p)
			platform=$OPTARG
			;;
		j)
			automate=1
			;;
		n|a)
			;;
		*)
			print_usage
			exit 1
			;;
	esac
done

#Ensure that the platform is supported
__parse_params_validate

platform_dir="platforms/$platform"
disk_image="$platform/grub-busybox.img"

pushd $platform_dir
set -- "$@" "-v" "../../../../output/$disk_image"
if [[ $automate == 1 ]]; then
	wget http://files.oss.arm.com/releases/SSG-SW/prebuilts/refinfra/secure_boot/nor2_flash.img
fi
source ./run_model.sh

# if not model failed to start, return
if [ "$MODEL_PID" == "0" ] ; then
	exit 1
fi

# wait for boot to complete and the model to be killed
parse_log_file "$PWD/$platform/$UART0_ARMTF_OUTPUT_FILE_NAME" "UEFI Secure Boot is enabled" 7200
parse_log_file "$PWD/$platform/$UART0_ARMTF_OUTPUT_FILE_NAME" "/ #" 7200
ret=$?

kill_model
sleep 3

if [ "$ret" != "0" ]; then
	echo "[ERROR]: Secure Busybox boot test failed or timedout!"
	exit 1
else
	echo "[SUCCESS]: Secure Busybox boot test completed!"
fi

popd
exit 0
