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

function _get_includes() {
	local FOLDER="$1"
	local FILE="$2"
	local INCLUDES=""
	local RET=""
	if [ -f "${FOLDER}/${FILE}" ]; then
		RET+="${FILE} "
		INCLUDES+=$(cat ${FOLDER}/${FILE} | grep -P '^[ \t]*include' | gsed 's/^[ \t]*include[ \t]*//')
		INCLUDES+=" "
		for INC in ${INCLUDES}; do
			INCLUDES+=$(_get_includes ${FOLDER} ${INC})
		done
	fi
	for INC in ${INCLUDES}; do
		[ -n "${INC}" ] && RET+="${INC} "
	done
	[ -n "${RET}" ] && echo "${RET}"
}
function get_includes() {
	local FOLDER="$1"
	local FILE="$2"
	local FILES=$(_get_includes "${FOLDER}" "${FILE}")
	(for F in ${FILES}; do
		[ -f "${FOLDER}/${F}" ] && echo "${FOLDER}/${F}"
	done) | sort -u
}

function _read_config() {
	local FOLDER="$1"
	local FILE="$2"
	local READ=$(for F in ${FILES}; do [ "${FOLDER}/${FILE}" == "${F}" ] && echo "f"; done)
	if [ -z "${READ}" ]; then
		FILES+="${FOLDER}/${FILE} "
		while IFS= read -r LINE; do
			local INCLUDE=$(echo "${LINE}" | grep -P '^[ \t]*include' | gsed 's/^[ \t]*include[ \t]*//')
			if [ -n "${INCLUDE}" ] && [ -f "${FOLDER}/${INCLUDE}" ]; then
				#echo "# ${LINE}"
				_read_config ${FOLDER} ${INCLUDE}
			else
				echo "${LINE}"
			fi
		done < ${FOLDER}/${FILE}
	#else
	#	FILES+="${FOLDER}/${FILE} "
	fi
}
function read_config() {
	local FOLDER="$1"
	local FILE="$2"
	local FILES=""
	_read_config "${FOLDER}" "${FILE}" | grep -v -P '^[ \t]*#' | grep -v -P '^[ \t]*$'
}

function _parse_config() {
	local ENTRY_CNT=0
	local ENTRIES
	declare -a ENTRIES
	
	local MENU_TITLE=""
	local MENU_BACKGROUND=""
	local DEFAULT_ENRTY=""
	
	local IS_ENTRY=1
	local ENTRY_NAME=""
	local ENTRY_TITLE=""
	local ENTRY_KERNEL=""
	local ENTRY_APPEND=""
	while IFS= read -r line; do
		
		#echo "${line}" 1>&2
		if [ -n "$(echo "${line}" | grep -P '^[ \t]*[Mm][Ee][Nn][Uu] [Ee][Nn][Dd][ \t]*.*$')" ]; then
			IS_ENTRY=1 ENTRY_NAME="" ENTRY_TITLE="" ENTRY_KERNEL="" ENTRY_APPEND=""
			#echo "### Entry End" 1>&2
		fi
		
		if [ -n "$(echo "${line}" | grep -P '^[ \t]*[Ll][Aa][Bb][Ee][Ll][ \t]*.*$')" ]; then
			IS_ENTRY=0 ENTRY_NAME="" ENTRY_TITLE="" ENTRY_KERNEL="" ENTRY_APPEND=""
			#echo "### Entry START" 1>&2
		fi
		
		if [ "${IS_ENTRY}" == "0" ]; then
			if [ -n "$(echo "${line}" | grep -P '^[ \t]*[Ll][Aa][Bb][Ee][Ll][ \t]*.*$')" ]; then
				ENTRY_NAME=$(echo "${line}" | gsed 's/^[ \t]*[Ll][Aa][Bb][Ee][Ll][ \t]*//')
				echo "### Entry Name: ${ENTRY_NAME}" 1>&2
			elif [ -n "$(echo "${line}" | grep -P '^[ \t]*[Mm][Ee][Nn][Uu] [Ll][Aa][Bb][Ee][Ll][ \t]*.*$')" ]; then
				ENTRY_TITLE=$(echo "${line}" | gsed 's/^[ \t]*[Mm][Ee][Nn][Uu] [Ll][Aa][Bb][Ee][Ll][ \t]*//')
				#echo "### Entry Title: ${ENTRY_TITLE}" 1>&2
			elif [ -n "$(echo "${line}" | grep -P '^[ \t]*[Kk][Ee][Rr][Nn][Ee][Ll][ \t]*.*$')" ]; then
				ENTRY_KERNEL=$(echo "${line}" | gsed 's/^[ \t]*[Kk][Ee][Rr][Nn][Ee][Ll][ \t]*//')
				#echo "### Entry Kernel: ${ENTRY_KERNEL}" 1>&2
			elif [ -n "$(echo "${line}" | grep -P '^[ \t]*[Aa][Pp][Pp][Ee][Nn][Dd][ \t]*.*$')" ]; then
				ENTRY_APPEND=$(echo "${line}" | gsed 's/^[ \t]*[Aa][Pp][Pp][Ee][Nn][Dd][ \t]*//')
				#echo "### Entry Append: ${ENTRY_APPEND}" 1>&2
			fi
			if [ -n "${ENTRY_NAME}" ] && [ -n "${ENTRY_TITLE}" ] && [ -n "${ENTRY_KERNEL}" ] && [ -n "${ENTRY_APPEND}" ]; then
				ENTRIES[${ENTRY_CNT}]="ENTRY_NAME=\"${ENTRY_NAME}\" ENTRY_TITLE=\"${ENTRY_TITLE}\" ENTRY_KERNEL=\"${ENTRY_KERNEL}\" ENTRY_APPEND=\"${ENTRY_APPEND}\""
				ENTRY_CNT=$((${ENTRY_CNT}+1))
				IS_ENTRY=1
			fi
		else
			
			
			if [ -z "${MENU_TITLE}" ] && [ -n "$(echo "${line}" | grep -P '^[ \t]*[Mm][Ee][Nn][Uu] [Tt][Ii][Tt][Ll][Ee][ \t]*.*$')" ]; then
				MENU_TITLE=$(echo "${line}" | gsed 's/^[ \t]*[Mm][Ee][Nn][Uu] [Tt][Ii][Tt][Ll][Ee][ \t]*//')
				echo "### Menu Title: ${MENU_TITLE}" 1>&2
			elif [ -z "${MENU_BACKGROUND}" ] && [ -n "$(echo "${line}" | grep -P '^[ \t]*[Mm][Ee][Nn][Uu] [Bb][Aa][Cc][Kk][Gg][Rr][Oo][Uu][Nn][Dd][ \t]*.*$')" ]; then
				MENU_BACKGROUND=$(echo "${line}" | gsed 's/^[ \t]*[Mm][Ee][Nn][Uu] [Bb][Aa][Cc][Kk][Gg][Rr][Oo][Uu][Nn][Dd][ \t]*//')
				echo "### Menu Background: ${MENU_BACKGROUND}" 1>&2
			elif [ -z "${DEFAULT_ENRTY}" ] && [ -n "$(echo "${line}" | grep -P '^[ \t]*[Dd][Ee][Ff][Aa][Uu][Ll][Tt][ \t]*.*$')" ]; then
				DEFAULT_ENRTY=$(echo "${line}" | gsed 's/^[ \t]*[Dd][Ee][Ff][Aa][Uu][Ll][Tt][ \t]*//')
				echo "### Default Entry: ${DEFAULT_ENRTY}" 1>&2
			fi
		fi
	done
	if [ ${ENTRY_CNT} -gt 0 ]; then
		local RET=""
		RET+="ENTRY_CNT=\"${ENTRY_CNT}\""
		[ -n "${MENU_TITLE}" ] && RET+=" MENU_TITLE=\"${MENU_TITLE}\""
		[ -n "${MENU_BACKGROUND}" ] && RET+=" MENU_BACKGROUND=\"${MENU_BACKGROUND}\""
		[ -n "${DEFAULT_ENRTY}" ] && RET+=" DEFAULT_ENRTY=\"${DEFAULT_ENRTY}\""
		echo "${RET}"
		local CNT=0
		while [ ${CNT} -lt ${ENTRY_CNT} ]; do
			echo "${ENTRIES[${CNT}]}"
			CNT=$((${CNT}+1))
		done
	fi
}
function parse_config() {
	local FOLDER="$1"
	local FILE="$2"
	read_config "${FOLDER}" "${FILE}" | _parse_config
}

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

INPUT="$1"
FOLDER=$(dirname "${INPUT}")
FILE=$(basename "${INPUT}")

################################################################################

echo "# ${SCRIPTNAME} ${FOLDER} ${FILE}" 1>&2

INCLUDES=$(get_includes ${FOLDER} ${FILE})
echo "${INCLUDES}" 1>&2
echo ""
#CONFIG=$(read_config ${FOLDER} ${FILE})
#echo "${CONFIG}"

#PARSED=$(parse_config ${FOLDER} ${FILE})
#echo "${PARSED}"

parse_config ${FOLDER} ${FILE}

#INCLUDES=$(get_includes ${FOLDER} debian-installer/amd64/boot-screens/menu.cfg)
#echo "${INCLUDES}"
echo ""

clean_up 0

################################################################################
