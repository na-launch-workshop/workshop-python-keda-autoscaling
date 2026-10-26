#!/usr/bin/env bash
# Admin setup — run once before the workshop on a new cluster.
# Prerequisites: logged in as cluster-admin, KEDA and KEDA HTTP add-on installed.
# Usage: ./scripts/admin-setup.sh

set -euo pipefail

echo "=== NBA Scoreboard — Admin Setup ==="
echo ""

# 1. Build and push the scoreboard image
echo "1. Creating ImageStream and BuildConfig in openshift namespace..."
oc apply -f scripts/buildconfig.yaml

echo "   Starting image build (this takes ~2 minutes)..."
oc start-build nba-scoreboard -n openshift --follow

echo ""
echo "2. Granting workspace SAs edit permissions in all devspaces namespaces..."
for ns in $(oc get ns -o name | grep '\-devspaces' | cut -d/ -f2 | sort); do
  oc adm policy add-role-to-group edit "system:serviceaccounts:$ns" -n "$ns" 2>&1 | grep -v "already"
  echo "   → $ns"
done

echo ""
echo "Setup complete. Participants can now run devfile command '1. Deploy scoreboard'."
