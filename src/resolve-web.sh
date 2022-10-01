#!/bin/bash

function main {

  local OPTIONS_PARSED

  # set default values
  SELF_PATH="$(readlink -f "$0")"
  SELF_NAME="$(basename "$SELF_PATH")"
  SELF_DIR="$(dirname "$SELF_PATH")"
  UTILS="$SELF_DIR/utils.sh"

  # load project variables
  source "$SELF_DIR/project.env"

  # parse arguments
  OPTIONS_PARSED=$(
    getopt \
      --options 'r:x:d:u:g:m:' \
      --longoptions 'url:,headers:,target-dir:,target-user:,target-group:,target-mode:' \
      --name "$SELF_NAME" \
      -- "$@"
  )

  # replace arguments
  eval set -- "$OPTIONS_PARSED"

  # apply arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -r | --url)
        URL="$2"
        shift 2
        ;;
      -x | --headers)
        HEADERS="$2"
        shift 2
        ;;
      -d | --target-dir)
        TARGET_DIR="$2"
        shift 2
        ;;
      -u | --target-user)
        TARGET_USER="$2"
        shift 2
        ;;
      -g | --target-group)
        TARGET_GROUP="$2"
        shift 2
        ;;
      -m | --target-mode)
        TARGET_MODE="$2"
        shift 2
        ;;
      --)
        shift 1
        break
        ;;
      *)
        break
        ;;
    esac
  done

  # check that no unassigned argument remains
  if [[ $# -ne 0 ]]; then
    echo "$SELF_NAME: cannot handle unassigned arguments: $*" >&2
    exit 1
  fi

  resolve
}

function resolve {

  local TEMPDIR
  local CURL_COMMAND
  local HTTP_STATUS_CODE

  TEMPDIR="$(mktemp -d)"

  # shellcheck disable=SC2089
  CURL_COMMAND="curl -O -J --silent --write-out '%{http_code}' --output-dir '$TEMPDIR' '$URL'"

  while IFS= read -r line; do
    if [[ ! "$line" =~ ^[:space:]*$ ]]; then
      # shellcheck disable=SC2089
      CURL_COMMAND="$CURL_COMMAND -H '$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')'"
    fi
  done <<< "${HEADERS:-}"

  HTTP_STATUS_CODE="$(eval "$CURL_COMMAND")"

  if [[ "$HTTP_STATUS_CODE" -ne 200 ]]; then
      echo "$SELF_NAME: cannot download file: $URL" >&2
      exit 1
  fi

  "$UTILS" copy_files "$TEMPDIR" "$TARGET_DIR" \
    "${TARGET_USER:-}" "${TARGET_GROUP:-}" "${TARGET_MODE:-}"

  rm -rf "$TEMPDIR"
}

set -euo pipefail
main "$@"
exit 0
