#!/bin/bash

set -e
set -x

export LANGUAGE=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

SCRIPTNAME=$(basename "$0")
SCRIPTNAME=$(basename "$0")
SCRIPTDIR=$(cd `dirname "$0"`; pwd)
SCRIPTSDIR="${SCRIPTDIR}/.scripts"

################################################################################
## Need Packages

NEEDEDPACKAGES=""
#if [ -z `which debootstrap` ]; then NEEDEDPACKAGES+="debootstrap "; fi
if [ -n "${NEEDEDPACKAGES}" ]; then
	echo "Need ${NEEDEDPACKAGES}, installing them..."
	apt-get -qq -y install ${NEEDEDPACKAGES}
fi

################################################################################
## Need TEMPDIR

TEMPDIR=$(mktemp -d -t ${SCRIPTNAME}.XXXXXXXXXX)
LOCKFILE=${TEMPDIR}.lock
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

Usage: ${SCRIPTNAME} [OPTIONS]... -o [OUTFILE]

Options
 -o          set OUTFILE
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
# get Arguments

OUTDIR=""

################################################################################
# need newest Script installed

REMOTE_REF=$(git ls-remote https://github.com/sbausis/${SCRIPTNAME}.git | grep "refs/heads/master" | awk '{print $1}')
[ -f "/usr/local/lib/${SCRIPTNAME}/${SCRIPTNAME}.ref" ] && LOCAL_REF=$(cat "/usr/local/lib/${SCRIPTNAME}/${SCRIPTNAME}.ref")

if [ ! -f "/usr/local/bin/${SCRIPTNAME}" ] || [ -z "${LOCAL_REF}" ] || [ "${LOCAL_REF}" != "${REMOTE_REF}" ] || [ "${INSTALL}" == "0" ]; then
	
	echo "Installing to /usr/local/lib/${SCRIPTNAME} ..."
	git clone https://github.com/sbausis/${SCRIPTNAME}.git ${TEMPDIR}/${SCRIPTNAME}
	rm -Rf /usr/local/lib/${SCRIPTNAME}
	mkdir -p /usr/local/lib/${SCRIPTNAME}
	cp -Rf ${TEMPDIR}/${SCRIPTNAME}/${SCRIPTNAME} ${TEMPDIR}/${SCRIPTNAME}/.scripts /usr/local/lib/${SCRIPTNAME}/
	echo "${REMOTE_REF}" > "/usr/local/lib/${SCRIPTNAME}/${SCRIPTNAME}.ref"
	cat <<EOF > /usr/local/bin/${SCRIPTNAME}
#!/bin/bash
bash /usr/local/lib/${SCRIPTNAME}/${SCRIPTNAME} \$@
exit \$?
EOF
	chmod +x /usr/local/bin/${SCRIPTNAME}
	/usr/local/bin/${SCRIPTNAME} $@
	clean_up $?

fi

################################################################################
# need Arguments

if [ -z "${OUTDIR}" ] && [ -f "~/.pxe-packages" ]; then
	source "~/.pxe-packages"
else
	OUTDIR="./"
fi
[ -d "${OUTDIR}" ] || help_exit

################################################################################

function create_debian_netinstall_pxe_package() {
	local MIRROR="$1"
	local SUITE="$2"
	local ARCH="$3"
	local INTERFACE="$4"
	mkdir -p pxe-packages
	echo "MIRROR=${MIRROR};SUITE=${SUITE};ARCH=${ARCH};INTERFACE=$INTERFACE" >/config.sh
	cat ${SCRIPTSDIR}/debian_netinstall_helper.sh >> ${TEMPDIR}/config.sh
	if [ -n "${INTERFACE}" ]; then
		tar -czf pxe-packages/debian_${SUITE}_netinstall_${ARCH}_${INTERFACE}.tar.gz -C ${TEMPDIR} ${OUTDIR}/config.sh
	else
		tar -czf pxe-packages/debian_${SUITE}_netinstall_${ARCH}.tar.gz -C ${TEMPDIR} ${OUTDIR}/config.sh
	fi
	rm -f ${TEMPDIR}/config.sh
}

################################################################################

echo "[ ${SCRIPTNAME} ] ${OUTDIR}"
STARTTIME=`date +%s`

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

# create Debian jessie NetInstall package
create_debian_netinstall_pxe_package "ch" "jessie" "amd64"
create_debian_netinstall_pxe_package "ch" "jessie" "i386"
create_debian_netinstall_pxe_package "ch" "jessie" "amd64" "gtk"
create_debian_netinstall_pxe_package "ch" "jessie" "i386" "gtk"

LOCAL_PACKAGES=$(cd pxe-packages && find . -type f -name "*.tar.gz")
(for PACKAGE in ${LOCAL_PACKAGES}; do
	echo "http://UniverseNAS.0rca.ch/sources/pxe-packages/"$(basename ${PACKAGE})
done) > ${TEMPDIR}/pxe-packages.list

REMOTE_PACKAGES=$(wget -qq -O - http://pxe.omv-extras.org/packages)
(for PACKAGE in ${REMOTE_PACKAGES}; do
	echo "http://pxe.omv-extras.org/${PACKAGE}"
done) >> ${TEMPDIR}/pxe-packages.list

cat <(cat ${TEMPDIR}/pxe-packages.list | sort) > ${OUTDIR}/pxe-packages.list
rm -f ${TEMPDIR}/pxe-packages.list

echo "6.03" > ${OUTDIR}/pxe-syslinux

################################################################################

STOPTIME=`date +%s`
RUNTIME=$((STOPTIME-STARTTIME))
echo "Runtime: $RUNTIME sec"

clean_up 0

################################################################################
