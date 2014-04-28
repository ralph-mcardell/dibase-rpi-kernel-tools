#!/bin/bash
#
# Transfer cross-built Linux kernel, modules and firmware to a Raspberry Pi
# using rsync with ssh.
#
# Prerequisites:
# --------------
# Built kernel  : See build-linux.sh
# Firmware files: Firmware files from Raspberry Pi Firmware Github repository
#                 git://github.com/raspberrypi/firmware.git whose version
#                 matches that of the kernel source.
# rsync         : Remote file copying tool
# ssh           : Used by rsync for remote communication
# KERNEL_SRC    : Exported environment variable. 
#                 Value is directory path to existing Linux kernel source.
#                 (for make kernelversion only).
# KERNEL_BUILD  : Exported environment variable. 
#                 Value is path to existing directory for built output. Output
#                 should be in a directory under ${KERNEL_BUILD} of the form:
#                   linux-version
#                 where version is the string returned by the kernel source:
#                   make kernelversion 
#                 command. Kernel build output is expected to be placed in:
#                   linux-version/kernel
#                 Similarly, the modules staging directory is expected be in:
#                    linux-version/modules
# FIRMWARE_DIR  : Exported environment variable.
#                 Path to the Raspberry Pi firmware files.
# STAGING_DIR   : Exported environment variable.
#                 Existing directory into which files to be transferred 
#                 are copied in the required directory structure before
#                 transfer.
# TGT_USER      : Exported environment variable.
#                 Target Raspberry Pi user to use for transfer.
# TGT_RPI       : Exported environment variable.
#                 Target Raspberry Pi host name or IP address to transfer to.
# TGT_DIR       : Exported environment variable.
#                 Absolute directory to use as root of transferred files.
#                 Files will be placed under ${TGT_DIR} in a directory of the
#                 form:
#                   version
#                 where version is the string returned by the kernel source:
#                   make kernelversion 
#                 command. The various kernel, module and firmware files will
#                 be transferred to sub-directories:
#                   boot    for boot partition files to be placed under /boot
#                   lib     for module files to be placed in /lib
#                   opt/vc  for the /opt/vc 'firmware' files.
BRed='\e[1;31m'
Grn='\e[0;32m'
Yel='\e[0;33m'
BYel='\e[1;33m'
Wht='\e[0;37m'
TxtNorm=${Wht}
TxtErr=${BRed}
TxtIntro=${BYel}
TxtInfo=${Grn}
TxtApp=${Yel}

# Check required exported environment variables are set:
if [[ -z "${KERNEL_SRC}" ]]
then
	echo -e "${TxtErr}KERNEL_SRC not set."
  echo -e "Expected KERNEL_SRC to be set to path to Linux kernel source."
  echo -e ${TxtNorm}
	exit 11
fi
if [[ -z "${KERNEL_BUILD}" ]]
then
	echo -e "${TxtErr}KERNEL_BUILD not set."
  echo -e "Expected KERNEL_BUILD to be set to a valid path for kernel build output."
  echo -e ${TxtNorm}
	exit 11
fi
if [[ -z "${FIRMWARE_DIR}" ]]
then
	echo -e "${TxtErr}FIRMWARE_DIR not set."
  echo -e "Expected FIRMWARE_DIR to be set to a valid path for Raspberry Pi firmware files."
  echo -e ${TxtNorm}
	exit 11
fi
if [[ -z "${STAGING_DIR}" ]]
then
	echo -e "${TxtErr}STAGING_DIR not set."
  echo -e "Expected STAGING_DIR to be set to a valid path."
  echo -e ${TxtNorm}
	exit 11
fi
if [[ -z "${TGT_RPI}" ]]
then
	echo -e "${TxtErr}TGT_RPI not set."
  echo -e "Expected TGT_RPI to be set to host name or IP address of Raspberry Pi to transfer files to."
  echo -e ${TxtNorm}
	exit 11
fi
if [[ -z "${TGT_USER}" ]]
then
	echo -e "${TxtErr}TGT_USER not set."
  echo -e "Expected TGT_USER to be set to user name on target Raspberry Pi to use for transfer."
  echo -e ${TxtNorm}
	exit 11
fi
if [[ -z "${TGT_DIR}" ]]
then
	echo -e "${TxtErr}TGT_DIR not set."
  echo -e "Expected TGT_DIR to be set to absolute directory on target Raspberry Pi to transfer files to."
  echo -e ${TxtNorm}
	exit 11
fi

# Check required exported environment variables have sane looking values:
if [[ ! -d ${KERNEL_SRC}/kernel ]]
then
	echo -e "${TxtErr}${KERNEL_SRC} does not seem to contain Linux kernel source."
  echo -e ${TxtNorm}
	exit 12
fi
if [[ ! -d ${STAGING_DIR} ]]
then
	echo -e "${TxtErr}${STAGING_DIR} does not exist."
  echo -e ${TxtNorm}
	exit 12
fi
if [[ ! -d ${FIRMWARE_DIR}boot ]]
then
	echo -e "${TxtErr}${FIRMWARE_DIR} does not seem to contain Raspberry Pi firmware files."
  echo -e ${TxtNorm}
	exit 12
fi
if [[ ! -f ${FIRMWARE_DIR}boot/bootcode.bin ]]
then
	echo -e "${TxtErr}${FIRMWARE_DIR}boot/bootcode.bin is missing."
  echo -e ${TxtNorm}
	exit 12
fi
if [[ ! -f ${FIRMWARE_DIR}boot/fixup.dat ]]
then
	echo -e "${TxtErr}${FIRMWARE_DIR}boot/fixup.dat is missing."
  echo -e ${TxtNorm}
	exit 12
fi
if [[ ! -f ${FIRMWARE_DIR}boot/start.elf ]]
then
	echo -e "${TxtErr}${FIRMWARE_DIR}boot/start.elf is missing."
  echo -e ${TxtNorm}
	exit 12
fi
if [[ ! -d ${FIRMWARE_DIR}opt/vc ]]
then
	echo -e "${TxtErr}${FIRMWARE_DIR}opt/vc (Raspberry Pi VideoCore files) missing ."
  echo -e ${TxtNorm}
	exit 12
fi

# Change to source directory, determine kernel version that will be build,  
# set build output directory based on version value and create if necessary:
cd ${KERNEL_SRC}

kernel_version=`make kernelversion`
build_dir_base=${KERNEL_BUILD}linux-${kernel_version}
build_dir=${build_dir_base}/kernel
modules_dir=${build_dir_base}/modules
image_file=${build_dir}/arch/arm/boot/zImage
if [[ ! -d ${build_dir_base} ]]
then
  	echo -e "${TxtErr}${build_dir_base} does not seem to exist as a directory."
  echo -e ${TxtNorm}
	exit 12
fi
if  [[ ! -x ${image_file} ]]
then
  echo -e "${TxtErr}Compressed image file ${image_file} is missing."
  echo -e ${TxtNorm}
  exit 12
fi
if  [[ ! -d ${modules_dir}/lib ]]
then
  echo -e "${TxtErr}Module lib directory ${modules_dir}/lib is missing."
  echo -e ${TxtNorm}
  exit 12
fi

# Build local transfer staging directory structure, if necessary
stage_base_dir=${STAGING_DIR}${kernel_version}
stage_boot_dir=${stage_base_dir}/boot
stage_lib_dir=${stage_base_dir}/lib
stage_opt_dir=${stage_base_dir}/opt
if [[ ! -d ${stage_base_dir} ]]
then
	if !(mkdir ${stage_base_dir})
	then
		echo -e "${TxtErr}Failed to create transfer staging base directory ${stage_base_dir}."
    echo -e ${TxtNorm}
		exit 13
	fi
  if  [[ ! -d ${stage_boot_dir} ]]
  then
    if !(mkdir ${stage_boot_dir})
    then
      echo -e "${TxtErr}Failed to create transfer boot files staging directory ${stage_boot_dir}."
      echo -e ${TxtNorm}
      exit 13
    fi
  fi
  if  [[ ! -d ${stage_lib_dir} ]]
  then
    if !(mkdir ${stage_lib_dir})
    then
      echo -e "${TxtErr}Failed to create transfer lib files staging directory ${stage_lib_dir}."
      echo -e ${TxtNorm}
      exit 13
    fi
  fi
  if  [[ ! -d ${stage_opt_dir} ]]
  then
    if !(mkdir ${stage_opt_dir})
    then
      echo -e "${TxtErr}Failed to create transfer opt files staging directory ${stage_opt_dir}."
      echo -e ${TxtNorm}
      exit 13
    fi
  fi
fi

target_base_dir=${TGT_DIR}${kernel_version}
target_boot_dir=${target_base_dir}/boot
target_lib_dir=${target_base_dir}/lib
target_opt_dir=${target_base_dir}/opt
echo -e "${TxtIntro}Transferring Raspberry Pi boot & Linux kernel version ${kernel_version} files."
echo -e "       From: build output in: ${build_dir}"
echo -e "                  modules in: ${modules_dir}"
echo -e "                 firmware in: ${FIRMWARE_DIR}"
echo -e " Staged via:"
echo -e "              /boot files in: ${stage_boot_dir}"
echo -e "               /lib files in: ${stage_lib_dir}"
echo -e "               /opt files in: ${stage_opt_dir}"
echo -e " Transfer To:                 ${TGT_USER}@${TGT_RPI}:"
echo -e "              /boot files in: ${target_boot_dir}"
echo -e "               /lib files in: ${target_lib_dir}"
echo -e "               /opt files in: ${target_opt_dir}"
echo -e ${TxtNorm}

# Use rsync to update files in transfer staging sub-tree
rsync -re ssh ${image_file} ${stage_boot_dir}
rsync -re ssh ${FIRMWARE_DIR}boot/bootcode.bin ${stage_boot_dir}
rsync -re ssh ${FIRMWARE_DIR}boot/fixup.dat ${stage_boot_dir}
rsync -re ssh ${FIRMWARE_DIR}boot/start.elf ${stage_boot_dir}

rsync -rqe ssh ${modules_dir}/lib ${stage_base_dir}

rsync -re ssh ${FIRMWARE_DIR}/opt ${stage_base_dir}

# Transfer staging files to Raspberry Pi receiving directory
rsync --stats -rze ssh ${stage_base_dir} ${TGT_USER}@${TGT_RPI}:${TGT_DIR}
