#!/usr/bin/env bash
set -eux

CACHE_DIR="$1"; shift
mkdir -p "$CACHE_DIR"
cd "$CACHE_DIR"

go get -u github.com/golang/dep/cmd/dep
