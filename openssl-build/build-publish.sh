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

if [ -z "$OPENSSL_VERSION" ]; then
    echo "Do not use this script directly. Use 'build.sh' instead."
    exit 1
fi

source "${TOP}/github-client.sh"

REQUIRE_COMMAND git

# -----------------------------------------------------------------------------
# PUBLISH_VALIDATE_VERSION validates whether we're at right branch and version
# is not published yet. Function also loads github access credentials
# and initialize github-client.sh.
#
# Parameters:
#   $1   - Version to validate
#   $2   - 0 / 1 whether version will be published to github
# -----------------------------------------------------------------------------
function PUBLISH_VALIDATE_VERSION
{
    local ver="$1"
    local upload="$2"

    if [ x$upload == x0 ]; then
        LOG "Skipping release version validation..."
        return
    fi

    PUSH_DIR "${OPENSSL_DEST}"
    
    LOG "Validating release version..."
    
    local GIT_CURRENT_BRANCH=`git rev-parse --abbrev-ref HEAD`
    if [ "$GIT_CURRENT_BRANCH" != "$CC7_BRANCH" ]; then
        FAILURE "You have to be at '${CC7_BRANCH}' git branch."
    fi
    
    git fetch origin
    
    local CURRENT_TAGS=(`git tag -l`)
    local TAG   
    for TAG in ${CURRENT_TAGS[@]}; do
        if [ "$TAG" == ${ver} ]; then 
            FAILURE "Version '${ver}' is already published."
        fi 
    done

    POP_DIR
    
    # Load credentials
    if [ -z "$GITHUB_ACCESS" ]; then
        LOAD_API_CREDENTIALS
        [[ -z "$GITHUB_RELEASE_ACCESS" ]] && FAILURE "Missing \$GITHUB_RELEASE_ACCESS variable in .lime-credentials file."
        GITHUB_ACCESS="$GITHUB_RELEASE_ACCESS"
        DEBUG_LOG "Using github credentials from .lime-credentials file."
    else
        DEBUG_LOG "Using github credentials from command line."
    fi
    
    # Split credentials into user & token
    local ACCESS=(${GITHUB_ACCESS//:/ })
    local USER=${ACCESS[0]}
    local TOKEN=${ACCESS[1]}
    [[ -z "$USER" ]] && FAILURE "Missing user in github access."
    [[ -z "$TOKEN" ]] && FAILURE "Missing access token in github access."
    
    GITHUB_INIT 'wultra' 'cc7' ${USER} ${TOKEN}
}

# -----------------------------------------------------------------------------
# PUBLISH_COMMIT_CHANGES displays info about release publishing
#
# Parameters:
#   $1   - 0 / 1 whether version will be published to github
# -----------------------------------------------------------------------------
function PUBLISH_COMMIT_CHANGES
{
    local upload="$1"
    
    LOG_LINE
    LOG "Publishing OpenSSL ${OPENSSL_VERSION} for cc7 release ${CC7_VERSION}."
    LOG_LINE
    
    LOG "Saving all generated files..."
    
    SAVE_FETCH_CONFIG
    SAVE_VERSION_FILE
    
    if [ x$upload == x0 ]; then
        LOG_LINE
        LOG "Skipping publishing to github, as requested."
        LOG "Now you can investigate all local changes."
        return
    fi
    
    PUSH_DIR "${TOP}/.."
    
    LOG "Commiting all chages..."
    
    git add 'Package.swift'
    git add 'openssl-build/config-fetch.sh'
    git add 'openssl-build/version.sh'
    git commit -m "Deployment: Update release files to ${CC7_VERSION}"
    
    LOG "Creating tag for version..."
    
    git tag -a ${CC7_VERSION} -m "Version ${CC7_VERSION}"
    
    LOG "Pushing all changes..."

    git push --follow-tag
    
    POP_DIR
    
    LOG "Creating release at github..."

    local rel_json="$GHC_TMP/rel.json"
    
    GITHUB_CREATE_RELEASE "${CC7_VERSION}" "${CC7_VERSION}" '- TBA' false false "$rel_json"
    
    PUBLISH_UPLOAD_ARTIFACT "$rel_json" "${OPENSSL_DEST_ANDROID_PATH}"
    PUBLISH_UPLOAD_ARTIFACT "$rel_json" "${OPENSSL_DEST_APPLE_PATH}"
    PUBLISH_UPLOAD_ARTIFACT "$rel_json" "${OPENSSL_DEST_APPLE_XCFW_PATH}"
    
    GITHUB_DEINIT
    
    LOG_LINE
    LOG "Now you can edit release notes at  : ${CC7_RELEASE_URL}/${CC7_VERSION}"
}

# -----------------------------------------------------------------------------
# PUBLISH_UPLOAD_ARTIFACT uploads artifact into github release 
# 
# Parameters:
#   $1   - release JSON file
#   $2   - artifact to upload
# -----------------------------------------------------------------------------
function PUBLISH_UPLOAD_ARTIFACT
{
    local rel_json="$1"
    local artifact="$2"
    local artifact_name=$(basename $artifact)
    local mime_type=
    case $artifact in
        *zip) mime_type='application/zip' ;;
        *tar.gz) mime_type='application/gzip' ;;
        *) FAILURE "Unknown artifact file extension: $artifact" ;;
    esac
    
    LOG "Uploading $artifact_name ..."
    
    GITHUB_UPLOAD_RELEASE_ASSET "$rel_json" "$artifact" "$artifact_name" "$mime_type"
}

# -----------------------------------------------------------------------------
# PUBLISH_SAVE_ARTIFACT saves just created artifact into config-fetch.sh 
# 
# Parameters:
#   $1   - precompiled artifact to save
# -----------------------------------------------------------------------------
function PUBLISH_SAVE_ARTIFACT
{
    local archive="$1"
    local info_path=
    local platform=
    local hash=
    local BASE_URL="${CC7_RELEASE_URL}/download"
    
    case "$archive" in
        *-apple.tar.gz) 
            info_path="${OPENSSL_DEST_APPLE_INFO}"
            platform="Apple"
            ;;
        *.xcframework.zip) 
            info_path="${OPENSSL_DEST_APPLE_XCFW_INFO}"
            platform="Apple-XCFW"
            # Also copy prebuilt Package.swift to "{GIT_ROOT}/Package.swift"
            $CP "${OPENSSL_DEST_APPLE_XCFW_PACKAGE}" "${TOP}/../Package.swift"
            ;;
        *-android.tar.gz)
            info_path="${OPENSSL_DEST_ANDROID_INFO}"
            platform="Android"
            ;;
        *) 
            FAILURE "Unable to determine platform from the precompiled archive: $archive"
            ;;
    esac
    
    LOG "Publishing OpenSSL ${OPENSSL_VERSION} for ${platform} platform..."
    
    if [ ! -f "${archive}" ]; then
        FAILURE "Missing archive file for ${platform} platform: ${archive}"
    fi

    # Load fetch config & package info file
    
    LOAD_FETCH_CONFIG
    LOAD_ARCHIVE_INFO_FILE required "${info_path}"
    
    hash=${OPENSSL_PREBUILD_HASH}
    if [ $platform == 'Apple' ]; then
        OPENSSL_FETCH_APPLE_URL="${BASE_URL}/${CC7_VERSION}/${OPENSSL_DEST_APPLE_FILE}"
        OPENSSL_FETCH_APPLE_HASH=$hash
    elif [ $platform == 'Apple-XCFW' ]; then
        OPENSSL_FETCH_APPLE_XCFW_URL="${BASE_URL}/${CC7_VERSION}/${OPENSSL_DEST_APPLE_XCFW_FILE}"
        OPENSSL_FETCH_APPLE_XCFW_HASH=$hash
    else
        OPENSSL_FETCH_ANDROID_URL="${BASE_URL}/${CC7_VERSION}/${OPENSSL_DEST_ANDROID_FILE}"
        OPENSSL_FETCH_ANDROID_HASH=$hash
    fi

    LOG "  - Precompiled archive : ${archive}"
    LOG "  - Info path           : ${info_path}"
    LOG "  - Hash                : ${hash}"
}

# -----------------------------------------------------------------------------
# LOAD_FETCH_CONFIG loads config-fetch.sh into OPENSSL_FETCH* variables.
# -----------------------------------------------------------------------------
function LOAD_FETCH_CONFIG
{   
    DEBUG_LOG "Loading config-fetch.sh ..."
    
    if [ ! -z $OPENSSL_FETCH_VERSION ] && [ "$OPENSSL_FETCH_VERSION" == "${OPENSSL_VERSION}" ]; then
        DEBUG_LOG "File config-fetch.sh is already loaded."
        return 0
    fi
    
    if [ -f "${TOP}/config-fetch.sh" ]; then
        source "${TOP}/config-fetch.sh" 
        if [ -z $OPENSSL_FETCH_VERSION ] || [ "$OPENSSL_FETCH_VERSION" != "${OPENSSL_VERSION}" ]; then
            DEFAULT_FETCH_CONFIG
        fi
    else
        DEFAULT_FETCH_CONFIG
    fi
}

# -----------------------------------------------------------------------------
# SAVE_FETCH_CONFIG saves OPENSSL_FETCH* variables to config-fetch.sh
# -----------------------------------------------------------------------------
function SAVE_FETCH_CONFIG
{
    DEBUG_LOG "Saving config-fetch.sh ..."
    
    if [ -z $OPENSSL_FETCH_VERSION ] || [ "$OPENSSL_FETCH_VERSION" != "${OPENSSL_VERSION}" ]; then
        DEFAULT_FETCH_CONFIG
    fi
    
    local dst_config="${TOP}/config-fetch.sh"
    cat > ${dst_config} <<EOF
# ------------------------------------------------------- #
#      Please do not modify this autogenerated file.      #
#  Use  >> build.sh --publish <<  to update its content.  #
# ------------------------------------------------------- #

OPENSSL_FETCH_VERSION='${OPENSSL_FETCH_VERSION}'
OPENSSL_FETCH_ANDROID_URL='${OPENSSL_FETCH_ANDROID_URL}'
OPENSSL_FETCH_ANDROID_HASH='${OPENSSL_FETCH_ANDROID_HASH}'
OPENSSL_FETCH_APPLE_URL='${OPENSSL_FETCH_APPLE_URL}'
OPENSSL_FETCH_APPLE_HASH='${OPENSSL_FETCH_APPLE_HASH}'
OPENSSL_FETCH_APPLE_XCFW_URL='${OPENSSL_FETCH_APPLE_XCFW_URL}'
OPENSSL_FETCH_APPLE_XCFW_HASH='${OPENSSL_FETCH_APPLE_XCFW_HASH}'
EOF
}

# -----------------------------------------------------------------------------
# DEFAULT_FETCH_CONFIG sets default values OPENSSL_FETCH* variables.
# -----------------------------------------------------------------------------
function DEFAULT_FETCH_CONFIG
{
    DEBUG_LOG "Setting default values for config-fetch.sh ..."
    
    local BASE_URL="${CC7_RELEASE_URL}/download"
    OPENSSL_FETCH_VERSION="${OPENSSL_VERSION}"
    OPENSSL_FETCH_ANDROID_URL="${BASE_URL}/${CC7_VERSION}/${OPENSSL_DEST_ANDROID_FILE}"
    OPENSSL_FETCH_ANDROID_HASH=''
    OPENSSL_FETCH_APPLE_URL="${BASE_URL}/${CC7_VERSION}/${OPENSSL_DEST_APPLE_FILE}"
    OPENSSL_FETCH_APPLE_HASH=''
    OPENSSL_FETCH_APPLE_XCFW_URL="${BASE_URL}/${CC7_VERSION}/${OPENSSL_DEST_APPLE_XCFW_FILE}"
    OPENSSL_FETCH_APPLE_XCFW_HASH=''
}

# -----------------------------------------------------------------------------
# SAVE_VERSION_FILE saves CC7_VERSION version to version.sh file
# -----------------------------------------------------------------------------
function SAVE_VERSION_FILE
{
    cat > "${TOP}/version.sh" <<EOF
# ------------------------------------------------------- #
#      Please do not modify this autogenerated file.      #
#  Use  >> build.sh --publish << to update its content.   #
# ------------------------------------------------------- #
    
CC7_VERSION_EXT='${CC7_VERSION}'
EOF
}