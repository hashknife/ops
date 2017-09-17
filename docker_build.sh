#!/bin/bash -eu

set -o pipefail

echo "=== $(basename $0) ==="

echo "$(cat <<-'EOF'
USAGE:
 -r Discards the golang-builder container after producing a fresh docker image
 -p Pushes the docker image id from $DOCKER_ID env var to quay
PURPOSE:
 This script is designed to leverage the centurylink/golang-builder docker image
 to create docker images of Golang apps at the smallest size possible. It will not
 work for applications written in other languages. If the -p flag is passed, the
 image will be pushed to quay.io.
REQUIREMENTS:
 * This project is intended to be run on CircleCI.
 * In order to make your golang project compatible with this script, you will need to
   add a comment after the package name in the go file which is the entrypoint. EX:
     package main // import github.com/zencoder/<SERVICE>
   The comment above is used to mount your source code as volume inside the golang-
   builder project from your file system. Without it, your source code cannot be
   found.
EOF
)"



echo $'\n==== SETUP ====\n'

image_name="quay.io/hashknife/$CIRCLE_PROJECT_REPONAME"
echo "image_name=$image_name"
echo "CIRCLE_SHA1=$CIRCLE_SHA1"
echo "Using Go: $(which go) -> $(go version)"

# If QUAY_USER or QUAY_TOKEN are set we need to login. We can assume one being set is good enough
echo $'\nLogging into Quay.io to push final docker image'
if [ -z ${QUAY_USER+x} ]; then
  echo "QUAY_USER environment variable is unset. Assuming quay session already exists."
else
  docker login -e="." -u="$QUAY_USER" -p="$QUAY_TOKEN" quay.io
fi
echo ""

# Grab Go package name
pkgName="$(go list -e -f '{{.ImportComment}}' 2>/dev/null || true)"
if [ -z $pkgName ]; then
  echo "ERROR: Unable to find the import comment in your applications entry point. See REQUIREMENTS above."
  exit 1
fi
echo "pkgName=$pkgName"

# Grab just first path listed in GOPATH
goPath="${GOPATH%%:*}"
if [ -z "$goPath" ]; then
  echo "ERROR: Empty GOPATH. Make sure it is set in your project settings or circle.yml file"
  exit 1
fi
echo "goPath=$goPath"

# Construct Go package path where vendor dependencies have been downloaded
pkgPath="$goPath/src/$pkgName"
if [ ! -d "$pkgPath" ]; then
  echo "ERROR: Unable to find a directory at $pkgPath. Make sure your project is inside your GOPATH."
  exit 1
fi
echo "pkgPath=$pkgPath"

# Sanity check the source directory
goPkgFileCount=$(cd $pkgPath && ls *go | wc -l)
if [ $goPkgFileCount -lt 1 ]; then
  echo "ERROR: No .go files found in source directory $pkgPath."
  exit 1
fi
echo "Found $goPkgFileCount go file(s) in source directory at $pkgPath"


# Run golang builder
echo $'\n==== DOCKER BUILD ====\n'
if [ "${1:-}" = "-r" ] || [ "${2:-}" = "-r" ]; then
  echo "Running golang-builder, removing container after build"
  DOCKER_ID=$(docker run -e CGO_ENABLED="${CGO_ENABLED:-0}" -e LDFLAGS="${LDFLAGS[@]:-}" --rm -v $pkgPath:/src -v /var/run/docker.sock:/run/docker.sock quay.io/hashknife/golang-builder:latest $image_name | tee /dev/tty | tail -1 | sed 's/.*Successfully built \(.*\)$/\1/')
else
  echo "Running golang-build, keeping container after build"
  DOCKER_ID=$(docker run -e CGO_ENABLED="${CGO_ENABLED:-0}" -e LDFLAGS="${LDFLAGS[@]:-}" -v $pkgPath:/src -v /var/run/docker.sock:/run/docker.sock quay.io/hashknife/golang-builder:latest $image_name | tee /dev/tty | tail -1 | sed 's/.*Successfully built \(.*\)$/\1/')
fi
echo "Finished docker build. Docker ID: $DOCKER_ID"


# PUSH Images
if [ "${1:-}" = "-p" ] || [ "${2:-}" = "-p" ]; then
  echo $'\n==== DOCKER PUSH ====\n'

  docker tag "$DOCKER_ID" "$image_name:$CIRCLE_SHA1"
  echo ""

  echo "List all images, hopefully see the :latest tag and the :$CIRCLE_SHA1"
  docker images

  echo $'\nPushing both tags to quay.io:'
  set -x
  docker push "$image_name:$CIRCLE_SHA1"
  docker push "$image_name:latest"
fi


# Add a totally useless line at the end of each script so that circle's web UI doesn't mess up the output.
echo $'\nDocker build finished.'
