#!/bin/bash

set -e
#set -x

SCRIPTNAME=$(basename "$0")
SCRIPTDIR=$(cd `dirname "$0"` && pwd)

function create_debian_netinstall_pxe_package() {
	local MIRROR="$1"
	local SUITE="$2"
	local ARCH="$3"
	echo "MIRROR=${MIRROR};SUITE=${SUITE};ARCH=${ARCH}" > /tmp/config.sh
	cat ${SCRIPTDIR}/.scripts/debian_netinstall_helper.sh >> /tmp/config.sh
	tar -czf pxe-packages/debian_${SUITE}_netinstall_${ARCH}.tar.gz -C /tmp config.sh
	rm -f /tmp/config.sh
}

# create Debian squeeze NetInstall package
create_debian_netinstall_pxe_package "ch" "squeeze" "amd64"
create_debian_netinstall_pxe_package "ch" "squeeze" "i386"

# create Debian wheezy NetInstall package
create_debian_netinstall_pxe_package "ch" "wheezy" "amd64"
create_debian_netinstall_pxe_package "ch" "wheezy" "i386"

# create Debian jessie NetInstall package
create_debian_netinstall_pxe_package "ch" "jessie" "amd64"
create_debian_netinstall_pxe_package "ch" "jessie" "i386"

LOCAL_PACKAGES=$(cd pxe-packages && find . -type f -name "*.tar.gz")
(for PACKAGE in ${LOCAL_PACKAGES}; do
	echo "http://UniverseNAS.0rca.ch/sources/pxe-packages/"$(basename ${PACKAGE})
done) > pxe-packages.list

REMOTE_PACKAGES=$(wget -qq -O - http://pxe.omv-extras.org/packages)
(for PACKAGE in ${REMOTE_PACKAGES}; do
	
	echo "http://pxe.omv-extras.org/${PACKAGE}"
done) >> pxe-packages.list

exit 0
