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

RELEASE=${RELEASE-"7.9.0"}
SUITE=${SUITE-"wheezy"}
ARCH=${ARCH-"amd64"}
INTERFACE=${INTERFACE-"standard"}

[ "$(echo "${RELEASE}" | awk -F"." '{print $1}')" == "7" ] && SUITE="wheezy"
[ "$(echo "${RELEASE}" | awk -F"." '{print $1}')" == "8" ] && SUITE="jessie"

################################################################################
# Download-URL

MIRROR_URL="http://cdimage.debian.org/cdimage/archive"
RELEASE_URL="${RELEASE}-live"
ARCH_URL="${ARCH}/webboot"
[ $(echo "${RELEASE}" | awk -F"." '{print $1}') -lt 7 ] && ARCH_URL="${ARCH}/web"

URL="${MIRROR_URL}/${RELEASE_URL}/${ARCH_URL}"
#http://cdimage.debian.org/cdimage/archive/8.0.1-live/i386/webboot/debian-live-8.0.1-i386-standard.vmlinuz
################################################################################
# download LiveBoot-Image

wget -O ${TEMPDIR}/debian-live-${RELEASE}-${ARCH}-${INTERFACE}.vmlinuz ${URL}/debian-live-${RELEASE}-${ARCH}-${INTERFACE}.vmlinuz

wget -O ${TEMPDIR}/debian-live-${RELEASE}-${ARCH}-${INTERFACE}.initrd.img ${URL}/debian-live-${RELEASE}-${ARCH}-${INTERFACE}.initrd.img

wget -O ${TEMPDIR}/debian-live-${RELEASE}-${ARCH}-${INTERFACE}.squashfs ${URL}/debian-live-${RELEASE}-${ARCH}-${INTERFACE}.squashfs

################################################################################
# checksum LiveBoot-Image

wget -q -O ${TEMPDIR}/MD5SUMS "${URL}/MD5SUMS"

MD5SUM_LINUX=$(cat ${TEMPDIR}/MD5SUMS | grep "debian-live-${RELEASE}-${ARCH}-${INTERFACE}.vmlinuz" | head -n 1 | awk -F" " '{print $1}')
MD5SUM_INITRD=$(cat ${TEMPDIR}/MD5SUMS | grep "debian-live-${RELEASE}-${ARCH}-${INTERFACE}.initrd.img" | head -n 1 | awk -F" " '{print $1}')
MD5SUM_SQUASHFS=$(cat ${TEMPDIR}/MD5SUMS | grep "debian-live-${RELEASE}-${ARCH}-${INTERFACE}.squashfs" | head -n 1 | awk -F" " '{print $1}')
if [ "${MD5SUM_LINUX}" != "$(md5sum ${TEMPDIR}/debian-live-${RELEASE}-${ARCH}-${INTERFACE}.vmlinuz | awk -F" " '{print $1}')" ] || \
	[ "${MD5SUM_INITRD}" != "$(md5sum ${TEMPDIR}/debian-live-${RELEASE}-${ARCH}-${INTERFACE}.initrd.img | awk -F" " '{print $1}')" ] || \
	[ "${MD5SUM_SQUASHFS}" != "$(md5sum ${TEMPDIR}/debian-live-${RELEASE}-${ARCH}-${INTERFACE}.squashfs | awk -F" " '{print $1}')" ]; then
	echo "!!! Checksum mismatch !!!"
	rm -f ${TEMPDIR}/debian-live-${RELEASE}-${ARCH}-${INTERFACE}.vmlinuz ${TEMPDIR}/debian-live-${RELEASE}-${ARCH}-${INTERFACE}.initrd.img ${TEMPDIR}/debian-live-${RELEASE}-${ARCH}-${INTERFACE}.squashfs
	clean_up 1
fi

################################################################################
# working directories

SOURCE_DIR="${TEMPDIR}"
DEST_DIR="debian/${SUITE}/liveboot/${ARCH}"
[ -n "${INTERFACE}" ] && DEST_DIR+="/${INTERFACE}"

mkdir -p ${DEST_DIR}

################################################################################
# get kernel

if [ -f "${TEMPDIR}/debian-live-${RELEASE}-${ARCH}-${INTERFACE}.vmlinuz" ]; then
	LINUX="vmlinuz"
	cp -f ${TEMPDIR}/debian-live-${RELEASE}-${ARCH}-${INTERFACE}.vmlinuz ${DEST_DIR}/vmlinuz
fi

[ -z "${LINUX}" ] && clean_up 1

################################################################################
#get ramdisk

cp -f ${TEMPDIR}/debian-live-${RELEASE}-${ARCH}-${INTERFACE}.initrd.img ${DEST_DIR}/initrd.img

################################################################################
# get config

LABEL="Debian ${SUITE} ${ARCH} LiveInstall"
[ -n "${INTERFACE}" ] && LABEL+=" ${INTERFACE}"
KERNEL="${DEST_DIR}/${LINUX}"
APPEND="vga=normal initrd=${DEST_DIR}/initrd.img --quiet"

################################################################################
# generate config

CONFIG_FILE="./.${SUITE}_${ARCH}_liveboot.config"
[ -n "${INTERFACE}" ] && CONFIG_FILE="./.${SUITE}_${ARCH}_${INTERFACE}_liveboot.config"
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
