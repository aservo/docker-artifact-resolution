#!/bin/bash

function main {

  local TASK
  local SHOW_HELP
  local SHOW_VERSION

  # set default values
  SELF_PATH="$(readlink -f "$0")"
  SELF_NAME="$(basename "$SELF_PATH")"
  SELF_DIR="$(dirname "$SELF_PATH")"
  SHOW_HELP=false
  SHOW_VERSION=false

  # load project variables
  source "$SELF_DIR/project.env"

  for var in "$@"; do
    if [[ "$var" == "-h" ]] || [[ "$var" == "--help" ]]; then
      SHOW_HELP=true
    fi
    if [[ "$var" == "-v" ]] || [[ "$var" == "--version" ]]; then
      SHOW_VERSION=true
    fi
  done

  if "$SHOW_HELP"; then
    echo "$SELF_NAME: for help, see the project website $PROJECT_URL"
  elif "$SHOW_VERSION"; then
    echo "$PROJECT_VERSION"
  else

    # check whether there is a defined task
    if [[ $# -eq 0 ]]; then
      echo "$SELF_NAME: require a task to continue" >&2
      exit 1
    fi

    # assign the task
    TASK="$1"
    shift 1

    # select task
    case "$TASK" in
      resolve-web)
        "$SELF_DIR/resolve-web.sh" "$@"
        ;;
      resolve-git)
        "$SELF_DIR/resolve-git.sh" "$@"
        ;;
      resolve-maven)
        "$SELF_DIR/resolve-maven.sh" "$@"
        ;;
      resolve-using-config)
        "$SELF_DIR/resolve-using-config.sh" "$@"
        ;;
      *)
        echo "$SELF_NAME: require a valid task" >&2
        exit 1
        ;;
    esac

  fi
}

set -euo pipefail
main "$@"
exit 0
