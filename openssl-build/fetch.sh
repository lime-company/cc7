#!/bin/bash
###############################################################################
# Include common functions...
# -----------------------------------------------------------------------------
TOP=$(dirname $0)
source "${TOP}/common-functions.sh"
source "${TOP}/utils.sh"
source "${TOP}/config.sh"
source "${TOP}/config-fetch.sh"

FETCH_LOCK="${TOP}/.fetch-lock"

# Variables configured from command line

DO_APPLE=0
DO_ANDROID=0
DO_REMOVE_LOCK=0

# -----------------------------------------------------------------------------
# USAGE prints help and exits the script with error code from provided parameter
# Parameters:
#   $1   - error code to be used as return code from the script
# -----------------------------------------------------------------------------
function USAGE
{
	echo ""
	echo "Usage:  $CMD  [options]  platform"
	echo ""
	echo "Command downloads precompiled version of OpenSSL for the requested"
	echo "platform from github's release artifacts."
	echo ""
	echo "platform                can be  'ios', 'android' or 'all'"
	echo ""
	echo "options are:"
	echo ""
	echo "  --remove-lock         remove filesystem lock in case that last fetch"
	echo "                        was aborted and the lock is still present."
	echo ""
	echo "  -v0                   turn off all prints to stdout"
	echo "  -v1                   print only basic log about execution progress"
	echo "  -v2                   print full build log with rich debug info"
	echo "  -h | --help           print this help information"
	echo ""
	exit $1
}

# -----------------------------------------------------------------------------
# FETCH_ARCHIVE downloads precompiled archive from remote source. 
#
# Parameters:
#   $1   - platform archive to fetch (apple or android)
# -----------------------------------------------------------------------------
function FETCH_ARCHIVE
{
	local PLATFORM="$1"
	local URL=
	local HASH=
	local INFO=
	local DEST=
	local DEST_DIR=
	local INDENT=
	case "${PLATFORM}" in
		apple)
			URL=${OPENSSL_FETCH_APPLE_URL}
			HASH=${OPENSSL_FETCH_APPLE_HASH}
			INFO="${OPENSSL_DEST_APPLE_INFO}"
			DEST="${OPENSSL_DEST_APPLE_PATH}"
			DEST_DIR="${OPENSSL_DEST_APPLE}"
			INDENT='Apple xcframework:'
			;;
		android)
			URL=${OPENSSL_FETCH_ANDROID_URL}
			HASH=${OPENSSL_FETCH_ANDROID_HASH}
			INFO="${OPENSSL_DEST_ANDROID_INFO}"
			DEST="${OPENSSL_DEST_ANDROID_PATH}"
			DEST_DIR="${OPENSSL_DEST_ANDROID}"
			INDENT='Android libraries:'
			;;
		*)
			FAILURE "Unexpected option passed to FETCH_ARCHIVE function"
	esac
	
	if [ -f "${INFO}" ]; then
		# Info file is present. This means that precompiled lib is already 
		# extracted at destination folder. We have to check version and hash.
		source ${INFO}
		if [ ! -z ${OPENSSL_PREBUILD_VERSION} ] && [ ! -z ${OPENSSL_PREBUILD_HASH} ]; then
			if [ ${OPENSSL_PREBUILD_VERSION} == ${OPENSSL_VERSION} ] && [ ${OPENSSL_PREBUILD_HASH} == ${HASH} ]; then
				LOG "$INDENT Library is prepared at: $(dirname ${INFO})"
				return 0
			fi
		else
			WARNING "$INDENT Info file doens't contain expected variables: ${INFO}"
			$RM "${INFO}"
		fi
	fi
	
	if [ -f "${DEST}" ]; then
		# Destination file exists, try to validate its hash
		if [ $(SHA256 "${DEST}") == ${HASH} ]; then
			LOG "$INDENT Library is already downloaded at: ${DEST}"
		else
			WARNING "$INDENT Downloaded precompiled library is corrupted. Removing file: ${DEST}"
			$RM "${DEST}"
		fi
	fi

	if [ ! -f "${DEST}" ]; then
		# The destination file doesn't exist. Try to download it from the remote site.
		LOG "$INDENT Downloading precompiled archive $(basename ${DEST})..."
		DEBUG_LOG "   - URL  : ${URL}"
		DEBUG_LOG "   - dest : ${DEST}"
		$MD $(dirname $DEST)
		curl ${CURL_OPTIONS} -sL ${URL} > "${DEST}"
		if [ ! -f "${DEST}" ]; then
			FAILURE "$INDENT Failed to download precompiled archive from URL: $URL"
		fi
		if [ $(SHA256 "${DEST}") != ${HASH} ]; then
			$RM "${DEST}"
			FAILURE "$INDENT Downloaded precompiled OpenSSL archive is corrupted. URL: $URL"
		fi
	fi
	
	LOG "$INDENT Extracting precompiled library..."
	
	# Remove the destination directory
	$RM -rf "${DEST_DIR}"
	PUSH_DIR "${OPENSSL_DEST}"
	# -----
	tar -xf $(basename ${DEST}) -C .
	# -----
	POP_DIR
	
	# Re-create info file
	SAVE_ARCHIVE_INFO_FILE "${DEST}" "${HASH}"
	
	LOG "$INDENT Library is prepared at: $(dirname ${INFO})"
}

###############################################################################
# Script's main execution starts here...
# -----------------------------------------------------------------------------

# Process command line paramters

while [[ $# -gt 0 ]]
do
	opt="$1"
	case "$opt" in
		apple)
			DO_APPLE=1
			;;
		android)
			DO_ANDROID=1
			;;
		all)
			DO_APPLE=1
			DO_ANDROID=1
			;;
		--remove-lock)
			DO_REMOVE_LOCK=1
			;;
		-v*)
			SET_VERBOSE_LEVEL_FROM_SWITCH $opt
			;;
		-h | --help)
			USAGE 0
			;;
		*)
			USAGE 1
			;;
	esac
	shift
done
UPDATE_VERBOSE_COMMANDS

# Validate input parameters

if [ $DO_APPLE$DO_ANDROID == 00 ]; then
	FAILURE "You have to specify platform to fetch."
fi

if [ x$DO_REMOVE_LOCK == x1 ]; then
	if [ -d "${FETCH_LOCK}" ]; then
		WARNING "Force-removing lock as requested: "${FETCH_LOCK}""
		REMOVE_LOCK "${FETCH_LOCK}"
	fi
fi

ACQUIRE_LOCK "${FETCH_LOCK}" 60
# -----------------------------------------------------------------------------

LOG_LINE
[[ x${DO_ANDROID} == x1 ]] && FETCH_ARCHIVE android
[[ x${DO_APPLE}   == x1 ]] && FETCH_ARCHIVE apple

# -----------------------------------------------------------------------------
REMOVE_LOCK "${FETCH_LOCK}"
EXIT_SUCCESS
