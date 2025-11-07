#!/bin/bash

set -e

if [ "$#" -lt 3 ]; then
    echo "Usage: $0 release_tag github_token zip_file [zip_file ...]"
    echo
    echo "GitHub token can be created under your GitHub Settings → Developer settings → Personal access tokens"
    echo "This uploader uses https://github.com/github-release/github-release"
    exit 1
fi

tag=$1
token=$2
shift 2  # remove tag and token, leaving only zip files

echo "Uploading images to $tag"

for d in "$@"; do
    if [ ! -f "$d" ]; then
        echo "Error: file not found: $d" >&2
        exit 1
    fi
    fname=$(basename "$d")
    echo "Uploading $d as $fname"
    github-release upload -s "$token" \
        -u sailfishos-sony-nagara -a rinigus -r main \
        -t "$tag" \
        -f "$d" -n "$fname"
    echo "Sleep for 1 minute"
    sleep 60
done
