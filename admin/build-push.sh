#!/usr/bin/env bash
# Build the scoreboard image and push it to Quay — only needed when admin/app or admin/surge.py change.
# Every cluster pulls this image directly; nothing is built on the cluster.
# Prerequisites: podman machine running, `podman login quay.io` as pknezevich, Quay repo public.
# Usage: ./admin/build-push.sh [tag]
#   Default tag is v1. For a new version, pass a new tag and update the image in
#   manifests/deployment.yaml and surge-all.sh to match.

set -euo pipefail
cd "$(dirname "$0")"

IMAGE="quay.io/pknezevich/nba-scoreboard:${1:-v1}"

# Cluster workers are x86 — build amd64 even on Apple Silicon.
podman build --platform linux/amd64 -t "$IMAGE" .
podman push "$IMAGE"

echo ""
echo "Pushed $IMAGE"
