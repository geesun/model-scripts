#!/usr/bin/env bash

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

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#
# This script is contains different utility method to run validation tests  #
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#

SGI_TEST_MAX_TIMEOUT=7200
CURRENT_DATE_TIME=`date +%Y-%m-%d_%H.%M.%S`
MYPID=$$

# UART Log files
UART0_ARMTF_OUTPUT_FILE_NAME=refinfra-${MYPID}-uart-0-armtf_$CURRENT_DATE_TIME
UART1_MM_OUTPUT_FILE_NAME=refinfra-${MYPID}-uart-1-mm_$CURRENT_DATE_TIME
UART0_CONSOLE_OUTPUT_FILE_NAME=refinfra-${MYPID}-uart-0-console_$CURRENT_DATE_TIME
UART0_SCP_OUTPUT_FILE_NAME=refinfra-${MYPID}-uart-0-scp_$CURRENT_DATE_TIME
UART0_MCP_OUTPUT_FILE_NAME=refinfra-${MYPID}-uart-0-mcp_$CURRENT_DATE_TIME

if [ -z "$refinfra" ] ; then
	refinfra="sgi"
fi

__print_supported_platforms_sgi()
{
	echo "Supported platforms are -"
	for plat in "${!platforms_sgi[@]}" ;
		do
			printf "\t $plat\n"
		done
	echo
}

__print_supported_platforms_rdinfra()
{
	echo "Supported platforms are -"
	for plat in "${!platforms_rdinfra[@]}" ;
		do
			printf "\t $plat\n"
		done
	echo
}

__print_examples_sgi()
{
	__print_examples "sgi575"
}

__print_examples_rdinfra()
{
	__print_examples "rdn1edge"
}

__parse_params_validate()
{
	#Ensure that the platform is supported
	if [ -z "$platform" ] ; then
		print_usage
		exit 1
	fi
	if [ -z "${platforms_sgi[$platform]}" -a \
             -z "${platforms_rdinfra[$platform]}" ]; then
		echo "[ERROR] Could not deduce which platform to execute on."
		__print_supported_platforms_$refinfra
		exit 1
	fi
}

# search all the available network interfaces and find an available tap
# network interface to use.
find_tap_interface()
{
    echo -e "\n[INFO] Finding available TAP interface..."
    if [[ -n "$TAP_NAME" ]]; then
        TAP_INTERFACE=$TAP_NAME
    else
        echo -e "\n[WARN] Environment variable TAP_NAME is not defined."
        echo -e "[INFO] If you want to use a particular interface then please export TAP_NAME with the interface name."
        echo -e "[INFO] Searching for available TAP device(s)..."
        ALL_INTERFACES=`ifconfig -a | sed 's/[ \t].*//;/^\(lo\|\)$/d'`
        while read -r line; do
            last_char="${line: -1}"
            #On machines with ubuntu 18.04+, the interface name ends with ":" character.
            #Strip this character from the network interface name.
            if [ "$last_char" == ":" ]; then
	            TAP_INTERFACE=${line::-1}
            else
	            TAP_INTERFACE=$line
            fi
            # The file tun_flags will only be available under tap interface directory.
            # Incase of multiple tap interfaces, only the first available tap interface will be used.
            if [ -f "/sys/class/net/$TAP_INTERFACE/tun_flags" ];then
                break;
            fi
        done <<< "$ALL_INTERFACES"
    fi
    if [[ -z "$TAP_INTERFACE" ]]; then
        echo -e "[WARN] No TAP interface found !!! Please create a new tap interface for network to work inside the model."
        return 1
    else
        echo -e "[INFO] Interface Found : $TAP_INTERFACE"
    fi
    return 0
}

# creates a nor flash image with the path and filename passed as parameter.
create_nor_flash_image () {
	if [ ! -f $1 ]; then
		echo -e "\n[INFO] Creating NOR Flash image"
		#create 64MB image of 256K block size
		dd if=/dev/zero of=$1 bs=256K count=256 > /dev/null 2>&1
		#Gzip it
		gzip $1 && mv $1.gz $1
	fi
}

# kill the model's children, then kill the model
kill_model () {
    if [[ -z "$MODEL_PID" ]]; then
        :
    else
        echo -e "\n[INFO] Killing all children of PID: $MODEL_PID"
        MODEL_CHILDREN=$(pgrep -P $MODEL_PID)
        for CHILD in $MODEL_CHILDREN
        do
            echo -e "\n[INFO] Killing $CHILD $(ps -e | grep $CHILD)"
            kill -9 $CHILD > /dev/null 2>&1
        done
        kill -9 $MODEL_PID > /dev/null 2>&1
        echo -e "\n[INFO] All model processes killed successfully."
    fi
}

# parse_log_file: waits until the search string is found in the log file
#				  or timeout occurs
# Arguments: 1. log file name
#            2. search string
#            3. timeout
# Return Value: 0 -> Success
#              -1 -> Failure
parse_log_file ()
{
	local testdone=1
	local cnt=0
	local logfile=$1
	local search_str=$2
	local timeout=$3

	if [ "$timeout" -le 0 ] || [ "$timeout" -gt $SGI_TEST_MAX_TIMEOUT ]; then
		echo -e "\n[WARN] timeout value $timeout is invalid. Setting" \
			"timeout to $SGI_TEST_MAX_TIMEOUT seconds."
		timeout=$SGI_TEST_MAX_TIMEOUT;
	fi

	while [  $testdone -ne 0 ]; do
		sleep 1
		if ls $logfile 1> /dev/null 2>&1; then
			tail $logfile | grep -q -s -e "$search_str" > /dev/null 2>&1
			testdone=$?
		fi
		if [ "$cnt" -ge "$timeout" ]; then
			echo -e "\n[ERROR]: ${FUNCNAME[0]}: Timedout or $logfile may not found!\n"
			return -1
		fi
		cnt=$((cnt+1))
	done
	return 0
}

##
# Get the IP address of the Fast Model running Fedora OS.
#
# In case if host dhcp server doesn't assign fixed IP address to the fast model,
# this function will be useful to extract the IP from the UART0_ARMTF Log
##
get_ip_addr_fedora () {
	local _IP=""
	console_op=$(grep -e 'Admin Console' $PWD/$platform/$UART0_ARMTF_OUTPUT_FILE_NAME)
	re="https://([^/]+):" # regular expression
	if [[ $console_op =~ $re ]]; then _IP=${BASH_REMATCH[1]}; fi
	echo -e "\n[INFO] IP address of the model: $_IP"
	eval "$1=$_IP"
	return 0
}

##
# send shutdown signal to the os
##
send_shutdown () {
	RET=1

	echo -e "\n[INFO] Sending Shutdown Signal ...\n"
	ssh  -o ServerAliveInterval=30 \
	 -o ServerAliveCountMax=720 \
	 -o StrictHostKeyChecking=no \
	 -o UserKnownHostsFile=/dev/null root@$2 \
	 'shutdown -h now' 2>&1 | tee -a $1
	RET=$?
	return $RET
}
