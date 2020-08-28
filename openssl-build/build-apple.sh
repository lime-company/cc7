#!/bin/bash
# -----------------------------------------------------------------------------
# Copyright 2020 Wultra s.r.o.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

###############################################################################

if [ x$OPENSSL_VERSION == 'x' ]; then
	echo "Do not use this script explicitly. Use 'build.sh' instead."
	exit 1
fi

REQUIRE_COMMAND xcodebuild
REQUIRE_COMMAND xcrun
REQUIRE_COMMAND lipo
REQUIRE_COMMAND libtool
REQUIRE_COMMAND sed
REQUIRE_COMMAND jq			# brew install jq
REQUIRE_COMMAND plutil

# -----------------------------------------------------------------------------
# BUILD_APPLE builds all supported Apple platforms.
# -----------------------------------------------------------------------------
function BUILD_APPLE
{
	local TMP_PATH="${TOP}/tmp/apple"
	local BUILD_LOG=$TMP_PATH/Build.log
	local LIB_NAME="openssl"
	
	LOG_LINE
	LOG "Building OpenSSL ${OPENSSL_VERSION} for Apple platforms..."
	
	DEBUG_LOG "Destination folders cleanup"
	
	[[ -d "${OPENSSL_DEST_APPLE}" ]] && $RM -rf "${OPENSSL_DEST_APPLE}"
	[[ -f "${OPENSSL_DEST_APPLE_PATH}" ]] && $RM "${OPENSSL_DEST_APPLE_PATH}"
	$MD "${OPENSSL_DEST_APPLE}"
		
	# Set reference to custom configuration. This lets the openssl build system know that
	# we have our own configurations.
	export OPENSSL_LOCAL_CONFIG_DIR="${TOP}/config"
	
	# Build all targets
	APPLE_CONF_ALL=()		# All configuration headers
	for TARGET in ${APPLE_TARGETS}
	do
		#APPLE_CONF_ALL+=("${TMP_PATH}/${TARGET}/openssl.tmp/include/openssl/opensslconf_${TARGET}.h")
		BUILD_APPLE_TARGET ${TARGET} ${LIB_NAME} "${TMP_PATH}"
	done
	
	# Build FAT frameworks per platform
	LOG_LINE
	APPLE_FW_ALL=()			# All intermediate frameworks
	for PLATFORM in ${APPLE_PLATFORMS}
	do
		BUILD_APPLE_FAT_FRAMEWORK ${PLATFORM} ${LIB_NAME} "${TMP_PATH}"
	done
	# We still have to support a FAT static library for older mobile SDKs
	[[ x$APPLE_LEGACY_LIB == x1 ]] && BUILD_APPLE_STATIC_LIB ${LIB_NAME} "${TMP_PATH}" "${BUILD_LOG}" libcrypto.a
	# Build final XCFramework
	BUILD_APPLE_XC_FRAMEWORK ${LIB_NAME} "${TMP_PATH}" "${BUILD_LOG}"

	LOG "Making Apple archive..."
	
	DEBUG_LOG "Archive path: ${OPENSSL_DEST_APPLE_PATH}"
	
	PUSH_DIR "${OPENSSL_DEST}"
	# ----
	export GZIP='-9'
	echo "### tar package" > ${BUILD_LOG}
	tar -zcvf ${OPENSSL_DEST_APPLE_FILE} apple >> ${BUILD_LOG} 2>&1
	SAVE_ARCHIVE_INFO_FILE "${OPENSSL_DEST_APPLE_FILE}"
	# ----
	POP_DIR 
	
	LOG "Final cleanup..."
	
	unset OPENSSL_LOCAL_CONFIG_DIR
	$RM -rf "${TMP_PATH}"	
}

# -----------------------------------------------------------------------------
# BUILD_APPLE_TARGET builds OpenSSL for all possible architectures.
#
# Parameters:
#   $1   - architecture to build in form of target conf (e.g. ios-cross-armv7)
#   $2   - output library name (e.g. openssl)
#   $3   - path to temporary folder
# -----------------------------------------------------------------------------
function BUILD_APPLE_TARGET
{
	local TARGET=$1
	local OUT_NAME="$2"
	local TMP_PATH="$3/$TARGET"
		
	local ARCH=$(BUILD_APPLE_ARCH_NAME ${TARGET})
	local SDK=$(BUILD_APPLE_SDK_NAME ${TARGET})
	local SDK_NAME=$(BUILD_APPLE_FAT_NAME ${TARGET})
	local MIN_OS_VERSION=$(BUILD_APPLE_SDK_MIN_VERSION ${SDK_NAME})
	local SRC_PATH="$TMP_PATH/src"
	local OUT_PATH="$TMP_PATH/${OUT_NAME}.tmp"
	local BUILD_LOG="$TMP_PATH/Build.log"
	
	LOG_LINE
	LOG "Building $SDK_NAME ($MIN_OS_VERSION+) ~ $ARCH"
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
	
	export CONFIG_DISABLE_BITCODE='true'
	export CROSS_SYSROOT=`xcrun -sdk $SDK --show-sdk-path`
	export CROSS_MIN_VERSION=$MIN_OS_VERSION
	export SDKVERSION=`xcrun -sdk $SDK --show-sdk-version`
	
	set +e
	./Configure \
		${TARGET} \
		${OPENSSL_CONF_PARAMS} \
		>> ${BUILD_LOG} 2>&1
	
	if [ $? -ne 0 ]; then
		tail -20 ${BUILD_LOG}
		LOG_LINE
		FAILURE "Configure script did fail"
	fi
	
	LOG "Building library..."
	
	echo "### make" >> ${BUILD_LOG}
	
	make -j$BUILD_JOBS_COUNT >> ${BUILD_LOG} 2>&1	
	set -e
	
	if [ ! -f "libcrypto.a" ]; then
		tail -20 ${BUILD_LOG}
		LOG_LINE
		FAILURE "Build did not produce final library"
	fi
	
	LOG "Installing headers..."
	
	echo "### make install" >> ${BUILD_LOG}
	make DESTDIR=out install_sw -j$BUILD_JOBS_COUNT >> ${BUILD_LOG} 2>&1
	
	# ----
	POP_DIR
	
	# Copy all headers only for armeabi-v7a architecture
	$MD "${OUT_PATH}"
	$MD "${OUT_PATH}/include"
	$CP -r "$SRC_PATH/out/usr/local/include/openssl" "${OUT_PATH}/include"
	
	# Copy ABI specific opensslconf into unique header.
	local TARGET_CONF_HEADER="${OUT_PATH}/include/openssl/opensslconf_${TARGET}.h"
	$CP "${OUT_PATH}/include/openssl/opensslconf.h" "${TARGET_CONF_HEADER}"
	# Keep that header for later processing
	APPLE_CONF_ALL+=("${TARGET_CONF_HEADER}")
	
	# Make library
	DEBUG_LOG "Copying library to temporary folder..."
	echo "### libtool" >> ${BUILD_LOG}
	libtool -static -no_warning_for_no_symbols -o "${OUT_PATH}/${OUT_NAME}.a" "$SRC_PATH/libcrypto.a" \
		>> ${BUILD_LOG} 2>&1
}

# -----------------------------------------------------------------------------
# BUILD_APPLE_FAT_FRAMEWORK builds FAT OpenSSL framework for given platform
#
# Parameters:
#   $1   - platform to build (e.g. iOS, iOS_Simulator, etc...)
#   $2   - output library name (e.g. openssl)
#   $3   - path to temporary folder
# -----------------------------------------------------------------------------
function BUILD_APPLE_FAT_FRAMEWORK
{
	local PLATFORM=$1
	local OUT_NAME="$2"
	local TMP_PATH="$3"
	local OUT_PATH="${TMP_PATH}/$PLATFORM/${OUT_NAME}.framework"
	local MIN_OS_VERSION=$(BUILD_APPLE_SDK_MIN_VERSION $PLATFORM)
	
	LOG "Building intermediate $PLATFORM ($MIN_OS_VERSION+) FAT framework..."
	
	[[ -d "$OUT_PATH" ]] && $RM -rf "$OUT_PATH"
	$MD "${OUT_PATH}"
	
	# Collect all libs for given platform.
	local LIBS=()
	local COPY_HEADERS=1
	for TARGET in ${APPLE_TARGETS};	do
		if [ $(BUILD_APPLE_FAT_NAME $TARGET) == $PLATFORM ]; then
			LIBS+=("$TMP_PATH/$TARGET/openssl.tmp/${OUT_NAME}.a")
			if [ x$COPY_HEADERS == x1 ]; then
				COPY_HEADERS=0
				DEBUG_LOG "Installing headers for FAT framework..."
				$CP -r "$TMP_PATH/$TARGET/openssl.tmp/include/openssl" "$OUT_PATH"
				$MV "$OUT_PATH/openssl" "$OUT_PATH/Headers"
				BUILD_APPLE_PLATFORM_SWITCH "$OUT_PATH/Headers"
			fi
		fi
	done
	
	if [[ x$COPY_HEADERS == x1 ]]; then
		# Looks like we didn't build any lib for such platform. 
		# Check config-build.sh or BUILD_APPLE_*_NAME functions whether match together.
		FAILURE "Platform $PLATFORM has no precompiled library available."
	fi
	
    # Make FAT library. Don't lipo a single file
    if [[ ${#LIBS[@]} -gt 1 ]]; then
        lipo -create ${LIBS[@]} -output "$OUT_PATH/$OUT_NAME"
    else
        $CP ${LIBS[0]} "$OUT_PATH/$OUT_NAME"
    fi
	if otool -l "$OUT_PATH/$OUT_NAME" | grep __bitcode >/dev/null; then
		LOG "  + library contains Bitcode"
	fi
	
	# Make proper Info.plist
	sed -e "s/%MIN_OS_VERSION%/$MIN_OS_VERSION/g" "${TOP}/assets/apple/Info-template.plist" > "$OUT_PATH/Info.plist"
	
	# Keep final framework in the list
	APPLE_FW_ALL+=("${OUT_PATH}")
}

# -----------------------------------------------------------------------------
# BUILD_APPLE_XC_FRAMEWORK builds final XCFramework and prepares helper script
# for Xcode build. The helper script is responsible for copying platform
# specific framework from the final XCFramework.
#
# Parameters:
#   $1   - library name (e.g. openssl)
#   $2   - path to temporary folder
#   $3   - path to top-level build log
# -----------------------------------------------------------------------------
function BUILD_APPLE_XC_FRAMEWORK
{
	local LIB_NAME="$1"
	local TMP_PATH="$2"
	local BUILD_LOG="$3"
	local FW_PATH="${OPENSSL_DEST_APPLE}/${LIB_NAME}.xcframework"
	local JSON_INFO="${OPENSSL_DEST_APPLE}/Info.json"
	local FILT_INFO="${OPENSSL_DEST_APPLE}/Info-filtered.json"
	local DST_HEADERS="${OPENSSL_DEST_APPLE}/include"
	local SRC_HEADERS=
	
	LOG "Creating final ${LIB_NAME}.xcframework..."
    
	local XCFW_ARGS=
    for ARG in ${APPLE_FW_ALL[@]}; do
        XCFW_ARGS+="-framework ${ARG} "
    done
	$MD "${OPENSSL_DEST_APPLE}"
    xcodebuild -create-xcframework $XCFW_ARGS -output "${FW_PATH}" >> ${BUILD_LOG} 2>&1
	
	LOG "Preparing Xcode build helper script..."
	
	local PLOPT=
	[[ $VERBOSE -gt 1 ]] && PLOPT='-r'
	plutil -convert json ${PLOPT} -o "${JSON_INFO}" "${FW_PATH}/Info.plist"
	
	local XCFW_TAG=`jq .CFBundlePackageType ${JSON_INFO}`
	local XCFW_VERSION=`jq .XCFrameworkFormatVersion ${JSON_INFO}`
	if [ ${XCFW_TAG} != "\"XFWK\"" ]; then
		FAILURE "Unknown xcframework format '${XCFW_TAG}': $FW_PATH"
	fi
	if [ ${XCFW_VERSION} != "\"1.0\"" ]; then
		WARNING "Unknown xcframework version '${XCFW_VERSION}': $FW_PATH"
	fi
	
	# Prepare filtered plist, with just minimum information required for processing.
	jq '.AvailableLibraries[] | [ "\(.LibraryIdentifier) \(.SupportedPlatform)\(.SupportedPlatformVariant)" ] | add' ${JSON_INFO} > ${FILT_INFO}
	
	local HELPER="${OPENSSL_DEST_APPLE_HELP}"
	echo '# --------------------------------------------------------'	>  $HELPER
	echo '# Do not edit. Autogenerated by build.sh script.'				>> $HELPER
	echo '# --------------------------------------------------------'	>> $HELPER
	echo 'function TRANSLATE_BUILD_SUFFIX {'							>> $HELPER
	echo '  case $1 in'													>> $HELPER

	for PLATFORM in ${APPLE_PLATFORMS}
	do
		case $PLATFORM in
			iOS)
				local SELECTOR='iosnull'
				local BUILD_SUFFIX='-iphoneos'
				;;
			iOS_Simulator)
				local SELECTOR='iossimulator'
				local BUILD_SUFFIX='-iphonesimulator'
				;;
			tvOS)
				local SELECTOR='tvosnull'
				local BUILD_SUFFIX='-appletvos'
				;;
			tvOS_Simulator)
				local SELECTOR='tvossimulator'
				local BUILD_SUFFIX='-appletvsimulator'
				;;
			macOS_Catalyst)
				local SELECTOR='iosmaccatalyst'
				local BUILD_SUFFIX='-maccatalyst'
				;;
			*)
				FAILURE "Platform '$PLATFORM' is not supported in Xcode build helper script."
				;;
		esac
		local TMP=(`grep $SELECTOR "${FILT_INFO}"`)
		local LIB_IDENTIFIER=${TMP[0]#\"}
		echo "    $BUILD_SUFFIX)" 										>> $HELPER
		echo "      echo \"$LIB_IDENTIFIER\" ;;"						>> $HELPER
		[[ $PLATFORM == "iOS" ]] && SRC_HEADERS="${FW_PATH}/$LIB_IDENTIFIER/openssl.framework"
	done
	# Close 'case' & 'function'
	echo '    *)'														>> $HELPER
	echo '      FAILURE "Unknown build suffix: $1" ;;'					>> $HELPER
	echo '  esac'														>> $HELPER
	echo '}'															>> $HELPER
	
	LOG "Copying headers from 'iOS' platform framework..."
	
	[[ -z "${SRC_HEADERS}" ]] && FAILURE "Failed to acquire path to iOS platform headers."
	
	$MD "${DST_HEADERS}"
	$CP -r "${SRC_HEADERS}/Headers" "${DST_HEADERS}"
	$MV "${DST_HEADERS}/Headers" "${DST_HEADERS}/openssl"
	
	# Cleanup
	$RM "${JSON_INFO}" "${FILT_INFO}"
}

# -----------------------------------------------------------------------------
# BUILD_APPLE_STATIC_LIB builds a final static FAT library that contains
# all iOS architectures (e.g. ARM & x86).
#
# Parameters:
#   $1   - static library name (e.g. openssl)
#   $2   - path to temporary folder
#   $3   - path to top-level build log
#   $4   - output static lib name (e.g. libcrypto.a)
# -----------------------------------------------------------------------------
function BUILD_APPLE_STATIC_LIB
{
	local LIB_NAME="$1"
	local TMP_PATH="$2"
	local BUILD_LOG="$3"
	local OUT_LIB="${OPENSSL_DEST_APPLE}/$4"
	
	local IOS='iOS'
	local SIM='iOS_Simulator'
	local MIN_OS_VERSION=$(BUILD_APPLE_SDK_MIN_VERSION ${IOS})
	
	LOG "Building ${IOS}+${SIM} (${MIN_OS_VERSION}+) static FAT library..."
	
	# Look for iOS and Simulator library
	local LIBS=()
	for TARGET in ${APPLE_TARGETS};	do
		local TARGET_PLATFORM=$(BUILD_APPLE_FAT_NAME $TARGET)
		if [ ${TARGET_PLATFORM} == ${IOS} ] || [ ${TARGET_PLATFORM} == ${SIM} ]; then
			LIBS+=("$TMP_PATH/$TARGET/openssl.tmp/${LIB_NAME}.a")
		fi
	done
	
	# Make FAT library from that two platforms.
    if [[ ${#LIBS[@]} -lt 2 ]]; then
        FAILURE "Failed to collect libs for ${IOS} and ${SIM} targets."
    fi
	
	lipo -create ${LIBS[@]} -output "${OUT_LIB}"

	if otool -l "${OUT_LIB}" | grep __bitcode >/dev/null; then
		LOG "  + library contains Bitcode"
	fi
}

# -----------------------------------------------------------------------------
# BUILD_APPLE_PLATFORM_SWITCH makes #if-def switch to platform specific 
# config includes.
#
# Parameters:
#   $1   - path to destination "include" folder
#
# Global variables:
#  $APPLE_CONF_ALL    - array with paths to platform & architecture specific
#                      config headers. The array contains full paths 
#                      to include files.
# -----------------------------------------------------------------------------
function BUILD_APPLE_PLATFORM_SWITCH
{
	local INCLUDE="$1"
	
	DEBUG_LOG "Preparing platform switch to opensslconf.h..."
	
	if [ ${#APPLE_CONF_ALL[@]} -eq 0 ]; then
		FAILURE "No architecture has been produced (e.g. \$APPLE_CONF_ALL array is empty)"
	fi
		
	# Copy template file into the final configuration file
	local DEST_PATH="${INCLUDE}"
	local DEST_CONF="${DEST_PATH}/opensslconf.h"
	$CP "${TOP}/assets/apple/opensslconf-template.h" "${DEST_CONF}"
	printf "\n\n" >> "${DEST_CONF}"
	
	# Iterate over all collected platform specific header files
	local LOOPCOUNT=0
	local IF_CONDITION=0
	for PLATFORM_CONF_PATH in "${APPLE_CONF_ALL[@]}" ; do

		# Copy platform specific header into destination
		$CP "${PLATFORM_CONF_PATH}" "${DEST_PATH}"
		local PLATFORM_CONF=$(basename $PLATFORM_CONF_PATH)

		# Determine define condition
	    case "${PLATFORM_CONF}" in
			*_macos64-x86_64.h)
				IF_CONDITION="TARGET_OS_OSX && TARGET_CPU_X86_64" ;;
			*_macos64-arm64.h)
				IF_CONDITION="TARGET_OS_OSX && TARGET_CPU_ARM64" ;;
			*_ios-sim-cross-x86_64.h)
				IF_CONDITION="TARGET_OS_IOS && TARGET_OS_SIMULATOR && TARGET_CPU_X86_64" ;;
			*_ios-sim-cross-i386.h)
				IF_CONDITION="TARGET_OS_IOS && TARGET_OS_SIMULATOR && TARGET_CPU_X86" ;;
			*_ios64-cross-arm64.h)
				IF_CONDITION="TARGET_OS_IOS && TARGET_OS_EMBEDDED && TARGET_CPU_ARM64 && !defined(__arm64e__)" ;;
			*_ios64-cross-arm64e.h)
				IF_CONDITION="TARGET_OS_IOS && TARGET_OS_EMBEDDED && TARGET_CPU_ARM64 && defined(__arm64e__)" ;;
			*_ios-cross-armv7s.h)
				IF_CONDITION="TARGET_OS_IOS && TARGET_OS_EMBEDDED && TARGET_CPU_ARM && defined(__ARM_ARCH_7S__)" ;;
			*_ios-cross-armv7.h)
				IF_CONDITION="TARGET_OS_IOS && TARGET_OS_EMBEDDED && TARGET_CPU_ARM && !defined(__ARM_ARCH_7S__)" ;;
			*_tvos-sim-cross-x86_64.h)
				IF_CONDITION="TARGET_OS_TV && TARGET_OS_SIMULATOR && TARGET_CPU_X86_64" ;;
			*_tvos64-cross-arm64.h)
				IF_CONDITION="TARGET_OS_TV && TARGET_OS_EMBEDDED && TARGET_CPU_ARM64" ;;
			*_watchos-cross-armv7k.h)
				IF_CONDITION="TARGET_OS_WATCHOS && TARGET_OS_EMBEDDED && TARGET_CPU_ARMV7K" ;;
			*_watchos-cross-arm64_32.h)
				IF_CONDITION="TARGET_OS_WATCHOS && TARGET_OS_EMBEDDED && TARGET_CPU_ARM64_32" ;;
			*_watchos-sim-cross-i386.h)
				IF_CONDITION="TARGET_OS_SIMULATOR && TARGET_CPU_X86 || TARGET_OS_EMBEDDED" ;;
			*_mac-catalyst-x86_64.h)
				IF_CONDITION="(TARGET_OS_MACCATALYST || (TARGET_OS_IOS && TARGET_OS_SIMULATOR)) && TARGET_CPU_X86_64" ;;
			*_mac-catalyst-arm64.h)
				IF_CONDITION="(TARGET_OS_MACCATALYST || (TARGET_OS_IOS && TARGET_OS_SIMULATOR)) && TARGET_CPU_ARM64" ;;
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

# -----------------------------------------------------------------------------
# BUILD_APPLE_SDK_NAME converts compile TARGET into SDK name. For example, for
# "ios-cross-armv7" target prints "iphoneos".
#
# Parameters:
#   $1   - target to convert (e.g. ios-cross-armv7)
# -----------------------------------------------------------------------------
function BUILD_APPLE_SDK_NAME
{
	case $1 in
		ios-cross* | ios64-cross*)	echo "iphoneos" ;;
		ios-sim*)					echo "iphonesimulator" ;;
		watchos-cross*)				echo "watchos" ;;
		watchos-sim*)				echo "watchsimulator" ;;
		tvos64-cross*)				echo "appletvos" ;;
		tvos-sim*)					echo "appletvsimulator" ;;
		macos64* | mac-catalyst*)	echo "macosx" ;;
		*)
			FAILURE "Unable to determine SDK for target $1"
			;;
	esac
}

# -----------------------------------------------------------------------------
# BUILD_APPLE_FAT_NAME converts compile TARGET into FAT library postfix name.
# The ame is in general very similar to "SDK_NAME" but makes difference between
# macOS and macCatalyst
#
# Parameters:
#   $1   - target to convert (e.g. ios-cross-armv7)
# -----------------------------------------------------------------------------
function BUILD_APPLE_FAT_NAME
{
	case $1 in
		ios-cross* | ios64-cross*)	echo "iOS" ;;
		ios-sim*)					echo "iOS_Simulator" ;;
		watchos-cross*)				echo "watchOS" ;;
		watchos-sim*)				echo "watchOS_Simulator" ;;
		tvos64-cross*)				echo "tvOS" ;;
		tvos-sim*)					echo "tvOS_Simulator" ;;
		macos64*)					echo "macOSX" ;;
		mac-catalyst*)				echo "macOS_Catalyst" ;;
		*)
			FAILURE "Unable to determine FAT library postfix for target $1"
			;;
	esac
}

# -----------------------------------------------------------------------------
# BUILD_APPLE_SDK_MIN_VERSION prints required minimum OS version for given
# build FAT name. Check config-build.sh for such version constants.
#
# Parameters:
#   $1   - FAT name to convert (e.g. iOS, iOS_Simulator, etc...)
# -----------------------------------------------------------------------------
function BUILD_APPLE_SDK_MIN_VERSION
{	
	case $1 in
		iOS | iOS_Simulator)			echo ${APPLE_IOS_MIN_SDK} ;;
		watchOS | watchOS_Simulator)	echo ${APPLE_WATCHOS_MIN_SDK} ;;
		tvOS | tvOS_Simulator)			echo ${APPLE_TVOS_MIN_SDK} ;;
		macOSX)							echo ${APPLE_OSX_MIN_SDK} ;;
		macOS_Catalyst)					echo ${APPLE_CATALYST_MIN_SDK} ;;
		*)
			FAILURE "Unable to determine MIN SDK for FAT library $1"
			;;
	esac
}

# -----------------------------------------------------------------------------
# BUILD_APPLE_ARCH_NAME converts compile TARGET into CPU architecture name. 
# For example, for "ios-cross-armv7" target prints "armv7"
#
# Parameters:
#   $1   - target to convert (e.g. ios-cross-armv7)
# -----------------------------------------------------------------------------
function BUILD_APPLE_ARCH_NAME
{
	echo "$1" | sed -E 's|^.*\-([^\-]+)$|\1|g'
}