#!/usr/bin/env bash
#
#   ██████╗ ██╗   ██╗██╗██╗     ██████╗
#   ██╔══██╗██║   ██║██║██║     ██╔══██╗
#   ██████╔╝██║   ██║██║██║     ██║  ██║
#   ██╔══██╗██║   ██║██║██║     ██║  ██║
#   ██████╔╝╚██████╔╝██║███████╗██████╔╝
#   ╚═════╝  ╚═════╝ ╚═╝╚══════╝╚═════╝
#       © 2022 Indico Systems AS
#          All rights reserved
#
# A simple helper script for building and publishing almost
# all indico software. The usage of this script is the same
# across all repositories, and it depends on doctl and docker
# For more information, questions or documentation pleas
# contact your friendly neighbourhood Martin.

# Defaults
# The location of package.json or version file of same format, usually "./package.json"
BUILD_PROJECT_FILE="./package.json"
# The docker container registry to push to
BUILD_REGISTRY_NAME="registry.digitalocean.com/indico"
# Retrieve current version
old_img=$(jq -r '.version' "$BUILD_PROJECT_FILE")
# shellcheck disable=SC2001
old_img=$(echo "$old_img" | sed "s/.*://g")

# TODO:: Support multiple env files
if [ -f ".build.env" ]; then
  source .build.env
fi

function header() {
  echo
  echo
  echo "    ██████╗ ██╗   ██╗██╗██╗     ██████╗"
  echo "    ██╔══██╗██║   ██║██║██║     ██╔══██╗"
  echo "    ██████╔╝██║   ██║██║██║     ██║  ██║"
  echo "    ██╔══██╗██║   ██║██║██║     ██║  ██║"
  echo "    ██████╔╝╚██████╔╝██║███████╗██████╔╝"
  echo "    ╚═════╝  ╚═════╝ ╚═╝╚══════╝╚═════╝"
  echo ""
  echo "        © 2022 Indico Systems AS"
  echo "           All rights reserved"
  echo ""
}

function help() {
  header
  echo "A simple helper script for building and publishing almost"
  echo "all indico software. The usage of this script is the same"
  echo "across all repositories, and it depends on doctl and docker"
  echo "For more information, questions or documentation pleas"
  echo "contact your friendly neighbourhood Martin."
  echo ""
  echo "Requirements:"
  echo " - doctl : DigitalOcean command line interface, see install"
  echo "           guide at https://dploy.indico.dev/#/digitalocean"
  echo " - docker: Docker runner, for windows this should be Docker-"
  echo "           Desktop, guide at https://dploy.indico.dev/#/docker"
  echo " - jq:   : Json command line parser, required to update version"
  echo "         : see docs to install https://stedolan.github.io/jq/"
  echo ""
  echo "Eks: ./build.sh 0.1.5-beta.5 -p --kuber --node --kpub -y"
  echo ""
  echo "Usage:      "
  echo "  -h,H          : Help, shows usage."
  echo "  --help        : Opens the full documentation page for this script at"
  echo "                  https://dploy.indico.dev/#/build."
  echo "  -y,Y          : Auto accepts image overwrite and reusing existing"
  echo "                  build version."
  echo "  -p, --publish : Publishes the docker image to the do-reguistry upon "
  echo "                  build completion"
  echo "  --kuber       : updates kubernetes deployment file with the new version."
  echo "                  NB, requires yq https://mikefarah.gitbook.io/yq/"
  echo "  --node        : Updates package json with the new version number."
  echo "                  NB, requires jq https://stedolan.github.io/jq/"
  echo "  --kpub,kpop   : Applies the kubernetes deployment changes with kubectl."
  echo "                  This requires kubectl to be installed and configured with"
  echo "                  the correct kubernetes cluster. Remember to sett the "
  echo "                  correct namespace"
  echo "  --tag         : Add and commits the updated resources post build, pushes"
  echo "                  the commit, and finally tags and pushes this final commit"
  echo "                  with the new version."
  echo "  v, version    : Displays the last built and published version name according"
  echo "                  to this repo."
  echo "  -v,--version  : Displays the last built version, and just the version."
  echo " "
}

open_url() {
  url="$1"
  xdg-open $url 2>/dev/null && return 0
  open $url 2>/dev/null && return 0
  start $url 2>/dev/null && return 0
  return 1
}

# Checks for minimum required environment
if [[ $# -lt 1 ]] && [ -z "$BUILD_IMAGE_VERSION" ] || [ -z "$BUILD_REGISTRY_NAME" ] || [ -z "$BUILD_IMAGE_NAME" ]; then
  help
  exit 0
fi

for arg in "$@"; do
  case "$arg" in
  --kpop | --kpub)
    export BUILD_IMAGE_KPUB=1
    ;;
  --node)
    export BUILD_IMAGE_NODE=1
    ;;
  --kuber)
    export BUILD_IMAGE_KUBER=1
    ;;
  --publish | -p)
    export BUILD_IMAGE_PUBLISH=1
    ;;
  -[yY])
    export BUILD_ALLOW=1
    ;;
  -[hH])
    help
    exit 0
    ;;
  --help)
    open_url "https://dploy.indico.dev/#/build"
    exit 0
    ;;
  --tag)
    export BUILD_GIT_TAG=1
    ;;
  v | version)
    echo "Last built version was $old_img"
    exit 0
    ;;
  --version|-v)
    echo $old_img
    exit 0
    ;;
  *)
    next_version=$arg
    ;;
  esac
done

# Check if docker is running
if ! docker ps &>/dev/null; then
  header
  echo " - error: Failed to connect to docker, ensure that docker is running."
  echo "          For more info on installing and running docker se the guide"
  echo "          at https://dploy.indico.dev/#/docker"
  exit 1
fi

function yesNo() {
  [ "$BUILD_ALLOW" -eq 1 ] && return 0
  read -r -p "$1 [Y/n]: " input
  case $input in
  [yY][eE][sS] | [yY])
    return 0
    ;;
  esac
  return 1
}

# Starts the actual build
header

if [ "$BUILD_IMAGE_PUBLISH" -eq 1 ]; then
  echo "### Connecting to digital digitalocean"
  (doctl registry login | sed -e 's/^/ - /;') || exit 1
  echo
fi

echo "### Resolving image version"
if [ -n "$next_version" ]; then
  export BUILD_IMAGE_VERSION="$next_version"
fi

while [ -z "$BUILD_IMAGE_VERSION" ]; do
  echo " - error: invalid image version"
  read -r -p "Set the new image version formatted like \"$old_img\": " BUILD_IMAGE_VERSION
done

while [ -n "$(docker images -q "$BUILD_IMAGE_NAME:$BUILD_IMAGE_VERSION")" ]; do
  yesNo " - error: image version ($BUILD_IMAGE_VERSION) already exist, overwrite?" && break
  read -r -p "Set the new image version formatted like \"$old_img\": " BUILD_IMAGE_VERSION
done

BUILD_IMAGE_VERSION=${BUILD_IMAGE_VERSION/$'\r'/}
BUILD_IMAGE_NAME=${BUILD_IMAGE_NAME/$'\r'/}

echo " - Using image version: $BUILD_IMAGE_VERSION"
echo "   "

if [ -n "$BUILD_ADDITIONAL_VERSION" ]; then
  echo "### Updating additional version"
  if $BUILD_ADDITIONAL_VERSION "$BUILD_IMAGE_VERSION"; then
    echo " - updated additional version."
  else
    echo " - error: failed to update additional version"
    exit 1
  fi
  echo " "
fi

if [ "$BUILD_IMAGE_NODE" -eq 1 ]; then
  echo "### Updating node version"
  if [ ! -f "$BUILD_PROJECT_FILE" ]; then
    echo " - error: failed to locate project version file at $BUILD_PROJECT_FILE"
    exit 1
  fi
  curr_date=$(date +"%Y-%m-%d")
  contents=$(jq --arg vs "$BUILD_IMAGE_VERSION" --arg date "$curr_date" '.version = $vs | .versionDate = $date' "$BUILD_PROJECT_FILE")
  echo "${contents}" >"$BUILD_PROJECT_FILE"
  echo " - updated date and version in $BUILD_PROJECT_FILE"
  echo " "
fi

if [ -n "$BUILD_EXEC" ]; then
  echo "### Running Build Exec"
  if $BUILD_EXEC; then
    echo " - build exec completed."
  else
    echo " - error: build exec failed"
    exit 1
  fi
  echo ""
fi

echo "### Building \"$BUILD_IMAGE_NAME:$BUILD_IMAGE_VERSION\""
if ! docker build -t "$BUILD_IMAGE_NAME:$BUILD_IMAGE_VERSION" .; then
  echo " - error: build failed."
  exit 1
fi
printf "\n"

if [ "$BUILD_IMAGE_PUBLISH" -eq 1 ]; then

  export BUILD_IMAGE_NEXT="$BUILD_REGISTRY_NAME/$BUILD_IMAGE_NAME:$BUILD_IMAGE_VERSION"

  echo "### Tagging the freshly made image"
  docker tag "$BUILD_IMAGE_NAME:$BUILD_IMAGE_VERSION" "$BUILD_IMAGE_NEXT"
  echo " - tagged: $BUILD_IMAGE_NAME:$BUILD_IMAGE_VERSION"
  echo " - tagged: $BUILD_IMAGE_NEXT"
  printf "\n"

  echo "### Publishing image to $BUILD_REGISTRY_NAME"
  if ! docker push "$BUILD_IMAGE_NEXT" | sed -e 's/^/ - /;'; then
    echo " - error: failed to push docker image"
    exit 1
  fi
  echo ""
fi

if [ "$BUILD_IMAGE_KUBER" -eq 1 ]; then
  echo "### Updating image version"
  if yq e -i '.spec.template.spec.containers[0].image = strenv(BUILD_IMAGE_NEXT)' ./kubernetes/deployment.yml; then
    echo " - updated deployment.yml"
  else
    exit 1
  fi
  echo ""
fi

# TODO::Be carefull when using this!
# Performing the actual publishing step requires kubectl
# to be installed and configured both with the do-container-registry
# and a deployment cluster. Contact your friendly neighbourhood Martin
# if you wish to learn more or configure this.

if [ "$BUILD_IMAGE_KPUB" -eq 1 ]; then
  echo "### Deploying to kubernetes"
  BUILD_KUBE_CONTEXT_CURRENT="$(kubectl config current-context)"
  if [ -n "$BUILD_KUBE_CONTEXT" ] && [ "$BUILD_KUBE_CONTEXT_CURRENT" != "$BUILD_KUBE_CONTEXT" ]; then
    echo " - ensuring correct context \"dploy\""
    printf " - $(kubectl config use-context "${BUILD_KUBE_CONTEXT}")\n"
  fi
  kubectl apply -f ./kubernetes/deployment.yml | sed -e 's/^/ - /;'
  if [ -n "$BUILD_KUBE_CONTEXT_CURRENT" ] && [ "$BUILD_KUBE_CONTEXT_CURRENT" != "$BUILD_KUBE_CONTEXT" ]; then
    echo " - returning to previous context \"${BUILD_KUBE_CONTEXT_CURRENT}\""
    kubectl config use-context "${BUILD_KUBE_CONTEXT_CURRENT}" | sed -e 's/^/ - /;'
  fi
  echo " "
fi

if [ "$BUILD_GIT_TAG" -eq 1 ]; then
  echo "### Publishing changes to git"
  printf " - adding changed files"
  if git add . &>/dev/null; then
    printf ": success\n"
  else
    printf ": failed\n"
    exit 1
  fi
  printf " - commit changed files"
  if [ -z "$BUILD_GIT_MESSAGE" ]; then
    export BUILD_GIT_MESSAGE="built new version"
  fi
  if git commit -m "${BUILD_GIT_MESSAGE}" &>/dev/null; then
    printf ": success\n"
  else
    printf ": failed\n"
    exit 1
  fi
  printf " - tagging commit \"$BUILD_IMAGE_VERSION\""
  if git tag -f "$BUILD_IMAGE_VERSION" &>/dev/null; then
    printf ": success\n"
  else
    printf ": failed\n"
    exit 1
  fi
  printf " - pushing changes"
  if git push --all &>/dev/null; then
    printf ": success\n"
  else
    printf ": failed\n"
    exit 1
  fi
  echo " "
fi

exit 0