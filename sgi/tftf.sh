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

__print_examples()
{
	echo "Example 1: ./tftf.sh -p $1"
	echo "  Executes the Trusted Firmware-A tests on the $1 model and prints"
	echo "  the results on the console."
	echo ""
	echo "Example 2: ./tftf.sh -p $1 -j true"
	echo "  Executes the Trusted Firmware-A tests on $1 model and automatically"
	echo "  terminates the FVP model when the test is completed."
}

print_usage ()
{
	echo ""
	echo "Executes Trusted Firmware-A Tests on a specified SGI platform"
	echo "Usage: ./tftf.sh -p <platform> [-n <true|false>] [-j <true|false>] [-a \"model params\"]"
	echo ""
	echo "Supported command line parameters - "
	echo "  -p   Specifies the SGI platform to be selected. See below for list of"
	echo "       SGI platforms supported \(mandatory\)"
	echo "  -n   Enable or disable network controller support on the platform \(optional\)."
	echo "       If not specified, network support is disabled by default."
	echo "  -a   Additional model parameters \(optional\)."
	echo "  -j   Enable or disable auto termination of the model after executing the"
	echo "       tests \(optional\). If not specified, default behaviour is to keep the"
	echo "       model executing."
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
pushd $platform_dir
set -- "$@" "-f" "none"
source ./run_model.sh

# if not model failed to start, return
if [ "$MODEL_PID" == "0" ] ; then
	exit 1
fi

# wait for tests to complete and the model to be killed
parse_log_file "$PWD/$platform/$UART_NSEC_OUTPUT_FILE_NAME" "Exiting tests." 7200
ret=$?

kill_model
sleep 3

if [ "$ret" != "0" ]; then
	echo "[ERROR]: Trusted Firmware-A tests failed or timedout!"
	exit 1
else
	echo "[SUCCESS]: Trusted Firmware-A tests completed!"
fi

popd
exit 0
