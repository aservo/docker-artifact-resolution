#!/bin/bash

function main {

  SELF_PATH="$(readlink -f "$0")"
  SELF_NAME="$(basename "$SELF_PATH")"
  SELF_DIR="$(dirname "$SELF_PATH")"
  TEMP_DIR="$SELF_DIR/../tmp"
  UTILS="$SELF_DIR/../src/utils.sh"
  CONFIG_FILE="$SELF_DIR/test-config.json"

  test_resolution
  echo "$SELF_NAME: finished test: resolve artifacts"

  test_resolution_with_cache
  echo "$SELF_NAME: finished test: resolve artifacts with cache"

  test_docker_build_ubuntu
  echo "$SELF_NAME: finished test: docker image build with Ubuntu base image"

  test_docker_build_rhel
  echo "$SELF_NAME: finished test: docker image build with RHEL base image"
}

function test_resolution {

  rm -rf "$TEMP_DIR"

  (
    cd "$SELF_DIR/.." && "./src/main.sh" resolve-using-config \
      --json-config-file "$CONFIG_FILE"
  )

  test -f "$TEMP_DIR/test_resolve_web/slf4j-api-2.0.3.jar"
  test -d "$TEMP_DIR/test_resolve_git/slf4j-api"
  test -f "$TEMP_DIR/test_resolve_maven/slf4j-api-2.0.3.jar"
}

function test_resolution_with_cache {

  WEB_URL="$(jq -r '.entries[] | select(.task=="resolve-web") | .arguments | .url' "$CONFIG_FILE")"
  GIT_URL="$(jq -r '.entries[] | select(.task=="resolve-git") | .arguments | .url' "$CONFIG_FILE")"
  GIT_BRANCH="$(jq -r '.entries[] | select(.task=="resolve-git") | .arguments | .branch' "$CONFIG_FILE")"
  GIT_SOURCE_PATH="$(jq -r '.entries[] | select(.task=="resolve-git") | .arguments | ."source-path"' "$CONFIG_FILE")"
  MAVEN_ARTIFACT="$(jq -r '.entries[] | select(.task=="resolve-maven") | .arguments | .artifact' "$CONFIG_FILE")"

  HASH_WEB="$("$UTILS" make_hash "$WEB_URL")"
  HASH_GIT="$("$UTILS" make_hash "$GIT_URL" "$GIT_BRANCH" "$GIT_SOURCE_PATH")"
  HASH_MAVEN="$("$UTILS" make_hash "$MAVEN_ARTIFACT")"

  rm -rf "$TEMP_DIR"

  (
    cd "$SELF_DIR/.." && "./src/main.sh" resolve-using-config \
      --json-config-file "$CONFIG_FILE" \
      --cache-dir "$TEMP_DIR/cache"
  )

  test -f "$TEMP_DIR/test_resolve_web/slf4j-api-2.0.3.jar"
  test -d "$TEMP_DIR/test_resolve_git/slf4j-api"
  test -f "$TEMP_DIR/test_resolve_maven/slf4j-api-2.0.3.jar"

  test -f "$TEMP_DIR/cache/$HASH_WEB/files/slf4j-api-2.0.3.jar"
  test -d "$TEMP_DIR/cache/$HASH_GIT/files/slf4j-api"
  test -f "$TEMP_DIR/cache/$HASH_MAVEN/files/slf4j-api-2.0.3.jar"

  rm -rf "$TEMP_DIR/test_resolve_web"
  rm -rf "$TEMP_DIR/test_resolve_git"
  rm -rf "$TEMP_DIR/test_resolve_maven"

  (
    cd "$SELF_DIR/.." && "./src/main.sh" resolve-using-config \
      --json-config-file "$CONFIG_FILE" \
      --cache-dir "$TEMP_DIR/cache"
  )

  test -f "$TEMP_DIR/test_resolve_web/slf4j-api-2.0.3.jar"
  test -d "$TEMP_DIR/test_resolve_git/slf4j-api"
  test -f "$TEMP_DIR/test_resolve_maven/slf4j-api-2.0.3.jar"
}

function test_docker_build_ubuntu {

  docker build \
    --tag artifact-resolution:test-ubuntu \
    "$SELF_DIR/../"
}

function test_docker_build_rhel {

  docker build \
    --file Dockerfile-rhel \
    --tag artifact-resolution:test-rhel \
    "$SELF_DIR/../"
}

set -euo pipefail
main "$@"
exit 0
