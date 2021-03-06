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
# Include common functions...
# -----------------------------------------------------------------------------
TOP=$(dirname $0)
source "${TOP}/common-functions.sh"
source "${TOP}/utils.sh"
source "${TOP}/config.sh"
source "${TOP}/config-build.sh"

# Variables loaded from command line

DO_APPLE=0
DO_ANDROID=0
DO_PUBLISH=0
DO_PUBLISH_VER=
DO_UPLOAD=0
GITHUB_ACCESS=

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
    echo "Command precompiles and publish OpenSSL for cc7 library purposes."
    echo ""
    echo "platform                can be  'apple', 'android' or 'all'"
    echo ""
    echo "options are:"
    echo ""
    echo "  --publish version     If used, then the build also create a new"
    echo "                        version tag and publish this build to github."
    echo ""
    echo "  --local version       Similar to '--publish', but makes only local"
    echo "                        changes, without publishing to github."
    echo ""
    echo "  --github-access user:token"
    echo "                        Set user with token to access github. If not"
    echo "                        provided, then script will use lime-credentials"
    echo "                        file to acquire credentials. Note that token"
    echo "                        must have following scopes: 'public_repo',"
    echo "                        'repo:status' and 'repo_deployment'"
    echo ""
    echo "  -v0                   turn off all prints to stdout"
    echo "  -v1                   print only basic log about execution progress"
    echo "  -v2                   print full build log with rich debug info"
    echo "  -h | --help           print this help information"
    echo ""
    exit $1
}

###############################################################################
# Script's main execution starts here...
# -----------------------------------------------------------------------------

case "$TOP" in
    *\ *)
        # Yes, this is lame, but better exit now than publish broken builds
        FAILURE "Current path contains space character. This script has not been tested for such case."
        ;;
esac

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
        --publish)
            DO_PUBLISH=1
            DO_UPLOAD=1
            VALIDATE_AND_SET_VERSION_STRING $2
            DO_PUBLISH_VER=$VERSION
            shift
            ;;
        --local)
            DO_PUBLISH=1
            DO_UPLOAD=0
            VALIDATE_AND_SET_VERSION_STRING $2
            DO_PUBLISH_VER=$VERSION
            shift
            ;;
        --github-access)
            GITHUB_ACCESS=$2
            shift
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

# Validate input parameters

if [ $DO_APPLE$DO_ANDROID == 00 ]; then
    FAILURE "You have to specify platform to build."
fi

REQUIRE_COMMAND shasum

# Dump debug configuration (use -v2 switch to show it in log)

DEBUG_LOG "Build configuration:"
DEBUG_LOG " - OpenSSL    : $OPENSSL_VERSION"
case $DO_APPLE$DO_ANDROID in
    01) DEBUG_LOG " - Platforms  : Android" ;;
    10) DEBUG_LOG " - Platforms  : Apple" ;;
    11) DEBUG_LOG " - Platforms  : Apple + Android" ;;
esac
if [ x$DO_PUBLISH = x1 ]; then
    CC7_VERSION=${DO_PUBLISH_VER}
    DEBUG_LOG " - Publish    : YES, upload for cc7 $CC7_VERSION"
else
    DEBUG_LOG " - Publish    : NO"
fi

# Include scripts

source "${TOP}/build-download.sh"
[[ x${DO_PUBLISH} == x1 ]] && source "${TOP}/build-publish.sh"
[[ x${DO_APPLE}   == x1 ]] && source "${TOP}/build-apple.sh"
[[ x${DO_ANDROID} == x1 ]] && source "${TOP}/build-android.sh"

# Execute build

[[ x${DO_PUBLISH} == x1 ]] && PUBLISH_VALIDATE_VERSION ${DO_PUBLISH_VER} ${DO_UPLOAD}

GET_OPENSSL_ARCHIVE

[[ x${DO_ANDROID} == x1 ]] && BUILD_ANDROID
[[ x${DO_APPLE}   == x1 ]] && BUILD_APPLE

LOG_LINE

[[ x${DO_ANDROID} == x1 ]] && [[ x${DO_PUBLISH} == x1 ]] && PUBLISH_SAVE_ARTIFACT "${OPENSSL_DEST_ANDROID_PATH}"
[[ x${DO_APPLE}   == x1 ]] && [[ x${DO_PUBLISH} == x1 ]] && PUBLISH_SAVE_ARTIFACT "${OPENSSL_DEST_APPLE_PATH}"
[[ x${DO_APPLE}   == x1 ]] && [[ x${DO_PUBLISH} == x1 ]] && PUBLISH_SAVE_ARTIFACT "${OPENSSL_DEST_APPLE_XCFW_PATH}"
[[ x${DO_PUBLISH} == x1 ]] && PUBLISH_COMMIT_CHANGES ${DO_UPLOAD}

EXIT_SUCCESS
