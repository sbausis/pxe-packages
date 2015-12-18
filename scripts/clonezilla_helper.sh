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
#if [ -z `which pax` ]; then NEEDEDPACKAGES+="pax "; fi
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

VERSION=${VERSION-"2.4.2-61"}
ARCH=${ARCH-"amd64"}

################################################################################
# Download-URL

MIRROR_URL="http://downloads.sourceforge.net"
FOLDER_URL="project/clonezilla/clonezilla_live_stable/${VERSION}"
FILE_URL="clonezilla-live-${VERSION}-${ARCH}.zip"

URL="${MIRROR_URL}/${FOLDER_URL}/${FILE_URL}"

################################################################################
# download LiveBoot-Image

wget -O ${TEMPDIR}/${FILE_URL} ${URL}

################################################################################
# extract NetBoot-Image

mkdir -p ${TEMPDIR}/clonezilla-live-${VERSION}-${ARCH}
unzip -j ${TEMPDIR}/${FILE_URL} -d ${TEMPDIR}/clonezilla-live-${VERSION}-${ARCH}

################################################################################
# working directories

SOURCE_DIR="${TEMPDIR}/clonezilla-live-${VERSION}-${ARCH}"
DEST_DIR="clonezilla/${VERSION}/${ARCH}"

mkdir -p ${DEST_DIR}

################################################################################
# get files

cp -Rf ${SOURCE_DIR}/* ${DEST_DIR}/

################################################################################
# generate config

CONFIG_FILE="./.clonezilla-live-${VERSION}-${ARCH}.config"
cat <<EOF > ${CONFIG_FILE}
LABEL $LABEL
 KERNEL $KERNEL
 APPEND $APPEND
EOF
cp -f ${CONFIG_FILE} ./config.txt

################################################################################
# cleanUp

clean_up 0

################################################################################
