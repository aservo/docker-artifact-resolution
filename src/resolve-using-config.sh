#!/bin/bash

function main {

  local OPTIONS_PARSED

  # set default values
  SELF_PATH="$(readlink -f "$0")"
  SELF_NAME="$(basename "$SELF_PATH")"
  SELF_DIR="$(dirname "$SELF_PATH")"

  # load project variables
  source "$SELF_DIR/project.env"

  # parse arguments
  OPTIONS_PARSED=$(
    getopt \
      --options 'j:c:' \
      --longoptions 'json-config-file:,cache-dir:' \
      --name "$SELF_NAME" \
      -- "$@"
  )

  # replace arguments
  eval set -- "$OPTIONS_PARSED"

  # apply arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -j | --json-config-file)
        JSON_CONFIG_FILE="$2"
        shift 2
        ;;
      -c | --cache-dir)
        CACHE_DIR="$2"
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

  local COMMAND

  jq -c '. | if (. | type) == "array" then .[] else .entries[] end' "$JSON_CONFIG_FILE" | while read -r var; do

    COMMAND="$SELF_DIR/main.sh '$(echo "$var" | jq -r '.task')'"

    if [[ -n "${CACHE_DIR:-}" ]]; then
      COMMAND="$COMMAND --cache-dir '$CACHE_DIR'"
    fi

    COMMAND="$COMMAND$(
      echo "$var" |
        jq '.arguments' |
        jq 'del(.. | select(. == null)) | del(.. | select(. == "")) | del(.. | select(. == []))' |
        jq '. | to_entries | map({key, value: (.value | if type == "array" then (. | join("\n")) else . end)})' |
        jq -j '.[] | ("--" + .key | @sh) + " " + (.value | @sh) | " " + .'
    )"

    eval "$COMMAND"

  done
}

set -euo pipefail
main "$@"
exit 0
