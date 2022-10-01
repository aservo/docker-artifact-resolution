#!/bin/bash

function copy_files {

  local SOURCE_DIR
  local TARGET_DIR
  local TARGET_USER
  local TARGET_GROUP
  local TARGET_MODE

  SOURCE_DIR="$1"
  TARGET_DIR="$2"
  TARGET_USER="$3"
  TARGET_GROUP="$4"
  TARGET_MODE="$5"

  if [[ -z "${TARGET_USER:-}" ]]; then
    TARGET_USER="$(id -u)"
  fi

  if [[ -z "${TARGET_GROUP:-}" ]]; then
    TARGET_GROUP="$(id -g)"
  fi

  chown -R "$TARGET_USER:$TARGET_GROUP" "$SOURCE_DIR"

  if [[ -n "${TARGET_MODE:-}" ]]; then

    chmod -R "$TARGET_MODE" "$SOURCE_DIR"

    install -d -o "$TARGET_USER" -g "$TARGET_GROUP" -m "$TARGET_MODE" "$TARGET_DIR"

  else
    install -d -o "$TARGET_USER" -g "$TARGET_GROUP" "$TARGET_DIR"
  fi

  cp -rfpv "$SOURCE_DIR/." "$TARGET_DIR"
}

function checksum {

  echo -n "$1" | sha256sum | cut -f 1 -d ' '
}

set -euo pipefail
"$@"
exit 0
