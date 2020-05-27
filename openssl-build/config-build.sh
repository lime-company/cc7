# -----------------------------------------------------------------------------
# Archive file, remote URL and local path

OPENSSL_ARCHIVE_FILE="openssl-${OPENSSL_VERSION}.tar.gz"
OPENSSL_ARCHIVE_URL="https://www.openssl.org/source/${OPENSSL_ARCHIVE_FILE}"
OPENSSL_ARCHIVE_LOCAL_PATH="${OPENSSL_DEST}/${OPENSSL_ARCHIVE_FILE}"

# OpenSSL features

OPENSSL_CONF_PARAMS=" no-deprecated no-filenames no-shared no-sock no-tls no-ssl no-ssl2 no-ssl3 no-ui-console no-engine no-comp no-ts no-ocsp no-async no-tests"
OPENSSL_CONF_PARAMS+=" no-idea no-camellia no-seed no-bf no-cast no-des no-rc2 no-rc4 no-rc5 no-md2 no-md4 no-dsa no-dh no-rfc3779"
OPENSSL_CONF_PARAMS+=" no-whirlpool no-srp no-mdc2 no-srtp no-aria no-ct no-gost no-poly1305 no-sm2 no-sm3 no-sm4"
OPENSSL_CONF_PARAMS+=" no-scrypt no-blake2 no-siphash"


# -----------------------------------------------------------------------------
# Apple specific
#  - Note that we don't build all architectures and platforms. 
#    The following lists exclude watchOS and OSX variants from the build.

APPLE_PLATFORMS="iOS iOS_Simulator macOS_Catalyst tvOS tvOS_Simulator"
APPLE_TARGETS="ios-sim-cross-x86_64 ios-cross-armv7 ios-cross-armv7s ios64-cross-arm64 ios64-cross-arm64e mac-catalyst-x86_64 tvos-sim-cross-x86_64 tvos64-cross-arm64"

# Minimum system versions
APPLE_IOS_MIN_SDK="8.0"
APPLE_TVOS_MIN_SDK="9.0"
APPLE_CATALYST_MIN_SDK="10.15"
APPLE_WATCHOS_MIN_SDK="2.0"
APPLE_OSX_MIN_SDK="10.11"


# -----------------------------------------------------------------------------
# Android specific

ANDROID_ARCHITECTURES="armeabi-v7a arm64-v8a x86 x86_64" 
ANDROID_API_LEVEL="21"

# -----------------------------------------------------------------------------
# Other params

BUILD_JOBS_COUNT=$(getconf _NPROCESSORS_ONLN)
CC7_RELEASE_URL="https://github.com/wultra/cc7/releases"