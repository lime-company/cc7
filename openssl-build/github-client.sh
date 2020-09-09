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

if [ -z "${TOP}" ]; then
	echo "Do not use this script directly."
	exit 1
fi

###############################################################################
# Global variables, initialized in GITHUB_INIT
#
# GHC_CIN  - is path to default input file for curl
# GHC_COUT - is path to default output from last `curl` execution
# GHC_TMP  - is path to temporary folder.

GHC_CIN=
GHC_COUT=
GHC_TMP=

# Global private variables

_GHC_ORG=
_GHC_REPO=
_GHC_ORGREPO=
_GHC_SEC_USER=
_GHC_SEC_TOKEN=
_GHC_SEC=

_GHC_URL='https://api.github.com/repos'
_GHC_UPLOAD_URL='https://uploads.github.com/repos'
_GHC_CURL_DEFAULT='-H "Accept: application/vnd.github.v3+json"'

# -----------------------------------------------------------------------------
# GITHUB_INIT sets configuration to private but still global variables used
# by this script.
# Parameters:
#   $1   - Github organization (e.g. wultra)
#   $2   - Github repository (for example: powerauth-mobile-sdk)
#   $3   - Github access user (e.g. 'somebody')
#   $4   - Github access token
#   $5   - (optional) Path to temporary folder
# -----------------------------------------------------------------------------
function GITHUB_INIT
{
    _GHC_ORG=$1
    _GHC_REPO=$2
    _GHC_SEC_USER=$3
    _GHC_SEC_TOKEN=$4
    
    _GHC_VALIDATE_CONFIG
    
    _GHC_ORGREPO="${_GHC_ORG}/${_GHC_REPO}"
    _GHC_SEC="${_GHC_SEC_USER}:${_GHC_SEC_TOKEN}"
    
    # Prepare temp folder and make sure it exists
    GHC_TMP=${5:-`mktemp -d -t github-client`}
    $MD "${GHC_TMP}"
    # Prepare default in/out files for curl
    GHC_CIN="${GHC_TMP}/curl.in"
    GHC_COUT="${GHC_TMP}/curl.out"
    
    # Check requirements
    REQUIRE_COMMAND curl
    REQUIRE_COMMAND jq      # brew install jq
    
    DEBUG_LOG "Github client initialized for \"${_GHC_ORGREPO}\""
}

# -----------------------------------------------------------------------------
# GITHUB_DEINIT unsets global variables and remove temporary folder
# -----------------------------------------------------------------------------
function GITHUB_DEINIT
{
    # Unset vars and cleanup temp.
    local foo=${_GHC_ORGREPO} 
    unset _GHC_ORG
    unset _GHC_REPO
    unset _GHC_ORGREPO
    unset _GHC_SEC_USER
    unset _GHC_SEC_TOKEN
    unset _GHC_SEC
    [[ -d "${GHC_TMP}" ]] && $RM -r "${GHC_TMP}"
    unset GHC_COUT
    unset GHC_TMP
    DEBUG_LOG "Github client released for \"$foo\"."
}

# -----------------------------------------------------------------------------
# GITHUB_GET_ERROR prints error message from JSON to stdout.
# Parameters:
#   $1   - (optional) Path to JSON. If not set, ${GHC_COUT} is used.
# -----------------------------------------------------------------------------
function GITHUB_GET_ERROR
{
    local jsonf=${2:-${GHC_COUT}}
    local message=`jq .message "$jsonf"`
    if [ $message == 'null' ]; then
        message='Unexpected JSON response'
    fi
    echo $message
}

###############################################################################
# Releases

# -----------------------------------------------------------------------------
# GITHUB_FIND_RELEASE finds release by its name.
# Parameters:
#   $1   - Find mode, use 'find' or 'require' constants. 
#          If set to 'require', then release must exist.
#   $2   - Release tag
#   $3   - (optional) Path where to store output. If not set, ${GHC_COUT} is used.
# -----------------------------------------------------------------------------
function GITHUB_FIND_RELEASE
{
    _GHC_VALIDATE_CONFIG
    
    local mode="$1"
    local tag="$2"
    local cout="${3:-${GHC_COUT}}"
    
    curl -s --user "${_GHC_SEC}" ${_GHC_CURL_DEFAULT} \
        $(_GHC_API_URL "/releases/tags/$tag") \
        > "$cout"
    if [ x$mode == 'xrequire' ]; then
        local release_id=$(GITHUB_GET_RELEASE_ID "$cout")
        if [ "$release_id" == 'null' ] || [ -z "$release_id" ]; then
            FAILURE "Failed to find release \"${_GHC_ORGREPO} ^ ${tag}\". Error: " $(GITHUB_GET_ERROR "$cout")
        fi
    fi
}

# -----------------------------------------------------------------------------
# GITHUB_CREATE_RELEASE create a new release by its name.
# Parameters:
#   $1   - Release tag
#   $2   - Release title
#   $3   - Release body
#   $4   - Draft release: use 'true' or 'false' constants
#   $5   - Prerelease: use 'true' or 'false' constants
#   $6   - (optional) Path where to store output. If not set, ${GHC_COUT} is used.
# -----------------------------------------------------------------------------
function GITHUB_CREATE_RELEASE
{
    _GHC_VALIDATE_CONFIG
    
    local tag="$1"
    local title="$2"
    local body="$3"
    local draft="$4"
    local prerelease=$5
    local cout="${6:-${GHC_COUT}}"
    
    DEBUG_LOG "Creating release \"${_GHC_ORGREPO} ^ $tag\""
    
    # Check if release already exists
    GITHUB_FIND_RELEASE find "$tag" "${cout}"
    local release_id=$(GITHUB_GET_RELEASE_ID "${cout}")
    if [ "$release_id" != 'null' ] && [ ! -z "$release_id" ]; then
        WARNING "Release \"${_GHC_ORGREPO} ^ ${tag}\" already exists. Identifier: ${release_id}"
        return
    fi
    # Release doesn't exist, so create a new one
    cat > "${GHC_CIN}" <<-EOF
    {
        "tag_name" : "${tag}",
        "name" : "${title}",
        "body" : "${body}",
        "draft" : ${draft},
        "prerelease" : ${prerelease}
    }
	EOF
    curl -s --user "${_GHC_SEC}" ${_GHC_CURL_DEFAULT} \
        $(_GHC_API_URL "/releases") \
        -X POST -d "@${GHC_CIN}" \
        > "$cout"
    # Validate whether creation succeeded
    release_id=$(GITHUB_GET_RELEASE_ID "${cout}")
    if [ "$release_id" == 'null' ] || [ -z "$release_id" ]; then
        FAILURE "Failed to create release \"${_GHC_ORGREPO} ^ ${tag}\". Error: " $(GITHUB_GET_ERROR "${cout}")
    fi
    DEBUG_LOG "Newly created release \"${_GHC_ORGREPO} ^ ${tag}\" has identifier ${release_id}."
}

# -----------------------------------------------------------------------------
# GITHUB_GET_RELEASE_ID prints release ID received in release JSON to stdout.
# Parameters:
#   $1   - (optional) Path to release JSON. If not set, ${GHC_COUT} is used.
# -----------------------------------------------------------------------------
function GITHUB_GET_RELEASE_ID
{
    local jsonf="${1:-${GHC_COUT}}"
    jq .id "$jsonf"
}

# -----------------------------------------------------------------------------
# GITHUB_GET_RELEASE_TAG_NAME prints release NAME received in release JSON to stdout.
# Parameters:
#   $1   - (optional) Path to release JSON. If not set, ${GHC_COUT} is used.
# -----------------------------------------------------------------------------
function GITHUB_GET_RELEASE_TAG_NAME
{
    local jsonf="${1:-${GHC_COUT}}"
    jq -r .tag_name "$jsonf"
}

# -----------------------------------------------------------------------------
# GITHUB_GET_RELEASE_ASSETS_URL gets URL to release assets from release JSON.
# Parameters:
#   $1   - (optional) Path to release JSON, If not set, ${GHC_COUT} is used.
# -----------------------------------------------------------------------------
function GITHUB_GET_RELEASE_ASSETS_URL
{
    local jsonf="${1:-${GHC_COUT}}"
    jq -r .assets_url "$jsonf"
}

###############################################################################
# Release Assets

# -----------------------------------------------------------------------------
# GITHUB_GET_RELEASE_ASSETS receives assets f.
# Parameters:
#   $1   - Path to release JSON. Will be updated after success with new release JSON content.
#   $2   - Path to the file to upload.
#   $3   - Name of the file to upload. Use $(basename $2) or other custom name.
#   $4   - Content type (e.g. 'application/zip').
#   $5   - (optional) Path to output JSON, If not set, ${GHC_COUT} is used.
# -----------------------------------------------------------------------------
function GITHUB_UPLOAD_RELEASE_ASSET
{
    _GHC_VALIDATE_CONFIG
    
    local release_json="$1"
    local upload_path="$2"
    local upload_name="$3"
    local content_type="$4"
    local cout="${5:-${GHC_COUT}}"
    local content_length=$(_GHC_FILE_LENGTH "$upload_path")
    local jq_query=
    
    local release_tag=$(GITHUB_GET_RELEASE_TAG_NAME "$release_json")
    local release_id=$(GITHUB_GET_RELEASE_ID "$release_json")
    
    DEBUG_LOG "Uploading release asset \"${upload_name}\" for release \"${_GHC_ORGREPO} ^ ${release_tag}\"."
    
    # Look whether asset already exist
    jq_query=".assets[] | select(.name == \"${upload_name}\").id"
    local asset_id=`jq -r "$jq_query" "$release_json"`
    jq_query=".assets[] | select(.name == \"${upload_name}\").state"
    local asset_state=`jq -r "$jq_query" "$release_json"`
    
    if [ ! -z "$asset_id" ]; then
        # Print warning only in case that state is uploaded.
        if [ x${asset_state} == xuploaded ]; then
            WARNING "Release \"${_GHC_ORGREPO} ^ ${release_tag}\" already has asset \"${upload_name}\". Removing the file before new upload."
        fi
        GITHUB_DELETE_RELEASE_ASSET "$release_json" $asset_id
    fi
    
    # Test whether our upload URL is correct
    local upload_url=${_GHC_UPLOAD_URL}/${_GHC_ORGREPO}/releases/${release_id}/assets
    local repo_upload_url=`jq -r .upload_url "$release_json"`
    if [[ $repo_upload_url == $upload_url* ]]; then
        DEBUG_LOG "Upload url is OK: $upload_url"
    else
        # Our calculated upload URL is different than github provided in repo JSON.
        # This failure suggests that REST API has been changed.
        DEBUG_LOG "Our upload URL  : $upload_url"
        DEBUG_LOG "Repo upload URL : $repo_upload_url"
        FAILURE "Asset upload URL doesn't match URL from repo \"${_GHC_ORGREPO} ^ ${release_tag}\""
    fi
    
    # Upload file to github
    curl -s --user "${_GHC_SEC}" ${_GHC_CURL_DEFAULT} \
        "$upload_url?name=${upload_name}" \
        -H "Content-Type: ${content_type}" \
        -H "Content-Length: ${content_length}" \
        -X POST --data-binary @"${upload_path}" \
        > "$cout"
    
    # Get asset id from result
    asset_id=`jq -r .id "$cout"`
    if [ -z "${asset_id}" ] || [ "${asset_id}" == "null" ]; then
        FAILURE "Failed to upload asset \"${upload_name}\" in \"${_GHC_ORGREPO} ^ ${release_tag}\"."
    fi
    
    # Update release JSON
    GITHUB_FIND_RELEASE require "$release_tag" "${release_json}"
    
    jq_query=".assets[] | select(.name == \"${upload_name}\").id"
    local asset_id_after=`jq -r "$jq_query" "$release_json"`
    if [ "$asset_id" != "$asset_id_after" ]; then
        FAILURE "Failed to upload asset X \"${upload_name}\" in \"${_GHC_ORGREPO} ^ ${release_tag}\"."
    fi
    
    DEBUG_LOG "Asset \"${upload_name}\" uploaded to release \"${_GHC_ORGREPO} ^ ${release_tag}\"."
}

# -----------------------------------------------------------------------------
# GITHUB_DELETE_RELEASE_ASSET delete release asset with given ID.
# Parameters:
#   $1   - Path to release JSON. Will be updated after success with new release JSON content.
#   $2   - Path to the file to upload.
#   $3   - Name of the file to upload. Use $(basename $2) or other custom name.
#   $4   - Content type (e.g. 'application/zip').
#   $5   - (optional) Path to output JSON, If not set, ${GHC_COUT} is used.
# -----------------------------------------------------------------------------
function GITHUB_DELETE_RELEASE_ASSET
{
    _GHC_VALIDATE_CONFIG
    
    local release_json="$1"
    local asset_id="$2"
    local release_tag=$(GITHUB_GET_RELEASE_TAG_NAME "$release_json")
    local release_id=$(GITHUB_GET_RELEASE_ID "$release_json")
    local jq_query=
    
    jq_query=".assets[] | select(.id == ${asset_id}).name"
    local asset_name=`jq -r "$jq_query" "$release_json"`
    
    DEBUG_LOG "Deleting release asset \"${asset_name}\" ($asset_id) for release \"${_GHC_ORGREPO} ^ $release_tag\"."
    
    curl -s --user "${_GHC_SEC}" ${_GHC_CURL_DEFAULT} \
        $(_GHC_API_URL "/releases/assets/$asset_id") \
        -X DELETE \
        > "$cout"
    
    # Update release JSON
    GITHUB_FIND_RELEASE require "$release_tag" "${release_json}"
    
    # Look for the same asset
    jq_query=".assets[] | select(.id == ${asset_id}).id"
    local asset_id_after=`jq -r "$jq_query" "$release_json"`
    if [ "$asset_id_after" == "$asset_id" ]; then
        FAILURE "Failed to delete asset \"${asset_name} in \"${_GHC_ORGREPO} ^ ${release_tag}\". File is still in github."
    fi
}

###############################################################################
# Private functions (should not be used directly)

# -----------------------------------------------------------------------------
# _GH_VALIDATE_CFG tests 
# -----------------------------------------------------------------------------
function _GHC_VALIDATE_CONFIG
{
    [[ -z "${_GHC_ORG}" ]] && FAILURE "Missing 'organization' in github client configuration."
    [[ -z "${_GHC_REPO}" ]] && FAILURE "Missing 'repo' in github client configuration."
    [[ -z "${_GHC_SEC_USER}" ]] && FAILURE "Missing access user in github client configuration."
    [[ -z "${_GHC_SEC_TOKEN}" ]] && FAILURE "Missing access token in github client configuration."
    :
}

# -----------------------------------------------------------------------------
# _GHC_API_URL prints full URL created from relative URL to stdout
# Parameters:
#   $1   - Relative URL (for example: /releases)
# -----------------------------------------------------------------------------
function _GHC_API_URL
{
    echo "${_GHC_URL}/${_GHC_ORGREPO}$1"
}

# -----------------------------------------------------------------------------
# _GHC_FILE_LENGTH prints file length to stdout
# Parameters:
#   $1   - Path to file
# -----------------------------------------------------------------------------
function _GHC_FILE_LENGTH
{
    case `uname -s` in
        Linux*)  stat -c%s "$1" ;;
        Darwin*) stat -f%z "$1" ;;
        *)       stat --printf="%s" "$1" ;;
    esac
}

