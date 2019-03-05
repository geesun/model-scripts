#!/usr/bin/env bash

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
image_name="fedora.satadisk"
disk_name="$PREBUILTS/refinfra/$image_name"
network=false
automate=0
extra_param=""
RUNDIR=$(pwd)
IP="10.0.2.16" # defualt IP
RC_ERROR=1

source $PWD/../sgi/sgi_common_util.sh

HOST_OS_LOG_FILE=kvm_test_host_os_${MYPID}_$CURRENT_DATE_TIME.log
GUEST_OS0_BOOT_LOG=kvm_test_guest_os0_${MYPID}_$CURRENT_DATE_TIME.log

# List of all the supported platforms.
declare -A platforms_sgi
platforms_sgi[sgi575]=1
declare -A platforms_rdinfra
platforms_rdinfra[rdn1edge]=1
platforms_rdinfra[rde1edge]=1

##
# Start guest os with lkvm
##
start_guest_os () {
	RET=1

	echo -e "\n[INFO] Starting Guest OS ...\n"
	mkdir -p $RESULT_OUTPUT_FOLDER
	ssh  -o ServerAliveInterval=30 \
	 -o ServerAliveCountMax=720 \
	 -o StrictHostKeyChecking=no \
	 -o UserKnownHostsFile=/dev/null root@$IP \
	 './lkvm run -k /boot/vmlinux-refinfra -c 8 --irqchip gicv3 -p "console=ttyAMA0,115200 earlycon=uart,mmio,0x3f8 debug"' 2>&1 | tee $RESULT_OUTPUT_FOLDER/$GUEST_OS0_BOOT_LOG
	RET=$?
	return $RET
}

##
# get kvm results
#
# collects the UART ARMTF and ssh log files, copies to $RESULT_OUTPUT_FOLDER
# and checks if the KVM result passed/failed from the ssh log file.
##
get_kvm_results () {
	RETUART0=0

	echo -e "\n[Result] KVM Host OS log file at $RESULT_OUTPUT_FOLDER/$HOST_OS_LOG_FILE\n"
	cp $PWD/$platform/$UART0_ARMTF_OUTPUT_FILE_NAME $RESULT_OUTPUT_FOLDER/$HOST_OS_LOG_FILE
	grep -q -s "# KVM session ended normally." $RESULT_OUTPUT_FOLDER/$GUEST_OS0_BOOT_LOG
	RETUART0=$?
	echo -e "\n[Result] KVM Guest OS log file at $RESULT_OUTPUT_FOLDER/$GUEST_OS0_BOOT_LOG\n"
	if [[ $RETUART0 != 0 ]]; then
	    echo -e "\n[Result] KVM test failed" | tee -a  $RESULT_OUTPUT_FOLDER/$GUEST_OS0_BOOT_LOG
	    return $RC_ERROR
	fi
	echo -e "\n[Result] KVM test passed" | tee -a $RESULT_OUTPUT_FOLDER/$GUEST_OS0_BOOT_LOG

	return 0
}

__print_examples()
{
	echo "Example 1: ./kvm.sh -p $1"
	echo "  Boot the distro image for KVM test."
        echo ""
	echo "Example 2: ./kvm.sh -p $1 -n true"
	echo "  Boot the distro image for KVM test with network enabled."
	echo ""
	echo "Example 3: ./kvm.sh -p $1 -j true -n true"
	echo "  Boot the distro image for KVM and automate the test."
	echo ""
	echo "Note: For automating the KVM test, it is a prerequisite to have"
	echo "      tap interface set in the host machine."

}

print_usage ()
{
	echo ""
	echo "Validate multiple guest OS boot"
	echo "Usage: ./kvm.sh -p <platform> [-n <true|false>] [-j <true|false>] [-a \"model params\"]"
	echo ""
	echo "Supported command line parameters:"
	echo "	-p   platform name (mandatory)"
	echo "	-n   Enable network: true or false (default: false)"
	echo "	-j   Automate kvm test: true or false (default: false)"
	echo "	-a   Additional model parameters, if any"
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
__parse_params_validate

platform_dir="platforms/$platform"
RESULT_OUTPUT_FOLDER="$RUNDIR/$platform_dir/$platform/kvm_test_results"

pushd $platform_dir

if [ ! -f $disk_name ]; then
	echo "[ERROR] Disk image $image_name not found under prebuilts directory"
	print_usage
	exit 1
fi

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

# Get the IP address of the model
get_ip_addr_fedora IP

# Execute kvm commands
echo -e "\n[INFO] KVM: Test started"
start_guest_os
if [ $? -ne 0 ]; then
	kill_model
	echo -e "\n[ERROR] Failed to start Guest OS"
	exit 1
fi

# send shutdown signal
send_shutdown $RESULT_OUTPUT_FOLDER/$GUEST_OS0_BOOT_LOG $IP

# get KVM log data
echo -e "\n[INFO] Collecting KVM log"
get_kvm_results
if [ $? -ne 0 ]; then
	kill_model
	exit 1
fi
echo -e "\n[INFO] Done collecting KVM logs"

parse_log_file "$PWD/$platform/$UART0_ARMTF_OUTPUT_FILE_NAME" "reboot: Power down" 240
if [ $? -ne 0 ]; then
	echo -e "\n[WARN]: System Shutdown failed or timed out!"
else
	echo -e "\n[INFO] System Shutdown completed!"
fi

kill_model
popd
exit 0
