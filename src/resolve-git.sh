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
      --options 'r:b:s:d:u:g:m:c:' \
      --longoptions 'url:,branch:,source-path:,target-dir:,target-user:,target-group:,target-mode:,cache-dir:' \
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
      -b | --branch)
        BRANCH="$2"
        shift 2
        ;;
      -s | --source-path)
        SOURCE_PATH="$2"
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

  local TEMPDIR
  local HASH

  TEMPDIR="$(mktemp -d)"

  if [[ -z "${SOURCE_PATH:-}" ]]; then
    SOURCE_PATH='.'
  fi

  HASH="$("$UTILS" make_hash "$URL" "${BRANCH:-}" "$SOURCE_PATH")"

  if [[ -n "${CACHE_DIR:-}" ]] && "$UTILS" cache_entry_exists "$HASH" "$CACHE_DIR"; then
    echo "$SELF_NAME: cache hit - read Git artifact from cache: URL=$URL branch=${BRANCH:-} source-path=$SOURCE_PATH"
    "$UTILS" read_cache_entry "$HASH" "$CACHE_DIR" "$TEMPDIR/result"
  else

    if [[ -n "${GIT_USERNAME:-}" ]] && [[ -n "${GIT_PASSWORD:-}" ]]; then
      git config --global credential.helper \
        '!f() { sleep 1; echo "username=${GIT_USERNAME}"; echo "password=${GIT_PASSWORD}"; }; f'
    fi

    if [[ -n "${BRANCH:-}" ]]; then
      git clone --branch "$BRANCH" --single-branch --no-checkout --depth 1 "$URL" "$TEMPDIR/repo"
    else
      git clone --single-branch --no-checkout --depth 1 "$URL" "$TEMPDIR/repo"
    fi

    git config --global --unset credential.helper || true

    git -C "$TEMPDIR/repo" checkout HEAD "$SOURCE_PATH"
    rm -rf "$TEMPDIR/repo/.git"
    mkdir "$TEMPDIR/result"
    cp -rfp "$TEMPDIR/repo/$SOURCE_PATH" "$TEMPDIR/result"

  fi

  if [[ -n "${CACHE_DIR:-}" ]] && ! "$UTILS" cache_entry_exists "$HASH" "$CACHE_DIR"; then
    echo "$SELF_NAME: cache miss - write Git artifact to cache: URL=$URL branch=${BRANCH:-} source-path=$SOURCE_PATH"
    "$UTILS" write_cache_entry "$HASH" "" "$CACHE_DIR" "$TEMPDIR/result"
  fi

  "$UTILS" copy_files "$TEMPDIR/result" "$TARGET_DIR" \
    "${TARGET_USER:-}" "${TARGET_GROUP:-}" "${TARGET_MODE:-}"

  rm -rf "$TEMPDIR"
}

set -euo pipefail
main "$@"
exit 0
