#!/bin/bash
###############################################################################

if [ x$OPENSSL_VERSION == 'x' ]; then
	echo "Do not use this script explicitly. Use 'build.sh' instead."
	exit 1
fi

REQUIRE_COMMAND curl
REQUIRE_COMMAND shasum

function VALIDATE_DOWNLOADED_OPENSSL
{
	set +e
	if [ ! -f ${OPENSSL_ARCHIVE_LOCAL_PATH} ]; then
		FAILURE "${OPENSSL_ARCHIVE_FILE} is not downloaded yet."
	fi
	if [ $(SHA256 ${OPENSSL_ARCHIVE_LOCAL_PATH}) == "${OPENSSL_SHA256}" ]; then
		echo "1"
	else
		echo "0"
	fi
	set -e
	echo $RESULT
}

function DOWNLOAD_OPENSSL
{
	LOG "Downloading ${OPENSSL_ARCHIVE_FILE} ..."
	
	$MD ${OPENSSL_DEST}
	curl ${CURL_OPTIONS} -s ${OPENSSL_ARCHIVE_URL} > "${OPENSSL_ARCHIVE_LOCAL_PATH}"
	
	LOG "Validating downloaded file ..."
	if [ x$(VALIDATE_DOWNLOADED_OPENSSL) != x1 ]; then
		DEBUG_LOG "File          : ${OPENSSL_ARCHIVE_LOCAL_PATH}"
		DEBUG_LOG "Expected hash : ${OPENSSL_SHA256}"
		FAILURE "Downloaded OpenSSL archive is corrupted."
	fi
}

function GET_OPENSSL_ARCHIVE
{
	if [ ! -f ${OPENSSL_ARCHIVE_LOCAL_PATH} ]; then
		DOWNLOAD_OPENSSL
	else
		DEBUG_LOG "Validating already downloaded file ..."
		if [ x$(VALIDATE_DOWNLOADED_OPENSSL) != x1 ]; then
			WARNING "Downloaded OpenSSL archive has invalid hash. Trying to download it again."
			$RM ${OPENSSL_ARCHIVE_LOCAL_PATH}
			DOWNLOAD_OPENSSL
		fi
	fi
	DEBUG_LOG "OpenSSL archive is available at: ${OPENSSL_ARCHIVE_LOCAL_PATH}"
}