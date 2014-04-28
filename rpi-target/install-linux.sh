#!/bin/bash
#
# Install Linux kernel, modules and firmware on a running Raspberry Pi to the
# correct file system locations, backing up the existing files.
#
# Prerequisites:
# --------------
# Files to install: Located in a directory below current directory or defined
#                   by the SRC_DIR (exported) environment variable, having the
#                   the value of the Linux kernel version, currently of the
#                   form M.N.P when M is the major kernel release number, (e.g.
#                   3) N is the minor revision number (e.g. 10) and P the patch
#                   (release) number (e.g. 28). Each such version sub-directory
#                   should contain directories:
#                     boot    for boot partition files to be placed under /boot
#                     lib     for module & firmware files to be placed in /lib
#                     opt/vc  for the /opt/vc 'firmware' files.
#
# SRC_DIR         : (optional) Exported environment variable.
#                   Absolute directory to use as the root of kernel/module/
#                   firmware file sets to install.
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

# Append path suffix to a path prefix
# $1 name of variable to return combined path string e.g. the_path
# $2 path prefix , e.g. /a/b/c 
# $3 path suffix e.g. a-file or a-dir/a-file 
# 
# Call example:
#   the_path=''
#   path_append the_path 'a/b/c' 'a-dir/a-file'
#   echo ${the_path}
# Prints:
#  a/b/c/a-dir/a-file
path_append ()
{
  path_prefix=$2
  path_suffix=$3
  last_char_idx=$(( ${#path_prefix} - 1 ))
  if [[ "${path_prefix:$last_char_idx:1}" != "/" ]]
    then
      path_prefix=${path_prefix}"/"
    fi
  eval "$1='${path_prefix}${path_suffix}'"
}

# Make a directory
# $1 Directory to make
make_dir ()
{
  echo -e "${TxtApp}Creating directory: $1"
  if !(mkdir "$1")
  then
    echo -e "${TxtErr}Failed to create directory $1."
    echo -e "Did you forget sudo?"
    echo -e ${TxtNorm}
    exit 13
  fi
}

# Copy a single file/directory specification with no special options
# $1 copy from path
# #2 copy to path
copy_file ()
{
  echo -e "${TxtApp}Copying: $1 to: $2"
  if !(cp "$1" "$2")
  then
    echo -e "${TxtErr}Failed to copy $1 to $2."
    echo -e ${TxtNorm}
    exit 13
  fi
}

# Copy a directory sub-tree
# $1 copy from path
# #2 copy to path
# Both paths must exist. Copies all contents of $1 recursively into $2
copy_dir_subtree ()
{
  echo -e "${TxtApp}Copying: $1/* into: $2"
  if !(cp  --recursive "$1/"* "$2")
  then
    echo -e "${TxtErr}Failed copying $1/* into $2."
    echo -e ${TxtNorm}
    exit 13
  fi
}

# Rename a single file or directory no special options
# $1 File or directory to rename path
# #2 New name path
rename ()
{
  echo -e "${TxtApp}Renaming: $1 to: $2"
  if !(mv "$1" "$2")
  then
    echo -e "${TxtErr}Failed to rename $1 to $2."
    echo -e ${TxtNorm}
    exit 13
  fi
}

#-------------------------------------------------------------------------------
# Main script:
source_base_dir=${SRC_DIR}
if [[ -z "${source_base_dir}" ]]
then
	source_base_dir=`pwd`
fi

if [[ -z "$1" ]]
then
	echo -e "${TxtErr}Source sub-directory not given."
  echo -e
  echo -e "Usage:"
  echo -e "   install-linux src-sub-dir"
  echo -e
  echo -e "where:"
  echo -e "   src-sub-dir is the sub-directory of ${source_base_dir} from"
  echo -e "               which the kernel, module and firmware files"
  echo -e "               to be installed are located."
  echo -e ${TxtNorm}
	exit 11
fi

source_dir=''
path_append source_dir "${source_base_dir}" "$1"

if [[ ! -d ${source_dir} ]]
then
	echo -e "${TxtErr}File installation directory ${source_dir} does not exist."
  echo -e ${TxtNorm}
	exit 12
fi

boot_dir=''
path_append boot_dir "${source_dir}" "boot"
lib_dir=''
path_append lib_dir "${source_dir}" "lib"
opt_dir=''
path_append opt_dir "${source_dir}" "opt"
#echo "boot_dir=${boot_dir}"
#echo " lib_dir=${lib_dir}"
#echo " opt_dir=${opt_dir}"
# Check expected 1st and 2nd level subdirectories and all boot partition files
# exist:
if [[ ! -d ${boot_dir} ]]
then
	echo -e "${TxtErr}${source_dir} does not have a boot subdirectory."
  echo -e ${TxtNorm}
	exit 12
fi
if  [[ ! -d ${lib_dir} ]]
then
  echo -e "${TxtErr}${source_dir} does not have a lib subdirectory."
  echo -e ${TxtNorm}
  exit 12
fi
if [[ ! -d ${opt_dir} ]]
then
	echo -e "${TxtErr}${source_dir} does not have an opt subdirectory."
  echo -e ${TxtNorm}
	exit 12
fi

if [[ ! -f ${boot_dir}/bootcode.bin ]]
then
	echo -e "${TxtErr}${boot_dir}/bootcode.bin is missing."
  echo -e ${TxtNorm}
	exit 12
fi
if [[ ! -f ${boot_dir}/fixup.dat ]]
then
	echo -e "${TxtErr}${boot_dir}/fixup.dat is missing."
  echo -e ${TxtNorm}
	exit 12
fi
if [[ ! -f ${boot_dir}/start.elf ]]
then
	echo -e "${TxtErr}${boot_dir}/start.elf is missing."
  echo -e ${TxtNorm}
	exit 12
fi
if  [[ ! -x ${boot_dir}/zImage ]]
then
  echo -e "${TxtErr}Compressed image file ${boot_dir}/zImage is missing or not executable."
  echo -e ${TxtNorm}
  exit 12
fi
if  [[ ! -d ${lib_dir}/firmware ]]
then
  echo -e "${TxtErr}${lib_dir}/firmware directory is missing."
  echo -e ${TxtNorm}
  exit 12
fi
if  [[ ! -d ${lib_dir}/modules ]]
then
  echo -e "${TxtErr}${lib_dir}/modules directory is missing."
  echo -e ${TxtNorm}
  exit 12
fi
if [[ ! -d ${opt_dir}/vc ]]
then
	echo -e "${TxtErr}${opt_dir}/vc (Raspberry Pi VideoCore files) directory is missing."
  echo -e ${TxtNorm}
	exit 12
fi

# backup existing boot files: 
timestamp=`date +%Y%m%d%H%M%S`
#echo "timestamp=${timestamp}"
boot_backup_dir="/boot/backup-${timestamp}"
#echo "boot_backup_dir=${boot_backup_dir}"
if [[ -d "${boot_backup_dir}" ]]
then
  sleep 1
  timestamp=`date +%Y%m%d%H%M%S`
fi
make_dir "${boot_backup_dir}"
copy_file "/boot/bootcode.bin" "${boot_backup_dir}"
copy_file "/boot/fixup.dat" "${boot_backup_dir}"
copy_file "/boot/start.elf" "${boot_backup_dir}"
copy_file "/boot/kernel.img" "${boot_backup_dir}"

# Copy new firmware opt/vc VideoCore support files into temporary place
vc_tmp_dir="/opt/vc-${timestamp}.tmp"
vc_backup_dir="/opt/vc-${timestamp}"
make_dir "${vc_tmp_dir}"
copy_dir_subtree "${opt_dir}/vc" "${vc_tmp_dir}"

# Copy new lib/firmware into temporary place
firmware_tmp_dir="/lib/firmware-${timestamp}.tmp"
firmware_backup_dir="/lib/firmware-${timestamp}"
make_dir "${firmware_tmp_dir}"
copy_dir_subtree "${lib_dir}/firmware" "${firmware_tmp_dir}"

# Copy new lib/modules into temporary place
modules_tmp_dir="/lib/modules-${timestamp}.tmp"
modules_backup_dir="/lib/modules-${timestamp}"
make_dir "${modules_tmp_dir}"
copy_dir_subtree "${lib_dir}/modules" "${modules_tmp_dir}"

# Copy new boot files into place
copy_file "${boot_dir}/bootcode.bin" "/boot/bootcode.bin"
copy_file "${boot_dir}/fixup.dat" "/boot/fixup.dat"
copy_file "${boot_dir}/start.elf" "/boot/start.elf"
copy_file "${boot_dir}/zImage" "/boot/kernel.img"

# backup /opt/vc and move new vc into place:
rename "/opt/vc" "${vc_backup_dir}"
rename "${vc_tmp_dir}" "/opt/vc"

# backup /lib/firmware and move new firmware into place:
rename "/lib/firmware" "${firmware_backup_dir}"
rename "${firmware_tmp_dir}" "/lib/firmware"

# backup /lib/modules and move new modules into place:
rename "/lib/modules" "${modules_backup_dir}"
rename "${modules_tmp_dir}" "/lib/modules"

echo -e "${TxtApp}Done."
