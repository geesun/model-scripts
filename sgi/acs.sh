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
	echo "Execute SBSA and SBBR tests."
	echo "Usage: ./acs.sh -p <platform> [-n <true|false>] [-j <true|false>] [-a \"model params\"]"
	echo ""
	echo "Supported command line parameters:"
	echo "  -p   SGI platform name (mandatory)"
	echo "  -n   Enable network: true or false (default: false)"
	echo "  -j   Automate acs test: true or false (default: false)"
	echo "  -v   Absolute path of luv-live image (optional)"
	echo "  -a   Additional model parameters, if any"
	echo ""
	__print_supported_sgi_platforms
	echo "Example 1: ./acs.sh -p sgi575"
	echo "  Executes ACS tests for sgi575 platform. The luv live image is picked"
	echo "  from the location \"output/sgi575/luv-live-image-gpt.img\""
	echo
	echo "Example 2: ./acs.sh -p sgi575 -j true"
	echo "  Executes ACS tests for sgi575 platform and terminates the fvp model"
	echo "  automatically when the test ends. The luv live image is picked"
	echo "  from the location \"output/sgi575/luv-live-image-gpt.img\""
	echo ""
	echo "Example 3: ./acs.sh -p sgi575 -v ~/prebuilts/acs/luv-live-image-gpt.img"
	echo "  Executes ACS tests for sgi575 platform. The luv live image is picked"
	echo "  from the location \"~/prebuilts/acs/luv-live-image-gpt.img\""
	echo ""
}

# get_acs_test_results: Extracts the ACS test results from LUV-RESULTS partition
# of luvOS disc image using the offset to start and end sectors.
get_acs_test_results()
{
	local flag=false

	mkdir -p $outdir

	# Get the start and end sectors offset in LUV-RESULTS partition
	sector=($(gdisk -l $acs_image | awk '/^Number/{p=1;next}; p{gsub(/[^[:digit:]]/, "", $2); print $2; print $3}'))
	arr=( $( echo "${sector[@]}" | sed -e 's/ /\n/g' ) )

	# Copy the SBSA/SBBR results from the LUV-RESULTS partition
	dd if=$acs_image of=luvres skip=${arr[0]} count=${arr[1]} &> /dev/null
	mcopy -i luvres ::/Sbsa_results/uefi/SbsaResults.log $outdir/sgi-${MODEL_PID}-sbsaResults_uefi_${CURRENT_DATE_TIME}.log
	mcopy -i luvres ::/Sbsa_results/linux/SbsaResults.log $outdir/sgi-${MODEL_PID}-sbsaResults_linux_${CURRENT_DATE_TIME}.log
	mcopy -i luvres ::/results.md $outdir/sgi-${MODEL_PID}-acs_results_${CURRENT_DATE_TIME}.md

	# Check whether the results are extracted successfully or not
	if [ -f "$outdir/sgi-${MODEL_PID}-sbsaResults_uefi_${CURRENT_DATE_TIME}.log" ] && \
		[ -f "$outdir/sgi-${MODEL_PID}-sbsaResults_linux_${CURRENT_DATE_TIME}.log" ] && \
		[ -f "$outdir/sgi-${MODEL_PID}-acs_results_${CURRENT_DATE_TIME}.md" ]; then
		flag=true
		echo "Detailed SBSA/SBBR results:"
		echo "SBSA UEFI shell tests results are at $outdir/sgi-${MODEL_PID}-sbsaResults_uefi_${CURRENT_DATE_TIME}.log"
		echo "SBSA OS tests results are at $outdir/sgi-${MODEL_PID}-sbsaResults_linux_${CURRENT_DATE_TIME}.log"
		echo "LuvOS test results are at $outdir/sgi-${MODEL_PID}-acs_results_${CURRENT_DATE_TIME}.md"
	fi
	if [[ ! "$flag" = true ]]; then
		echo "SBSA/SBBR results files are not exist in LUV-RESULTS partitions"
	fi
}

# print_acs_test_summary: Parse and print the ACS test results summary from the build log
print_acs_test_summary()
{
	# Parse and print UEFI shell results
	echo "UEFI shell based SBSA test results..................."
	sed -n '/SBSA Architecture Compliance Suite/{:a;n;/SBSA tests complete/b;p;ba}' \
			$PWD/$platform/$UART0_ARMTF_OUTPUT_FILE_NAME

	# Parse and print ACS results
	echo "FWTS and ACS SBSA results..........................."
	sed -n '/Test results summary/{:a;n;/qemuarm64 login/b;p;ba}' \
			$PWD/$platform/$UART0_ARMTF_OUTPUT_FILE_NAME
}

while getopts "p:n:a:j:v:h" opt; do
	case $opt in
		p)
			platform=$OPTARG
			;;
		j)
			;;
		n|a)
			;;
		v)
			prebuilt="true"
			acs_image=$OPTARG
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

#Run the SBSA/SBBR tests
if [ "$prebuilt" != "true" ]; then
	acs_image="../../../../output/$platform/luv-live-image-gpt.img"
fi

platform_dir="platforms/$platform"

pushd $platform_dir

if [ ! -f $acs_image ]; then
	echo "LUV image luv-live-image-gpt.img not found at $acs_image"
	print_usage
	exit 1
fi

if [ "$prebuilt" != "true" ]; then
	set -- "$@" "-v" "$acs_image"
else
	set -- "$@"
fi
source ./run_model.sh

# if model failed to start, exit
if [ "$MODEL_PID" == "0" ] ; then
	exit 1
fi

# wait for the test to complete
parse_log_file "$PWD/$platform/$UART0_ARMTF_OUTPUT_FILE_NAME" "login:" 7200
ret=$?

# kill the model's children, then kill the model
kill_model
sleep 5

if [ "$ret" != "0" ]; then
	echo "[ERROR]: ACS test failed or timedout!"
	exit 1
else
	echo "[SUCCESS]: ACS test completed!"
fi

outdir=$PWD/$platform/acs

# Parse and print ACS test summary
print_acs_test_summary

# Get the ACS test results
get_acs_test_results

popd
exit 0
