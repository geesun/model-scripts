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

# List of all the supported platforms.
declare -A platforms_sgi
platforms_sgi[sgi575]=1
declare -A platforms_rdinfra
platforms_rdinfra[rdn1edge]=1
platforms_rdinfra[rde1edge]=1
platforms_rdinfra[rdv1]=1
platforms_rdinfra[rdv1mc]=1
platforms_rdinfra[rdn2]=1
platforms_rdinfra[rdn2cfg1]=1
platforms_rdinfra[rdn2cfg2]=1

__print_examples()
{
	echo "Example 1: ./sct.sh -p $1"
	echo "  Executes UEFI SCT tests for $1 platform."
	echo
	echo "Example 2: ./sct.sh -p $1 -j true"
	echo "  Executes UEFI SCT tests for $1 platform and terminates the fvp model"
	echo "  automatically when the test ends."
}

print_usage ()
{
	echo ""
	echo "Execute UEFI SCT tests"
	echo "Usage: ./sct.sh -p <platform> [-n <true|false>] [-j <true|false>] [-a \"model params\"]"
	echo "  -p   Platform name (mandatory)"
	echo "  -n   Enable network: true or false (default: false)"
	echo "  -j   Automate sct test: true or false (default: false)"
	echo "  -a   Additional model parameters, if any"
	echo ""
	__print_supported_platforms_$refinfra
	__print_examples_$refinfra
	echo ""
}

# get_sct_test_results: Extracts the UEFI SCT test results from SCT partition
# of UEFI SCT disc image using the offset to start and end sectors.
get_sct_test_results()
{
	UEFI_SCT_RESULT_FILE=$outdir/sgi-UefiSct_Results_${CURRENT_DATE_TIME}.csv
	UEFI_SCT_SEQ_FILE=$outdir/sgi-UefiSct_Sequence_${CURRENT_DATE_TIME}.seq

	local flag=false

	mkdir -p $outdir

	# Get the start and end sectors offset in SCT partition
	sector=($(gdisk -l $sct_image | awk '/^Number/{p=1;next}; p{gsub(/[^[:digit:]]/, "", $2); print $2; print $3}'))
	arr=( $( echo "${sector[@]}" | sed -e 's/ /\n/g' ) )

	# Copy the test results from the SCT partition
	dd if=$sct_image of=sctres skip=${arr[0]} count=${arr[1]} &> /dev/null
	mcopy -i sctres ::SCT/Report/results.csv $UEFI_SCT_RESULT_FILE

	# Check whether the results are extracted successfully or not
	if [ -f "$UEFI_SCT_RESULT_FILE" ]; then
		flag=true
		echo "UEFI SCT test results are at $UEFI_SCT_RESULT_FILE"
	fi
	if [[ ! "$flag" = true ]]; then
		echo "UEFI SCT results files are not exist in SCT partition"
	fi

	flag=false
	# Get the sequence file from the SCT partition
	mcopy -i sctres ::SCT/Sequence/sct.seq $UEFI_SCT_SEQ_FILE
	if [ -f "$UEFI_SCT_SEQ_FILE" ]; then
		flag=true
		echo "UEFI SCT sequence file is at $UEFI_SCT_SEQ_FILE"
	fi
	if [[ ! "$flag" = true ]]; then
		echo "UEFI SCT sequence file is not exist in SCT partition"
	fi
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

#Run the UEFI SCT tests
sct_image="../../../../output/$platform/uefisct/uefi-sct.img"
platform_dir="platforms/$platform"

pushd $platform_dir

if [ ! -f $sct_image ]; then
	echo "UEFI-SCT image uefi-sct.img not found at $sct_image"
	print_usage
	exit 1
fi

set -- "$@" "-v" "$sct_image"
source ./run_model.sh

# if model failed to start, exit
if [ "$MODEL_PID" == "0" ] ; then
	exit 1
fi

# wait for the test to complete
parse_log_file "$PWD/$platform/$UART0_ARMTF_OUTPUT_FILE_NAME" "UEFI-SCT Done!" 7200
ret=$?

# kill the model's children, then kill the model
kill_model
sleep 2

if [ "$ret" != "0" ]; then
	echo "[ERROR]: SCT test failed or timedout!"
	exit 1
else
	echo "[SUCCESS]: SCT test completed!"
fi

outdir="$PWD/$platform/uefisct"

# Get the UEFI SCT test results
get_sct_test_results

popd
exit 0
