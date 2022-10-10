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

function make_hash {

  local VALUE

  if [[ "$#" -eq 1 ]]; then

    VALUE="$1"

  else

    VALUE=''

    for var in "$@"; do
      VALUE="$VALUE $(checksum "$var")"
    done

  fi

  checksum "$VALUE"
}

function cache_entry_exists {

  local ENTRY_ID
  local CACHE_DIR

  ENTRY_ID="$1"
  CACHE_DIR="$2"

  test -d "$CACHE_DIR/$ENTRY_ID"
}

function read_cache_entry {

  local ENTRY_ID
  local CACHE_DIR
  local TARGET_DIR

  ENTRY_ID="$1"
  CACHE_DIR="$2"
  TARGET_DIR="$3"

  mkdir -p "$TARGET_DIR"
  cp -rfp "$CACHE_DIR/$ENTRY_ID/files/." "$TARGET_DIR"
}

function write_cache_entry {

  local ENTRY_ID
  local ENTRY_NAME
  local CACHE_DIR
  local SOURCE_DIR

  ENTRY_ID="$1"
  ENTRY_NAME="$2"
  CACHE_DIR="$3"
  SOURCE_DIR="$4"

  mkdir -p "$CACHE_DIR/$ENTRY_ID/files"

  echo "ENTRY_ID=$ENTRY_ID" > "$CACHE_DIR/$ENTRY_ID/cache-entry.txt"
  echo "ENTRY_NAME=$ENTRY_NAME" >> "$CACHE_DIR/$ENTRY_ID/cache-entry.txt"
  echo "DATE_TIME=$(date --iso-8601=seconds)" >> "$CACHE_DIR/$ENTRY_ID/cache-entry.txt"

  cp -rfp "$SOURCE_DIR/." "$CACHE_DIR/$ENTRY_ID/files"
}

set -euo pipefail
"$@"
exit 0
