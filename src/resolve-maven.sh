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
      --options 'r:l:s:a:d:u:g:m:' \
      --longoptions 'remote-repo-urls:,local-repo-dir:,mirror-url:,artifact:,target-dir:,target-user:,target-group:,target-mode:' \
      --name "$SELF_NAME" \
      -- "$@"
  )

  # replace arguments
  eval set -- "$OPTIONS_PARSED"

  # apply arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -r | --remote-repo-urls)
        REMOTE_REPO_URLS="$2"
        shift 2
        ;;
      -l | --local-repo-dir)
        LOCAL_REPO_DIR="$2"
        shift 2
        ;;
      -s | --mirror-url)
        MIRROR_URL="$2"
        shift 2
        ;;
      -a | --artifact)
        ARTIFACT="$2"
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

  echo '<settings>' > "$TEMPDIR/settings.xml"
  write_maven_settings_local_repository "$TEMPDIR"
  write_maven_settings_servers "$TEMPDIR"
  write_maven_settings_mirrors "$TEMPDIR"
  write_maven_settings_profiles "$TEMPDIR"
  echo '</settings>' >> "$TEMPDIR/settings.xml"

  if [[ -n "${ARTIFACT:-}" ]]; then

    mvn \
      --global-settings "$TEMPDIR/settings.xml" \
      "org.apache.maven.plugins:maven-dependency-plugin:$MAVEN_DEPENDENCY_PLUGIN_VERSION:copy" \
      "-Dproject.basedir=$TEMPDIR" \
      "-Dartifact=$ARTIFACT"

    "$UTILS" copy_files "$TEMPDIR/target/dependency" "$TARGET_DIR" \
      "${TARGET_USER:-}" "${TARGET_GROUP:-}" "${TARGET_MODE:-}"

  else

    mvn \
      --global-settings "$TEMPDIR/settings.xml" \
      "org.apache.maven.plugins:maven-dependency-plugin:$MAVEN_DEPENDENCY_PLUGIN_VERSION:get" \
      "-Dartifact=org.apache.maven.plugins:maven-dependency-plugin:$MAVEN_DEPENDENCY_PLUGIN_VERSION"

    echo "$SELF_NAME: do nothing"

  fi

  rm -rf "$TEMPDIR"
}

function write_maven_settings_local_repository {

  local TEMPDIR

  TEMPDIR="$1"

  if [[ -n "${LOCAL_REPO_DIR:-}" ]]; then

    export LOCAL_REPO_DIR

    # shellcheck disable=SC2016
    echo '<localRepository>${env.LOCAL_REPO_DIR}</localRepository>' >> "$TEMPDIR/settings.xml"

  fi
}

function write_maven_settings_servers {

  local TEMPDIR

  TEMPDIR="$1"

  if [[ -n "${MAVEN_MIRROR_USERNAME:-}" ]] && [[ -n "${MAVEN_MIRROR_PASSWORD:-}" ]]; then

    export MAVEN_MIRROR_USERNAME
    export MAVEN_MIRROR_PASSWORD

    # shellcheck disable=SC2016
    echo '
<servers>
  <server>
    <id>internal-repository</id>
    <username>${env.MAVEN_MIRROR_USERNAME}</username>
    <password>${env.MAVEN_MIRROR_PASSWORD}</password>
  </server>
</servers>' >> "$TEMPDIR/settings.xml"

  fi
}

function write_maven_settings_mirrors {

  local TEMPDIR

  TEMPDIR="$1"

  if [[ -n "${MIRROR_URL:-}" ]]; then

    export MIRROR_URL

    # shellcheck disable=SC2016
    echo '
<mirrors>
  <mirror>
    <id>internal-repository</id>
    <name>internal-repository</name>
    <url>${env.MIRROR_URL}</url>
    <mirrorOf>*</mirrorOf>
  </mirror>
</mirrors>' >> "$TEMPDIR/settings.xml"

  fi
}

function write_maven_settings_profiles {

  local TEMPDIR

  TEMPDIR="$1"

  echo '
<profiles>
  <profile>
    <id>resolution</id>
    <activation>
      <activeByDefault>true</activeByDefault>
    </activation>
    <repositories>' >> "$TEMPDIR/settings.xml"

  while IFS= read -r line; do
    if [[ ! "$line" =~ ^[:space:]*$ ]]; then
      line="$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
      echo "
      <repository>
        <id>$("$UTILS" checksum "$line")</id>
        <url>$line</url>
        <releases>
          <enabled>true</enabled>
        </releases>
        <snapshots>
          <enabled>true</enabled>
        </snapshots>
      </repository>" >> "$TEMPDIR/settings.xml"
    fi
  done <<< "${REMOTE_REPO_URLS:-}"

  echo '
    </repositories>
  </profile>
</profiles>' >> "$TEMPDIR/settings.xml"
}

set -euo pipefail
main "$@"
exit 0
