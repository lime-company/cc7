# -----------------------------------------------------------------------------
# Main configuration for OpenSSL build
#
# OPENSSL_VERSION     Defines which OpenSSL version source codes will be downloaded in 'build.sh' script
#
# OPENSSL_SHA256      Defines SHA-256 checksum for source codes downloaded from openssl.org.
#                     This variable has to be updated together with $OPENSSL_VERSION.
#
# CC7_VERSION         OpenSSL version is strictly linked to the version of cc7. This variable basically
#                     links cc7 release version with the underlying OpenSSL version. So, the variable
#                     must be also updated together with $OPENSSL_VERSION.
#

OPENSSL_VERSION='1.1.1g'
OPENSSL_SHA256='ddb04774f1e32f0c49751e21b67216ac87852ceb056b75209af2443400636d46'
CC7_VERSION='0.2.3'


# -----------------------------------------------------------------------------
# Other common properties (shared between build.sh & fetch.sh)

OPENSSL_DEST="${TOP}/../openssl-lib"

OPENSSL_DEST_APPLE="${OPENSSL_DEST}/apple"
OPENSSL_DEST_APPLE_INFO="${OPENSSL_DEST_APPLE}/build-info.sh"
OPENSSL_DEST_APPLE_HELP="${OPENSSL_DEST_APPLE}/xcframework-helper.sh"
OPENSSL_DEST_APPLE_FILE="openssl-${OPENSSL_VERSION}-apple.tar.gz"
OPENSSL_DEST_APPLE_PATH="${OPENSSL_DEST}/${OPENSSL_DEST_APPLE_FILE}"

OPENSSL_DEST_ANDROID="${OPENSSL_DEST}/android"
OPENSSL_DEST_ANDROID_INFO="${OPENSSL_DEST_ANDROID}/build-info.sh"
OPENSSL_DEST_ANDROID_FILE="openssl-${OPENSSL_VERSION}-android.tar.gz"
OPENSSL_DEST_ANDROID_PATH="${OPENSSL_DEST}/${OPENSSL_DEST_ANDROID_FILE}"

# Init optional env variables, defaulting to empty string

CURL_OPTIONS="${CURL_OPTIONS:-}"
