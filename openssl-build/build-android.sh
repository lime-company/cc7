#!/bin/bash
###############################################################################

if [ x$OPENSSL_VERSION == 'x' ]; then
	echo "Do not use this script explicitly. Use 'build.sh' instead."
	exit 1
fi

# -----------------------------------------------------------------------------
# BUILD_ANDROID builds all Android architectures
# 
# Env variables:
#   $ANDROID_HOME      - path to Android SDK home folder
#   $ANDROID_NDK_HOME  - path to Android NDK folder
#   
# -----------------------------------------------------------------------------
function BUILD_ANDROID
{
	local TMP_PATH="${TOP}/android"
	local BUILD_LOG=$TMP_PATH/Build.log
	
	LOG_LINE
	LOG "Building OpenSSL ${OPENSSL_VERSION} for Android platforms..."
	
	if [ ! -z "$ANDROID_NDK_HOME" ]; then
		local NDK_DIR="$ANDROID_NDK_HOME"
	elif  [ ! -z "$ANDROID_HOME" ]; then
		local NDK_DIR="$ANDROID_HOME/ndk-bundle"
	else
		FAILURE "Neither \$ANDROID_NDK_HOME or \$ANDROID_HOME environment library is set."
	fi
	
	DEBUG_LOG "Destination folders cleanup"
	
	[[ -d "${OPENSSL_DEST_ANDROID}" ]] && $RM -rf "${OPENSSL_DEST_ANDROID}"
	[[ -f "${OPENSSL_DEST_ANDROID_PATH}" ]] && $RM "${OPENSSL_DEST_ANDROID_PATH}"
	$MD "${OPENSSL_DEST_ANDROID}"
	$MD "${OPENSSL_DEST_ANDROID}/include"
	
	DEBUG_LOG "Configure PATH variable"
	
	local KEEP_PATH="$PATH"
	local TOOLCHAIN_PATH=$(BUILD_ANDROID_TOOLCHAIN_PATH $NDK_DIR)
	export PATH=$NDK_DIR:$TOOLCHAIN_PATH:$PATH
	
	DEBUG_LOG "Validate clang"
	
	REQUIRE_COMMAND clang
	local TEST_CLANG=$(clang -v 2>&1 >/dev/null)
	case ${TEST_CLANG} in
		Android*)
			DEBUG_LOG "Using clang compiler at: $(REQUIRE_COMMAND_PATH clang)"
			;;
		*)
			FAILURE "Failed to find proper Android clang compiler."
			;;
	esac
	
	DEBUG_LOG "Build all architectures"
	
	# Array with all per-architecture configuration headers
	ANDROID_CONF_ALL=()
	
	for ABI in ${ANDROID_ARCHITECTURES}
	do
		BUILD_ANDROID_ARCH $ABI $NDK_DIR
	done
	# Make platform switch header
	BUILD_ANDROID_PLATFORM_SWITCH "${OPENSSL_DEST_ANDROID}/include"
	
	LOG "Making Android archive..."
	DEBUG_LOG "Archive path: ${OPENSSL_DEST_ANDROID_PATH}"
	
	PUSH_DIR "${OPENSSL_DEST}"
	# ----
	export GZIP='-9'
	echo "### tar package" > ${BUILD_LOG}
	tar -zcvf ${OPENSSL_DEST_ANDROID_FILE} android >> ${BUILD_LOG} 2>&1
	SAVE_ARCHIVE_INFO_FILE "${OPENSSL_DEST_ANDROID_FILE}"
	# ----
	POP_DIR 
	LOG "Final cleanup..."
	$RM -rf "${TOP}/android"
	
	# Restore previous PATH content
	export PATH="$KEEP_PATH"
}

# -----------------------------------------------------------------------------
# BUILD_ANDROID_ARCH builds one architecture
# 
# Parameters:
#   $1   - architecture ABI name (e.g. x86, armeabi, etc...)
# -----------------------------------------------------------------------------
function BUILD_ANDROID_ARCH
{
	local ABI=$1
	local TMP_PATH="${TOP}/android/${ABI}"
	local SRC_PATH="${TMP_PATH}/src"
	local BUILD_LOG="${TMP_PATH}/Build.log"
	
	local BUILD_TARGET=$(BUILD_ANDROID_TARGET $ABI)
	
	LOG_LINE
	LOG "Building  $ABI  (target: $BUILD_TARGET)"
	LOG "Build log:  ${BUILD_LOG}"
	
	DEBUG_LOG "Extracting sources to: $SRC_PATH"
	[[ -d "$TMP_PATH" ]] && $RM -rf "$TMP_PATH"
	$MD "$TMP_PATH"
	tar -xf ${OPENSSL_ARCHIVE_LOCAL_PATH} -C $TMP_PATH
	$MV "$TMP_PATH/openssl-$OPENSSL_VERSION" "$SRC_PATH"
	
	PUSH_DIR $SRC_PATH
	# ----
	
	LOG "Configuring library..."
	
	echo "### Configure" > ${BUILD_LOG}
	./Configure \
		${BUILD_TARGET} \
		-D__ANDROID_API__=${ANDROID_API_LEVEL} \
		${OPENSSL_CONF_PARAMS} \
		>> ${BUILD_LOG} 2>&1
	
	LOG "Building library..."
	
	echo "### make" >> ${BUILD_LOG}
	set +e
	make -j$BUILD_JOBS_COUNT >> ${BUILD_LOG} 2>&1	
	set -e
	
	if [ ! -f "libcrypto.a" ]; then
		LOG_LINE
		tail -20 ${BUILD_LOG}
		FAILURE "Build did not produce final library"
	fi
	
	LOG "Installing headers..."
	
	echo "### make install" >> ${BUILD_LOG}
	make DESTDIR=out install_sw -j$BUILD_JOBS_COUNT >> ${BUILD_LOG} 2>&1
	
	# Copy all headers only for armeabi-v7a architecture
	if [ $ABI == "armeabi-v7a" ]; then
		$CP -r "$SRC_PATH/out/usr/local/include/openssl" "${OPENSSL_DEST_ANDROID}/include" 
	fi
	# Copy ABI specific opensslconf into unique header.
	local ABI_CONF_HEADER="${OPENSSL_DEST_ANDROID}/include/openssl/opensslconf_${ABI}.h"
	$CP "$SRC_PATH/out/usr/local/include/openssl/opensslconf.h" "${ABI_CONF_HEADER}"
	# Keep that header for later processing
	ANDROID_CONF_ALL+=("${ABI_CONF_HEADER}")
	
	# ----
	POP_DIR
		
	DEBUG_LOG "Copying library to destination folder..."
	
	local ABI_DEST="${OPENSSL_DEST_ANDROID}/lib/${ABI}"
	[[ -d "$ABI_DEST" ]] && $RM -rf "$ABI_DEST"
	$MD "${ABI_DEST}"
	$CP "$SRC_PATH/libcrypto.a" "${ABI_DEST}"
}

# -----------------------------------------------------------------------------
# BUILD_ANDROID_TOOLCHAIN_PATH prints path to NDK toolchain folder to stdout.
#
# Parameters:
#   $1   - NDK home path
# -----------------------------------------------------------------------------
function BUILD_ANDROID_TOOLCHAIN_PATH
{
	local NDK_DIR=$1
	local HOST_INFO=`uname -a`
	local HOST_PLATFORM=""
	case ${HOST_INFO} in
		Darwin*)
			HOST_PLATFORM="darwin-x86_64"
			;;
		Linux*)
    		HOST_PLATFORM="linux-x86_64"
			;;
		*)
			FAILURE "Unable to determine toolchain for current operating system."
			;;
	esac
	echo "$NDK_DIR/toolchains/llvm/prebuilt/${HOST_PLATFORM}/bin"
}

# -----------------------------------------------------------------------------
# BUILD_ANDROID_TARGET translates ABI architecture to OpenSSL target
#
# Parameters:
#   $1   - ABI architecture
# -----------------------------------------------------------------------------
function BUILD_ANDROID_TARGET
{
	case $1 in
		armeabi-v7a)
			echo "android-arm -march=armv7-a"
			;;
		arm64-v8a)
			echo "android-arm64"
			;;
		x86)
			echo "android-x86"
			;;
		x86_64)
			echo "android-x86_64"
			;;
		*)
			FAILURE "Unable to determine target for architecture $1"
	esac
}

# -----------------------------------------------------------------------------
# BUILD_ANDROID_PLATFORM_SWITCH makes #if-def switch to platform specific 
# config includes.
#
# Parameters:
#   $1   - path to destination "include" folder
#
# Global variables:
#  $ANDROID_CONF_ALL - array with paths to platform & architecture specific
#                      config headers. The array contains full paths 
#                      to include files.
# -----------------------------------------------------------------------------
function BUILD_ANDROID_PLATFORM_SWITCH
{
	local INCLUDE="$1"
	
	LOG_LINE
	LOG "Preparing platform switch to opensslconf.h..."
	
	if [ ${#ANDROID_CONF_ALL[@]} -eq 0 ]; then
		FAILURE "No architecture has been produced (e.g. \$ANDROID_CONF_ALL array is empty)"
	fi
		
	# Copy template file into the final configuration file
	local DEST_PATH="${INCLUDE}/openssl"
	local DEST_CONF="${DEST_PATH}/opensslconf.h"
	$CP "${TOP}/assets/android/opensslconf-template.h" "${DEST_CONF}"
	printf "\n\n" >> "${DEST_CONF}"
	
	# Iterate over all collected platform specific header files
	local LOOPCOUNT=0
	local IF_CONDITION=0
	for PLATFORM_CONF_PATH in "${ANDROID_CONF_ALL[@]}" ; do
		# Determine define condition
		local PLATFORM_CONF=$(basename $PLATFORM_CONF_PATH)
	    case "${PLATFORM_CONF}" in
			*_armeabi-v7a.h)
				IF_CONDITION="defined(__ARM_ARCH) && __ARM_ARCH == 7" ;;
			*_arm64-v8a.h)
				IF_CONDITION="defined(__ARM_ARCH) && __ARM_ARCH == 8" ;;
			*_x86.h)
				IF_CONDITION="defined(__i386__)" ;;
			*_x86_64.h)
				IF_CONDITION="defined(__x86_64__)" ;;
			*)
				FAILURE "Unexpected platform config header: $PLATFORM_CONF"
				;;
	    esac

		# Determine loopcount; start with if and continue with elif
		LOOPCOUNT=$((LOOPCOUNT + 1))
		if [ ${LOOPCOUNT} -eq 1 ]; then
			echo "#if ${IF_CONDITION}" 								>> "${DEST_CONF}"
		else
			echo "#elif ${IF_CONDITION}"	 						>> "${DEST_CONF}"
		fi
		
		# Add include
		echo "#   include <openssl/${PLATFORM_CONF}>"				>> "${DEST_CONF}"
	done
	
    # Close #if-elif chain
    echo "#else" 													>> "${DEST_CONF}"
    echo "#   error Unable to determine platform in OpenSSL build"	>> "${DEST_CONF}"
    echo "#endif" 													>> "${DEST_CONF}"
}