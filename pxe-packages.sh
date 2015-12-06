#!/bin/bash

set -e
#set -x

SCRIPTNAME=$(basename "$0")
SCRIPTDIR=$(cd `dirname "$0"` && pwd)

function create_debian_netinstall_pxe_package() {
	local MIRROR="$1"
	local SUITE="$2"
	local ARCH="$3"
	local INTERFACE="$4"
	mkdir -p pxe-packages
	echo "MIRROR=${MIRROR};SUITE=${SUITE};ARCH=${ARCH};INTERFACE=${INTERFACE};" > /tmp/config.sh
	cat ${SCRIPTDIR}/.scripts/debian_netinstall_helper.sh >> /tmp/config.sh
	if [ -n "${INTERFACE}" ]; then
		tar -czf pxe-packages/debian_${SUITE}_netinstall_${ARCH}_${INTERFACE}.tar.gz -C /tmp config.sh
	else
		tar -czf pxe-packages/debian_${SUITE}_netinstall_${ARCH}.tar.gz -C /tmp config.sh
	fi
	rm -f /tmp/config.sh
}

# create Debian squeeze NetInstall package
create_debian_netinstall_pxe_package "ch" "squeeze" "amd64"
create_debian_netinstall_pxe_package "ch" "squeeze" "i386"
create_debian_netinstall_pxe_package "ch" "squeeze" "amd64" "gtk"
create_debian_netinstall_pxe_package "ch" "squeeze" "i386" "gtk"

# create Debian wheezy NetInstall package
create_debian_netinstall_pxe_package "ch" "wheezy" "amd64"
create_debian_netinstall_pxe_package "ch" "wheezy" "i386"
create_debian_netinstall_pxe_package "ch" "wheezy" "amd64" "gtk"
create_debian_netinstall_pxe_package "ch" "wheezy" "i386" "gtk"

# create Debian sid NetInstall package
create_debian_netinstall_pxe_package "ch" "sid" "amd64"
create_debian_netinstall_pxe_package "ch" "sid" "i386"
create_debian_netinstall_pxe_package "ch" "sid" "amd64" "gtk"
create_debian_netinstall_pxe_package "ch" "sid" "i386" "gtk"

# create Debian jessie NetInstall package
create_debian_netinstall_pxe_package "ch" "jessie" "amd64"
create_debian_netinstall_pxe_package "ch" "jessie" "i386"
create_debian_netinstall_pxe_package "ch" "jessie" "amd64" "gtk"
create_debian_netinstall_pxe_package "ch" "jessie" "i386" "gtk"

# create Debian stretch NetInstall package
create_debian_netinstall_pxe_package "ch" "stretch" "amd64"
create_debian_netinstall_pxe_package "ch" "stretch" "i386"
create_debian_netinstall_pxe_package "ch" "stretch" "amd64" "gtk"
create_debian_netinstall_pxe_package "ch" "stretch" "i386" "gtk"

LOCAL_PACKAGES=$(cd pxe-packages && find . -type f -name "*.tar.gz")
(for PACKAGE in ${LOCAL_PACKAGES}; do
	echo "http://UniverseNAS.0rca.ch/sources/pxe-packages/"$(basename ${PACKAGE})
done) > /tmp/pxe-packages.list

REMOTE_PACKAGES=$(wget -qq -O - http://pxe.omv-extras.org/packages)
(for PACKAGE in ${REMOTE_PACKAGES}; do
	
	echo "http://pxe.omv-extras.org/${PACKAGE}"
done) >> /tmp/pxe-packages.list

cat <(cat /tmp/pxe-packages.list | sort) > pxe-packages.list
rm -f /tmp/pxe-packages.list

echo "6.03" > pxe-syslinux

exit 0
