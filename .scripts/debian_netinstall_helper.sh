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
#if [ -z `which git` ]; then NEEDEDPACKAGES+="git-core "; fi
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
	
	#echo "Clean up ..."
	#rm -Rf "${TEMPDIR}"
	
	if [ "$1" != "0" ]; then
		echo "ERROR ..."
		exit $1
	else
		#echo " -> Done ..."
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

trap "{ clean_up; exit 255; }" SIGHUP SIGINT SIGTERM SIGQUIT
touch ${LOCKFILE}

################################################################################
# settings Env

MIRROR=${MIRROR-"ch"}
SUITE=${SUITE-"jessie"}
ARCH=${ARCH-"i386"}
INTERFACE=${INTERFACE-""}

################################################################################
# Download-URL

MIRROR_URL="http://ftp.${MIRROR}.debian.org/debian"
SUITE_URL="dists/${SUITE}/main"
ARCH_URL="installer-${ARCH}/current/images/netboot"
[ -n "${INTERFACE}" ] && ARCH_URL+="/${INTERFACE}"

URL="${MIRROR_URL}/${SUITE_URL}/${ARCH_URL}"

################################################################################
# download NetBoot-Image

wget -O /tmp/${SUITE}_${ARCH}_netboot.tar.gz ${URL}/netboot.tar.gz

################################################################################
# checksum NetBoot-Image

DIR=${INTERFACE}
[ -z "${DIR}" ] && DIR="netboot"
SHASUM=$(wget -q -O - "${MIRROR_URL}/${SUITE_URL}/installer-${ARCH}/current/images/MD5SUMS" | grep "${DIR}/netboot.tar.gz" | head -n 1 | awk -F" " '{print $1}')
if [ "${SHASUM}" != "$(md5sum /tmp/${SUITE}_${ARCH}_netboot.tar.gz | awk -F" " '{print $1}')" ]; then
	echo "!!! Checksum mismatch !!!"
	rm -f /tmp/${SUITE}_${ARCH}_netboot.tar.gz
	clean_up 1
fi

################################################################################
# extract NetBoot-Image

mkdir -p /tmp/${SUITE}_${ARCH}_netboot
tar -xvzf /tmp/${SUITE}_${ARCH}_netboot.tar.gz -C /tmp/${SUITE}_${ARCH}_netboot

################################################################################
# working directories

SOURCE_DIR="/tmp/${SUITE}_${ARCH}_netboot/debian-installer/${ARCH}"
DEST_DIR="debian/${SUITE}/netinst/${ARCH}"
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

################################################################################
# get config

if [ -f "${SOURCE_DIR}/boot-screens/txt.cfg" ]; then

	LABEL="Debian ${SUITE} ${ARCH} NetInstall"
	[ -n "${INTERFACE}" ] && LABEL+=" ${INTERFACE}"
	KERNEL="${DEST_DIR}/${LINUX}"
	APPEND=$(cat ${SOURCE_DIR}/boot-screens/txt.cfg | grep append | sed 's/^.*append //' | sed "s|debian-installer/${ARCH}/initrd.gz|${DEST_DIR}/initrd.gz|")

else

	LABEL="Debian ${SUITE} ${ARCH} NetInstall"
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

#rm -Rf /tmp/${SUITE}_${ARCH}_netboot.tar.gz /tmp/${SUITE}_${ARCH}_netboot config.sh

clean_up 0

################################################################################
