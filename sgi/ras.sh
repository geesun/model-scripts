#!/bin/bash

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

TOP_DIR="../../../.."
PREBUILTS=${TOP_DIR}/prebuilts
image_name="fedora.sgi.satadisk"
disk_name="$PREBUILTS/sgi/$image_name"
network=false
automate=false
extra_param=""
RUNDIR=$(pwd)
IP="10.0.2.16" #default IP
RC_ERROR=1

RESULT_LOG_FILE1=ras_test.log
RESULT_LOG_FILE2=ras_mm_test.log
RESULT_FILE=ras_test_result.log

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
	echo "Validate platform RAS error injection and handling"
	echo "Usage: ./ras.sh -p <platform> [-n <true|false>] [-j <true|false>] [-a \"model params\"]"
	echo ""
	echo "Supported command line parameters:"
	echo "	-p   SGI platform name (mandatory)"
	echo "	-n   Enable network: true or false (default: false)"
	echo "	-j   Automate ras test: true or false (default: false)"
	echo "	-a   Additional model parameters, if any"
	echo ""
	__print_supported_sgi_platforms
	echo "Example 1: ./ras.sh -p sgi575"
	echo "  Boot the distro image for RAS test."
        echo ""
	echo "Example 2: ./ras.sh -p sgi575 -n true"
	echo "  Boot the distro image for RAS test with network enabled."
	echo ""
	echo "Example 3: ./ras.sh -p sgi575 -j true -n true"
	echo "  Boot the distro image for RAS and automate the test."
	echo ""
	echo "Note: For automating the RAS test, it is a prerequisite to have"
	echo "      tap interface set in the host machine."
	echo ""
}

##
# inject DMC error
##
inject_dmc_error ()
{
    RET=1

    echo -e "\n${FG_YELLOW}** Injecting DMC error ...${FG_DEFAULT}\n"
	ssh  -o ServerAliveInterval=30 \
	 -o ServerAliveCountMax=720 \
	 -o StrictHostKeyChecking=no \
	 -o UserKnownHostsFile=/dev/null root@$IP \
	 'echo 0xdeadbeef > /sys/kernel/debug/sdei_ras_poison' 2>&1 | tee $log
    RET=$?
    return $RET
}

##
# get RAS results
##
get_ras_log ()
{
	RETUART0=0
	RETUART1=0
	local RESULT_FOLDER=$1

	echo -e "\n[Result] RAS log file at $RESULT_FOLDER/$RESULT_LOG_FILE1\n"
	echo -e "                           $RESULT_FOLDER/$RESULT_LOG_FILE2"

	cp $PWD/$platform/$UART0_ARMTF_OUTPUT_FILE_NAME $RESULT_FOLDER/$RESULT_LOG_FILE1
	cp $PWD/$platform/$UART1_MM_OUTPUT_FILE_NAME $RESULT_FOLDER/$RESULT_LOG_FILE2

	# Check if the log file contains the linux cper dump
	grep -q -s "Error 0, type: corrected" $RESULT_FOLDER/$RESULT_LOG_FILE1
	RETUART0=$?

	# Check if the MM log file contains the Error Interrupt dump
	grep -q -s "DMC620 RAS Error Type : SRAM" $RESULT_FOLDER/$RESULT_LOG_FILE2
	RETUART1=$?

	# If both dumps present, test passed, else test failed
	echo -e "\n[Result] RAS test result file at $RESULT_OUTPUT_FOLDER/$RESULT_FILE\n"
	if [[ $RETUART0 != 0 || $RETUART1 != 0 ]]; then
		echo -e "\n[Result] RAS test failed" > $RESULT_FOLDER/$RESULT_FILE
		return $RC_ERROR
	fi
	echo -e "\n[Result] RAS test passed" > $RESULT_FOLDER/$RESULT_FILE

	return 0
}

while getopts "p:n:a:j:h" opt; do
	case $opt in
		p)
			platform=$OPTARG
			;;
		j)
			automate=$OPTARG
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

if [ ! -f $disk_name ]; then
	echo "Disk image $image_name not found under prebuilts directory"
	print_usage
	exit 1
fi

RESULT_OUTPUT_FOLDER="$RUNDIR/platforms/$platform/$platform/ras"
echo "RAS Dir=$RESULT_OUTPUT_FOLDER"
mkdir -p $RESULT_OUTPUT_FOLDER

set -- "$@" -d $disk_name
source ./run_model.sh

# if not model failed to start, return
if [ "$MODEL_PID" == "0" ] ; then
	exit 1
fi

# Check if the distro booted till login prompt
parse_log_file "$PWD/$platform/$UART0_ARMTF_OUTPUT_FILE_NAME" "localhost login: " 7200
if [ $? -ne 0 ]; then
	echo -e "\n[ERROR]: System Boot failed or timed out!"
	kill_model
	exit 1
else
	echo -e "\n[INFO] System Booted!"
fi

echo "System Booted!!!"

# Get the IP address of the model
get_ip_addr_fedora IP

#injecting DMC memory error
echo "Injecting DMC Error"
inject_dmc_error
if [ $? -ne 0 ]; then
	kill_model
	echo "Failed to inject RAS error"
	exit 1
fi
echo "Done injecting DMC error"

#sleep for 30 seconds till error injected handled on mm side
sleep 30

#get RAS log data
echo "Collecting RAS logs"
get_ras_log $RESULT_OUTPUT_FOLDER
if [ $? -ne 0 ]; then
	echo "RAS test failed"
	kill_model
	exit 1
else
	echo "RAS test passed!"
fi

echo "Done collecting RAS logs"

send_shutdown $RESULT_OUTPUT_FOLDER/$RESULT_LOG_FILE1 $IP

kill_model
popd
exit 0
