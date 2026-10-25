#!/usr/bin/env bash
# Deploy the NBA scoreboard to every *-devspaces namespace.
# Run this after all participants have logged into Dev Spaces.
# Usage: ./scripts/deploy-all.sh

set -euo pipefail

MANIFESTS="$(cd "$(dirname "$0")/.." && pwd)/manifests"

echo "Deploying NBA scoreboard to all devspaces namespaces..."

for ns in $(oc get ns -o name | grep '\-devspaces' | cut -d/ -f2 | sort); do
  echo -n "  → $ns ... "
  oc apply -f "$MANIFESTS/deployment.yaml" \
            -f "$MANIFESTS/service.yaml" \
            -f "$MANIFESTS/interceptor-service.yaml" \
            -f "$MANIFESTS/route.yaml" \
            -n "$ns" --quiet 2>&1 && echo "done" || echo "FAILED"
done

echo ""
echo "Scoreboard deployed. Run 'oc get route nba-scoreboard -A' to verify routes."
