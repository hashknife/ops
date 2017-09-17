#!/bin/bash -eu

if [ -z $1 ]; then 
    echo "error: service required as argument"
    exit 1
fi

SERVICE=$1

curl -sSL \
	-X POST \
	-H "Content-Type: application/json" \
	-H "Accept: application/json" \
	-d "{
		\"build_parameters\": {
			\"HASHKNIFE_REPO\":\"${SERVICE}\",
			\"HASHKNIFE_SHA\":\"$CIRCLE_SHA1\",
			\"HASHKNIFE_ENV\":\"qa\"
		}
	}" \
	https://circleci.com/api/v1/project/hashknife/ops/tree/master?circle-token=$CIRCLE_TOKEN
