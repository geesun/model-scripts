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

TEST_HARD_TIMEOUT=7200

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

# wait for boot to complete by parsing UART log
check_boot_complete ()
{
	local testdone=1
	local cnt=0

	while [  $testdone -ne 0 ]; do
		sleep 1
		if ls $1 1> /dev/null 2>&1; then
			tail $1 | grep -q -s -e "$2" > /dev/null 2>&1
			testdone=$?
			if [ "$cnt" -ge "$TEST_HARD_TIMEOUT" ];then
				echo -e "\n[ERROR] The model took longer than expected to boot, terminating the test..."
				return 1
			fi
			cnt=$((cnt+1))
		fi
	done
        echo -e "\n[INFO] Boot complete!"
	return 0
}
