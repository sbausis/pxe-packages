#!/bin/bash

set -e
set -x

export LANGUAGE=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

SCRIPTNAME=$(basename "$0")

################################################################################
## Need Packages

NEEDEDPACKAGES=""
if [ -z `which pax` ]; then NEEDEDPACKAGES+="pax "; fi
if [ -n "${NEEDEDPACKAGES}" ]; then
	echo "Need ${NEEDEDPACKAGES}, installing them..."
	apt-get -qq -y install ${NEEDEDPACKAGES}
fi

################################################################################
## Need TEMPDIR

TEMPDIR=$(mktemp -d -t ${SCRIPTNAME}.XXXXXXXXXX)
LOCKFILE=${TEMPDIR}/${SCRIPTNAME}.lock
[ -f "${LOCKFILE}" ] && echo "ERROR ${LOCKFILE} already exist. !!!" && exit 255

################################################################################
## Need CleanUp

function clean_up() {
	
	echo "Clean up ..."
	
	rm -Rf "${TEMPDIR}"
	rm -f "${LOCKFILE}"
	
	trap "" SIGHUP SIGINT SIGTERM SIGQUIT EXIT
	if [ "$1" != "0" ]; then
		echo "ERROR ..."
		exit $1
	else
		echo "DONE ..."
		exit 0
	fi
}

function print_help() {
	echo "
${SCRIPTNAME}  version 0.1b
Copyright (C) 2015 by Simon Baur (sbausis at gmx dot net)

Usage: [MIRROR='MIRROR'] [SUITE='SUITE'] [ARCH='ARCH'] [INTERFACE='INTERFACE'] ${SCRIPTNAME}
 example: MIRROR=nl SUITE=wheezy ARCH=amd64 INTERFACE=gtk ${SCRIPTNAME}

Environment Variables:
 MIRROR='MIRROR'             (default:ch)     set MIRROR to your Country-Code for Debian-Mirror
 SUITE='SUITE'               (default:jessie) set SUITE to download
 ARCH='ARCH'                 (default:i386)   set ARCH to download
 INTERFACE='INTERFACE'       (default:)       may be 'gtk' / 'xen'
"
}

function help_exit() {
	print_help
	clean_up 1
}

################################################################################
## Need LOCKFILE

trap "{ clean_up 255; }" SIGHUP SIGINT SIGTERM SIGQUIT EXIT
touch ${LOCKFILE}

################################################################################
# settings Env

#MIRROR=${MIRROR-"ch"}
SUITE=${SUITE-"vivid"}
ARCH=${ARCH-"i386"}
INTERFACE=${INTERFACE-""}

################################################################################
# Download-URL

MIRROR_URL="http://ftp.ubuntu.com/ubuntu"
SUITE_URL="dists/${SUITE}/main"
ARCH_URL="installer-${ARCH}/current/images/netboot"
[ -n "${INTERFACE}" ] && ARCH_URL+="/${INTERFACE}"

URL="${MIRROR_URL}/${SUITE_URL}/${ARCH_URL}"

################################################################################
# download NetBoot-Image

wget -O ${TEMPDIR}/${SUITE}_${ARCH}_netboot.tar.gz ${URL}/netboot.tar.gz

################################################################################
# checksum NetBoot-Image

DIR=${INTERFACE}
[ -z "${DIR}" ] && DIR="netboot"
SHASUM=$(wget -q -O - "${MIRROR_URL}/${SUITE_URL}/installer-${ARCH}/current/images/MD5SUMS" | grep "${DIR}/netboot.tar.gz" | head -n 1 | awk -F" " '{print $1}')
if [ "${SHASUM}" != "$(md5sum ${TEMPDIR}/${SUITE}_${ARCH}_netboot.tar.gz | awk -F" " '{print $1}')" ]; then
	echo "!!! Checksum mismatch !!!"
	rm -f ${TEMPDIR}/${SUITE}_${ARCH}_netboot.tar.gz
	clean_up 1
fi

################################################################################
# extract NetBoot-Image

mkdir -p ${TEMPDIR}/${SUITE}_${ARCH}_netboot
tar -xvzf ${TEMPDIR}/${SUITE}_${ARCH}_netboot.tar.gz -C ${TEMPDIR}/${SUITE}_${ARCH}_netboot

################################################################################
# working directories

SOURCE_DIR="${TEMPDIR}/${SUITE}_${ARCH}_netboot/ubuntu-installer/${ARCH}"
DEST_DIR="ubuntu/${SUITE}/netinst/${ARCH}"
[ -n "${INTERFACE}" ] && DEST_DIR+="/${INTERFACE}"

mkdir -p ${DEST_DIR}

################################################################################
# get kernel

if [ -f "${SOURCE_DIR}/vmlinuz" ]; then
	LINUX="vmlinuz"
	cp -f ${SOURCE_DIR}/vmlinuz ${DEST_DIR}/vmlinuz
fi

if [ -f "${SOURCE_DIR}/linux" ]; then
	LINUX="linux"
	cp -f ${SOURCE_DIR}/linux ${DEST_DIR}/linux
fi

[ -z "${LINUX}" ] && clean_up 1

################################################################################
#get ramdisk

cp -f ${SOURCE_DIR}/initrd.gz ${DEST_DIR}/initrd.gz

#set +e
#wget -O ${TEMPDIR}/firmware.cpio.gz http://cdimage.debian.org/cdimage/unofficial/non-free/firmware/${SUITE}/current/firmware.cpio.gz
#set -e
#
#if [ ! -f "${TEMPDIR}/firmware.cpio.gz" ]; then
#	
#	wget -O ${TEMPDIR}/firmware.tar.gz http://cdimage.debian.org/cdimage/unofficial/non-free/firmware/${SUITE}/current/firmware.tar.gz
#	mkdir -p ${TEMPDIR}/firmware
#	tar -C ${TEMPDIR}/firmware -zxf ${TEMPDIR}/firmware.tar.gz
#	(cd ${TEMPDIR} && pax -x sv4cpio -s'%firmware%/firmware%' -w firmware | gzip -c >${TEMPDIR}/firmware.cpio.gz)
#fi
#cat ${SOURCE_DIR}/initrd.gz ${TEMPDIR}/firmware.cpio.gz > ${DEST_DIR}/initrd.firmware.gz

################################################################################
# get config

if [ -f "${SOURCE_DIR}/boot-screens/txt.cfg" ]; then

	LABEL="Ubuntu ${SUITE} ${ARCH} NetInstall"
	[ -n "${INTERFACE}" ] && LABEL+=" ${INTERFACE}"
	KERNEL="${DEST_DIR}/${LINUX}"
	APPEND=$(cat ${SOURCE_DIR}/boot-screens/txt.cfg | grep append | sed 's/^.*append //' | sed "s|ubuntu-installer/${ARCH}/initrd.gz|${DEST_DIR}/initrd.gz|")

else

	LABEL="Ubuntu ${SUITE} ${ARCH} NetInstall"
	[ -n "${INTERFACE}" ] && LABEL+=" ${INTERFACE}"
	KERNEL="${DEST_DIR}/${LINUX}"
	APPEND="vga=normal initrd=${DEST_DIR}/initrd.gz --quiet"

fi

################################################################################
# generate config

CONFIG_FILE="./.${SUITE}_${ARCH}_netboot.config"
[ -n "${INTERFACE}" ] && CONFIG_FILE="./.${SUITE}_${ARCH}_${INTERFACE}_netboot.config"
cat <<EOF > ${CONFIG_FILE}
LABEL $LABEL
 KERNEL $KERNEL
 APPEND $APPEND
EOF
cp -f ${CONFIG_FILE} ./config.txt

################################################################################
# cleanUp

#rm -Rf ${TEMPDIR}/${SUITE}_${ARCH}_netboot.tar.gz ${TEMPDIR}/${SUITE}_${ARCH}_netboot config.sh

clean_up 0

################################################################################
