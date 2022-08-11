#!/bin/bash

# Copyright (c) 2022, ARM Limited and Contributors. All rights reserved.
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

# set -x
SCRIPT=$(basename "$0")

ANDROID_HOST_BIN=""
TC_APK_INSTALLED_PATH=""

TC_DEVICE_PORT="127.0.0.1:5555"
TC_PRODUCT_NAME="tc_swr"
TC_MICRODROID_DEMO_PACKAGE_NAME="com.android.microdroid.tc"

tc_adb_error_exit() {
	echo "Run \`${SCRIPT}\` once Android services are completely up and running."
	echo "In Android, check \`getprop sys.boot_completed\` is 1"
	exit 1
}

tc_microdroid_prereq() {
    # ANDROID_PRODUCT_OUT set?
    if [ -z "$ANDROID_PRODUCT_OUT" ]; then
	echo "Environment var ANDROID_PRODUCT_OUT is empty"
	exit 1
    fi

    # find better way to get android/out/ from android/out/target/product/tc_swr
    ANDROID_OUT=`dirname ${ANDROID_PRODUCT_OUT}`
    ANDROID_OUT=`dirname ${ANDROID_OUT}`
    ANDROID_OUT=`dirname ${ANDROID_OUT}`

    ANDROID_HOST_BIN="${ANDROID_OUT}/host/linux-x86/bin"
    # adb exists ?
    if [ ! -f ${ANDROID_HOST_BIN}/adb ]; then
	echo "adb doesn't exists in ${ANDROID_HOST_BIN}"
	exit 1
    fi

    return 0
}

# Connect to TC FVP adb's port. Once connected, check product.name
tc_adb_connect() {
    echo "INFO: ADB connecting to ${TC_DEVICE_PORT}"
    cmd_op=`${ANDROID_HOST_BIN}/adb connect ${TC_DEVICE_PORT}`
    if [ $? != 0 ] || [[ ${cmd_op} == *"Connection refused"* ]]; then
	echo -e "Error: adb connect failed.\n"
	tc_adb_error_exit
    fi
    echo "INFO: ADB connected to ${TC_DEVICE_PORT}"

    echo "INFO: Checking ro.product.name"
    cmd_op=`${ANDROID_HOST_BIN}/adb -s ${TC_DEVICE_PORT} shell \
	getprop ro.product.name`
    if [ $? != 0 ]; then
	echo "Error: Get product name failed"
	tc_adb_error_exit
    fi
    if [ ${cmd_op} != "${TC_PRODUCT_NAME}" ]; then
	echo "TC product name: ${cmd_op}, doesn't match ${TC_PRODUCT_NAME}"
	exit 1
    fi
    echo "INFO: ro.product.name matches ${TC_PRODUCT_NAME}"

    return 0
}

# Get TC_MICRODROID_DEMO_PACKAGE_NAME installed path
tc_get_microdroid_apk_path() {
    echo "INFO: Checking path of ${TC_MICRODROID_DEMO_PACKAGE_NAME}"
    cmd_op=`${ANDROID_HOST_BIN}/adb -s ${TC_DEVICE_PORT} shell pm path \
           ${TC_MICRODROID_DEMO_PACKAGE_NAME}`
    if [ $? != 0 ]; then
	echo -e "Error: pm path on ${TC_MICRODROID_DEMO_PACKAGE_NAME} failed.\n"
	tc_adb_error_exit
    fi

    TC_APK_INSTALLED_PATH=${cmd_op##package:}
    echo "INFO: APK Installed path is: ${TC_APK_INSTALLED_PATH}"
    return 0
}

# Main
tc_microdroid_prereq
tc_adb_connect
tc_get_microdroid_apk_path

# Run TC Microdroid demo App
TEST_ROOT=/data/local/tmp
${ANDROID_HOST_BIN}/adb \
		   -s ${TC_DEVICE_PORT} \
		   shell /apex/com.android.virt/bin/vm run-app \
		   ${TC_APK_INSTALLED_PATH} \
		   ${TEST_ROOT}/TCMicrodroidDemoApp.apk.idsig \
		   ${TEST_ROOT}/instance.img \
		   assets/vm_config.json \
		   --log ${TEST_ROOT}/log.txt

exit $?
