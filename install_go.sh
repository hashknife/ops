#!/usr/bin/env bash
set -eux

CACHE_DIR="$1"; shift
mkdir -p "$CACHE_DIR"
cd "$CACHE_DIR"

sudo apt-get remove --purge golang
sudo rm -rf '/usr/local/go/'

# NB: when updating our go version, you also need to do this
#   docker pull library/golang:latest 
#   git clone git@github.com:CenturyLinkLabs/golang-builder.git 
#   cd golang-builder/builder 
#   docker build . -t quay.io/hashknife/golang-builder:latest
#   docker run --rm -it --entrypoint='bash' quay.io/hashknife/golang-builder:latest # use `go version` to verify
#   docker push quay.io/hashknife/golang-builder
VERSION='1.9'
GO="go${VERSION}.linux-amd64.tar.gz"

wget --no-clobber "https://storage.googleapis.com/golang/$GO"
sudo tar -xzf "$GO" -C '/usr/local'
