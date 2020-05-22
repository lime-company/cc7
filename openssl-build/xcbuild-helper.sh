#!/bin/bash
# -----------------------------------------------------------------------------
# This script helps with extracting platform specific framework from final
# xcframework.
# -----------------------------------------------------------------------------

###############################################################################
# Include common functions...
# -----------------------------------------------------------------------------
TOP=$(dirname $0)
source "${TOP}/common-functions.sh"
source "${TOP}/config.sh"

OPT_PLATFORM_SUFFIX=$1
OPT_DEST_FOLDER=$2

UPDATE_VERBOSE_COMMANDS

XCFRAMEWORK="${OPENSSL_DEST_APPLE}/openssl.xcframework"

[[ -z "${OPT_PLATFORM_SUFFIX}"       ]] && FAILURE "Missing build platform dir suffix."
[[ -z "${OPT_DEST_FOLDER}"           ]] && FAILURE "Missing build destination folder."
[[ ! -d "${XCFRAMEWORK}"             ]] && FAILURE "Looks like there's no precompiled openssl framework. Run 'fetch.sh apple' before this script."
[[ ! -f "${OPENSSL_DEST_APPLE_HELP}" ]] && FAILURE "Unable to locate helper script: ${OPENSSL_DEST_APPLE_HELP}"
[[ ! -d "${OPT_DEST_FOLDER}"         ]] && LOG "Build destination folder is missing, or there's no folder at path: ${OPT_DEST_FOLDER}" && $MD "${OPT_DEST_FOLDER}"

source "${OPENSSL_DEST_APPLE_HELP}"

LOG_LINE

LOG "Translating platform dir suffix '${OPT_PLATFORM_SUFFIX}' into platform..."

LIBRARY_IDENTIFIER=$(TRANSLATE_BUILD_SUFFIX ${OPT_PLATFORM_SUFFIX})

LOG "Copying inner framework for platform '${LIBRARY_IDENTIFIER}'"

if [ -d "${OPT_DEST_FOLDER}/openssl.framework" ]; then
	LOG "  remove-existing-path"
	LOG "       at: ${OPT_DEST_FOLDER}/openssl.framework"
	$RM -r "${OPT_DEST_FOLDER}/openssl.framework"
fi

LOG "  copy"
LOG "     from: ${XCFRAMEWORK}/${LIBRARY_IDENTIFIER}/openssl.framework"
LOG "       to: ${OPT_DEST_FOLDER}/openssl.framework"

$CP -r "${XCFRAMEWORK}/${LIBRARY_IDENTIFIER}/openssl.framework" "${OPT_DEST_FOLDER}"

EXIT_SUCCESS
