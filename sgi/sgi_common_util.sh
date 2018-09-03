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
