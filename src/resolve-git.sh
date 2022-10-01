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
      --options 'r:b:s:d:u:g:m:' \
      --longoptions 'url:,branch:,source-path:,target-dir:,target-user:,target-group:,target-mode:' \
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

  TEMPDIR="$(mktemp -d)"

  if [[ -z "${SOURCE_PATH:-}" ]]; then
    SOURCE_PATH='.'
  fi

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
  cp -vrp "$TEMPDIR/repo/$SOURCE_PATH" "$TEMPDIR/result"

  "$UTILS" copy_files "$TEMPDIR/result" "$TARGET_DIR" \
    "${TARGET_USER:-}" "${TARGET_GROUP:-}" "${TARGET_MODE:-}"

  rm -rf "$TEMPDIR"
}

set -euo pipefail
main "$@"
exit 0
