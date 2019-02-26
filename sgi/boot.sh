#!/bin/bash
###############################################################################
# Copyright (c) 2018, ARM Limited and Contributors. All rights reserved.
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

declare -A sgi_platforms
sgi_platforms[sgi575]=1
sgi_platforms[rdn1edge]=1
sgi_platforms[sgiclarkh]=1

__print_supported_sgi_platforms()
{
	echo "Supported platforms are -"
	for plat in "${!sgi_platforms[@]}" ;
		do
			printf "\t $plat \n"
		done
	echo
}

print_usage ()
{
	echo ""
	echo "Boots upto busybox console on a specified SGI platform."
	echo "Usage: ./boot.sh -p <platform> [-n <true|false>] [-a \"model params\"] [-j <true|false>]"
	echo ""
	echo "Supported command line parameters - "
	echo "  -p   Specifies the SGI platform to be selected. See below for list of"
	echo "       SGI platforms supported \(mandatory\)"
	echo "  -n   Enable or disable network controller support on the platform \(optional\)."
	echo "       If not specified, network support is disabled by default."
	echo "  -j   Enable or disable auto termination of the model after booting upto"
	echo "       a busybox shell \(optional\). If not specified, default behaviour is"
	echo "       to keep the model executing."
	echo "  -a   Additional model parameters \(optional\)."
	echo ""
	__print_supported_sgi_platforms
	echo ""
	echo "Example 1: ./boot.sh -p sgi575"
	echo "  Starts the execution of the SGI-575 model and the software boots upto the"
	echo "  busybox prompt"
	echo ""
	echo "Example 2: ./boot.sh -p sgi575 -n true"
	echo "  Starts the execution of the SGI-575 model and the software boots upto the"
	echo "  busybox prompt. The model supports networking allowing the software running"
	echo "   within the model to access the network."
	echo ""
	echo "Example 3: ./boot.sh -p sgi575 -n true -a \"board.flash0.diagnostics=1\""
	echo "  Starts the execution of the SGI-575 model with networking enabled and the"
	echo "  software boots upto the busybox prompt. Additional parameters to the model"
	echo "  are supplied using the -a command line parameter."
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
pushd $platform_dir
set -- "$@" "-f" "busybox"
source ./run_model.sh

# if not model failed to start, return
if [ "$MODEL_PID" == "0" ] ; then
	exit 1
fi

# wait for boot to complete and the model to be killed
parse_log_file "$PWD/$platform/$UART0_ARMTF_OUTPUT_FILE_NAME" "/ #" 7200
ret=$?

kill_model
sleep 3

if [ "$ret" != "0" ]; then
	echo "[ERROR]: Busybox boot test failed or timedout!"
	exit 1
else
	echo "[SUCCESS]: Busybox boot test completed!"
fi

popd
exit 0
