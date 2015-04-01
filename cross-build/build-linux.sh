#!/bin/bash
#
# Cross-build a Linux kernel from source using an existing Raspberry Pi Linux
# installation /proc/config.gz file.
#
# Prerequisites:
# --------------
# Linux kernel
# source          : Raspberry Pi Linux kernel source from GitHub repository
#                   git://github.com/raspberrypi/linux.git. Note: branches for
#                   for various kernel versions are available.
# Cross-platform
# build tools     : Requires build tools installed to build a non-cross build
#                   Linux kernel plus a cross-compilation compiler which
#                   can be obtained from the Raspberry Pi tools GitHub
#                   repository https://github.com/raspberrypi/tools.git or
#                   can be built from source using a tools such as crosstool-NG
#                   (note: also requires Subversion), as described at
#                   http://elinux.org/RPi_Linaro_GCC_Compilation (although
#                   newer GCC versions can be used than stated in the article).
# KERNEL_SRC      : Exported environment variable. 
#                   Value is directory path to existing Linux kernel source.
# KERNEL_BUILD    : Exported environment variable. 
#                   Value is path to existing directory for build output. Output
#                   will be in a directory under ${KERNEL_BUILD} of the form:
#                     linux-version
#                   where version is the string returned by the kernel source:
#                     make kernelversion 
#                   command. Kernel build output will be placed in:
#                     linux-version/kernel
#                   Similarly, the modules staging directory will be placed in:
#                      linux-version/modules
# CCPREFIX        : Exported environment variable.
#                   Value is file or path prefix for the cross compilation build
#                   tools, e.g. if cross-compile gcc has path
#                     /path/to/cc/tools/arm-rpi-linux-gnueabihf-gcc
#                   then the value of CCPREFIX would be:
#                     /path/to/cc/tools/arm-rpi-linux-gnueabihf-
#                   if /path/to/cc/tools/ was not on the path or just:
#                     arm-rpi-linux-gnueabihf-
#                   if it were.
# ${KERNEL_SRC}/config.gz :
#                   Copy of a compressed Raspberry Pi Linux kernel configuration
#                   file, /proc/config.gz. Note: Requires zcat to expand.
#echo $KERNEL_SRC
#echo $CCPREFIX
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
  echo -e "Expected KERNEL_BUILD to be set to a valid path for build output."
  echo -e ${TxtNorm}
  exit 11
fi
if [[ -z "${CCPREFIX}" ]]
then
  echo -e "${TxtErr}CCPREFIX not set."
  echo -e "Expected CCPREFIX to be set to file/path name prefix for cross-compiler GCC and related tools."
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
if [[ ! -d ${KERNEL_BUILD} ]]
then
  echo -e "${TxtErr}${KERNEL_BUILD} does not seem to exist as a directory."
  echo -e ${TxtNorm}
  exit 12
fi
if !(${CCPREFIX}gcc --version > /dev/null)
then
  echo -e "${TxtErr}Unable to execute ${CCPREFIX}gcc."
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
if [[ ! -d ${build_dir_base} ]]
then
  if !(mkdir ${build_dir_base})
  then
    echo -e "${TxtErr}Failed to create build output directory ${build_dir_base}."
    echo -e ${TxtNorm}
    exit 13
  fi
  if  [[ ! -d ${build_dir} ]]
  then
    if !(mkdir ${build_dir})
    then
      echo -e "${TxtErr}Failed to create kernel build output directory ${build_dir}."
      echo -e ${TxtNorm}
      exit 13
    fi
  fi
  if  [[ ! -d ${modules_dir} ]]
  then
    if !(mkdir ${modules_dir})
    then
      echo -e "${TxtErr}Failed to create modules staging directory ${modules_dir}."
      echo -e ${TxtNorm}
      exit 13
    fi
  fi
fi
echo -e "${TxtIntro}Building Linux kernel version ${kernel_version}"
echo -e "    From source in:" `pwd`
echo -e "To build output in: ${build_dir}"
echo -e " Modules staged in: ${modules_dir}"
echo -e ${TxtNorm}

# Make steps start here:
output_opt=O=${build_dir}
common_opts="${output_opt} ARCH=arm CROSS_COMPILE=${CCPREFIX}"
#echo -e ${output_opt} 
#echo -e ${common_opts} 

# 1/ clean build directory - will remove .config
echo -e "${TxtInfo}Cleaning build directory..."
echo -e ${TxtNorm}
if !(make ${output_opt} mrproper)
then
  echo -e "${TxtErr}Failed cleaning build directory with make ... mrproper"
  echo -e ${TxtNorm}
  exit 14
fi

# 2/ Expand into build .config file in the build directory the compressed
# config.gz file copied to the kernel source directory from a Raspberry Pi
# /proc/config.gz file.
echo
echo -e "${TxtInfo}Expanding Raspberry Pi compressed configuration file" `pwd`"/config.gz"
echo -e "into ${build_dir}/.config ..."
echo -e ${TxtNorm}
if !(zcat config.gz > ${build_dir}/.config)
then
  echo -e "${TxtErr}Failed using zcat to expand ${KERNEL_SRC}/config.gz to ${build_dir}/.config"
  echo -e ${TxtNorm}
  exit 14
fi

# 3/ Set configuration to use existing (just created) .config:
echo
echo -e "${TxtInfo}Configuring build with 'old' ${build_dir}/.config ."
echo -e "You may be queried about new configuration options..."
echo -e ${TxtNorm}
if !(make ${common_opts} oldconfig)
then
  echo -e "${TxtErr}Failed setting build configuration  make ...  oldconfig"
  echo -e ${TxtNorm}
  exit 14
fi

# 4/ Build the kernel:
echo
echo -e "${TxtInfo}Building kernel..."
echo -e ${TxtNorm}
if !(make ${common_opts} -j5)
then
  echo -e "${TxtErr}Failed building kernel make ..."
  echo -e ${TxtNorm}
  exit 14
fi

# 5/ Build the modules:
echo
echo -e "${TxtInfo}Building modules..."
echo -e ${TxtNorm}
if !(make ${common_opts} modules)
then
  echo -e "${TxtErr}Failed building make ... modules"
  echo -e ${TxtNorm}
  exit 14
fi

# 6/ Install the modules to the module staging directory:
echo
echo -e "${TxtInfo}Installing modules to ${modules_dir}..."
echo -e ${TxtNorm}
if !(make ${common_opts} INSTALL_MOD_PATH=${modules_dir} modules_install)
then
  echo -e "${TxtErr}Failed building make ... modules_install"
  echo -e ${TxtNorm}
  exit 14
fi
