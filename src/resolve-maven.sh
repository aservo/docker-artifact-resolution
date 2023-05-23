#!/bin/bash

function main {

  local OPTIONS_PARSED

  # set default values
  SELF_PATH="$(readlink -f "$0")"
  SELF_NAME="$(basename "$SELF_PATH")"
  SELF_DIR="$(dirname "$SELF_PATH")"
  UTILS="$SELF_DIR/utils.sh"
  LOCAL_REPO_ORIG_DIR="$HOME/.m2/repository"
  MAVEN_CENTRAL_URL="https://repo1.maven.org/maven2"

  # load project variables
  source "$SELF_DIR/project.env"

  # parse arguments
  OPTIONS_PARSED=$(
    getopt \
      --options 'r:l:s:a:d:u:g:m:c:' \
      --longoptions 'remote-repo-urls:,local-repo-dir:,mirror-url:,artifact:,target-dir:,target-user:,target-group:,target-mode:,cache-dir:' \
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

  HASH="$("$UTILS" make_hash "${ARTIFACT:-}")"

  echo '<settings>' > "$TEMPDIR/settings.xml"
  write_maven_settings_local_repository "$TEMPDIR"
  write_maven_settings_servers "$TEMPDIR"
  write_maven_settings_mirrors "$TEMPDIR"
  write_maven_settings_profiles "$TEMPDIR"
  echo '</settings>' >> "$TEMPDIR/settings.xml"

  if [[ -n "${ARTIFACT:-}" ]]; then

    if [[ -n "${CACHE_DIR:-}" ]] && "$UTILS" cache_entry_exists "$HASH" "$CACHE_DIR"; then
      echo "$SELF_NAME: cache hit - read Maven artifact from cache: $ARTIFACT"
      "$UTILS" read_cache_entry "$HASH" "$CACHE_DIR" "$TEMPDIR/target/dependency"
    else

      mvn \
        --legacy-local-repository \
        --global-settings "$TEMPDIR/settings.xml" \
        "org.apache.maven.plugins:maven-dependency-plugin:$MAVEN_DEPENDENCY_PLUGIN_VERSION:copy" \
        "-Dproject.basedir=$TEMPDIR" \
        "-Dartifact=$ARTIFACT"

    fi

    if [[ -n "${CACHE_DIR:-}" ]] && ! "$UTILS" cache_entry_exists "$HASH" "$CACHE_DIR"; then
      echo "$SELF_NAME: cache miss - write Maven artifact to cache: $ARTIFACT"
      "$UTILS" write_cache_entry "$HASH" "$ARTIFACT" "$CACHE_DIR" "$TEMPDIR/target/dependency"
    fi

    "$UTILS" copy_files "$TEMPDIR/target/dependency" "$TARGET_DIR" \
      "${TARGET_USER:-}" "${TARGET_GROUP:-}" "${TARGET_MODE:-}"

  else

    mvn \
      --legacy-local-repository \
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
    echo "<localRepository>$LOCAL_REPO_DIR</localRepository>" >> "$TEMPDIR/settings.xml"
  else
    echo "<localRepository>$LOCAL_REPO_ORIG_DIR</localRepository>" >> "$TEMPDIR/settings.xml"
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
    <mirrorOf>external:*</mirrorOf>
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

  if [[ -n "${LOCAL_REPO_DIR:-}" ]] && [[ -d "$LOCAL_REPO_ORIG_DIR" ]]; then
    echo "
      <repository>
        <id>local-primary</id>
        <url>file://$LOCAL_REPO_ORIG_DIR</url>
      </repository>" >> "$TEMPDIR/settings.xml"
  fi

  echo "
      <repository>
        <id>central</id>
        <url>$MAVEN_CENTRAL_URL</url>
        <releases>
          <enabled>true</enabled>
          <updatePolicy>never</updatePolicy>
        </releases>
        <snapshots>
          <enabled>false</enabled>
        </snapshots>
      </repository>" >> "$TEMPDIR/settings.xml"

  while IFS= read -r line; do
    if [[ ! "$line" =~ ^[:space:]*$ ]]; then
      line="$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
      echo "
      <repository>
        <id>$("$UTILS" checksum "$line")</id>
        <url>$line</url>
        <releases>
          <enabled>true</enabled>
          <updatePolicy>never</updatePolicy>
        </releases>
        <snapshots>
          <enabled>true</enabled>
        </snapshots>
      </repository>" >> "$TEMPDIR/settings.xml"
    fi
  done <<< "${REMOTE_REPO_URLS:-}"

  echo '
    </repositories>
    <pluginRepositories>' >> "$TEMPDIR/settings.xml"

  if [[ -n "${LOCAL_REPO_DIR:-}" ]] && [[ -d "$LOCAL_REPO_ORIG_DIR" ]]; then
    echo "
      <pluginRepository>
        <id>local-primary</id>
        <url>file://$LOCAL_REPO_ORIG_DIR</url>
      </pluginRepository>" >> "$TEMPDIR/settings.xml"
  fi

  echo "
      <pluginRepository>
        <id>central</id>
        <url>$MAVEN_CENTRAL_URL</url>
        <releases>
          <enabled>true</enabled>
          <updatePolicy>never</updatePolicy>
        </releases>
        <snapshots>
          <enabled>false</enabled>
        </snapshots>
      </pluginRepository>" >> "$TEMPDIR/settings.xml"

  echo '
    </pluginRepositories>
  </profile>
</profiles>' >> "$TEMPDIR/settings.xml"
}

set -euo pipefail
main "$@"
exit 0
