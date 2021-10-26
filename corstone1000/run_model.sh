#!/usr/bin/env bash
# This proprietary software may be used only as authorised by a licensing
# agreement from Arm Limited
# (C) COPYRIGHT 2021 Arm Limited
# The entire notice above must be reproduced on all authorised copies and
# copies may only be made to the extent permitted by a licensing agreement from
# ARM Limited.

# Set your ARMLMD_LICENSE_FILE License path for FVP licenses before running this script

# Get full absolute path to the directory of this file
pushd $(dirname "$0")
BASEDIR=$(pwd)
popd

help() {
    echo "usage: run_model.sh \${FVP executable path} [ -u ]"
    echo "  -u: Run unit test selector using pyIRIS"
    echo "   No additional argument: load and execute model"
    exit 1
}

# Ensure that an FVP path has been provided
if [ -z "$1" ]
then
    help
fi

cs700="Corstone-700"
cs1000="Corstone-1000"
a5ds="CA5DS"
YOCTO_DISTRO="poky-tiny"

if [[ $1 =~ $cs700 ]]; then

  YOCTO_IMAGE="corstone700-image"

  if [ -z "$MACHINE" ]; then
    MACHINE="corstone700-fvp"
  fi

  echo "Corstone700: using $MACHINE machine , $YOCTO_DISTRO DISTRO"

  OUTDIR=${BASEDIR}/../../build-${YOCTO_DISTRO}/tmp-$(echo ${YOCTO_DISTRO} | sed 's/-/_/g')/deploy/images/${MACHINE}
  DIRNAME=corstone700

elif [[ $1 =~ $cs1000 ]]; then

  YOCTO_IMAGE="corstone1000-image"

  if [ -z "$MACHINE" ]; then
    MACHINE="corstone1000-fvp"
  fi

  echo "Corstone1000: using $MACHINE machine , $YOCTO_DISTRO DISTRO"

  OUTDIR=${BASEDIR}/../../build/tmp/deploy/images/${MACHINE}
  DIRNAME=corstone1000

else
  OUTDIR=${BASEDIR}/../../build-${YOCTO_DISTRO}/tmp-$(echo ${YOCTO_DISTRO} | sed 's/-/_/g')/deploy/images/a5ds
  DIRNAME=a5ds
fi

if [ -z "$2" -o "$2" == "-S" ]
then
    if [[ $1 =~ $cs700 ]]; then
    echo "================== Launching Corstone700 Model ==============================="
    $1 \
        -C se.trustedBootROMloader.fname="${OUTDIR}/se_romfw.bin" \
        -C board.flashloader0.fname="${OUTDIR}/${YOCTO_IMAGE}-${MACHINE}.wic.nopt" \
        -C extsys_harness0.extsys_flashloader.fname="${OUTDIR}/es_flashfw.bin" \
        -C board.xnvm_size=64 \
        -C board.hostbridge.interfaceName="tap0" \
        -C board.smsc_91c111.enabled=1 \
        $2
    elif [[ $1 =~ $cs1000 ]]; then
    echo "================== Launching Corstone1000 Model ==============================="
    $1 \
	 -C se.trustedBootROMloader.fname="${OUTDIR}/bl1.bin" \
        --data board.flash0=${OUTDIR}/${YOCTO_IMAGE}-${MACHINE}.wic.nopt@0x68050000 \
        -C board.xnvm_size=64 \
        -C se.trustedSRAM_config=6 \
        -C se.BootROM_config="3" \
        -C board.hostbridge.interfaceName="tap0" \
        -C board.smsc_91c111.enabled=1 \
        -C board.hostbridge.userNetworking=1 \
        -C board.hostbridge.userNetPorts="5555=5555,8080=80,8022=22" \
        -C board.se_flash_size=8192 \
        -C diagnostics=4 \
	$2
    elif [[ $1 =~ $a5ds ]]; then
    echo "================== Launching CA5-DS Model ==============================="
    $1 \
      -C board.flashloader0.fname="${OUTDIR}/bl1.bin" \
      --data css.cluster.cpu0="${OUTDIR}/iota-tiny-image-a5ds.wic@0x80000000" \
      $2
    else
       help
    fi
elif [ "$2" == "-u" ]
then
    if [[ $1 =~ $cs1000 ]]; then
    echo "Corstone1000: run unit test selector not supported."
    else
    # The FVP model executable is used.
    python ${BASEDIR}/scripts/test/testselector.py \
       --${DIRNAME} "--image_dir ${OUTDIR} --fvp ${1}"
    fi
else
   help
fi
