#!/usr/bin/env bash
# Deploy a scoreboard into every participant namespace (*-devspaces).
# Run after participants have started their workspaces — the namespaces don't exist before.
# Re-runnable: namespaces that already have a scoreboard are skipped, so run it again for latecomers.
# Prerequisites: logged in as cluster-admin, admin/admin-setup.sh already run (image built).
# Usage: ./admin/deploy-all.sh [namespace ...]

set -euo pipefail
cd "$(dirname "$0")"

NAMESPACES="${*:-$(oc get ns -o name | grep -- '-devspaces$' | cut -d/ -f2 | sort)}"

echo "=== NBA Scoreboard — Deploy to participant namespaces ==="
echo ""

for ns in $NAMESPACES; do
  # Skip if already deployed — re-applying route.yaml would undo a participant's
  # switch to the KEDA interceptor.
  if oc get deployment nba-scoreboard -n "$ns" >/dev/null 2>&1; then
    echo "   = $ns (already deployed, skipped)"
    continue
  fi

  # The scoreboard reads its own Deployment/Pods for the dashboard, and the
  # workspace applies the HTTPScaledObject and patches the Route.
  oc adm policy add-role-to-group edit "system:serviceaccounts:$ns" -n "$ns" >/dev/null

  oc apply -n "$ns" \
    -f manifests/deployment.yaml \
    -f manifests/service.yaml \
    -f manifests/interceptor-service.yaml \
    -f manifests/route.yaml >/dev/null
  echo "   + $ns → https://$(oc get route nba-scoreboard -n "$ns" -o jsonpath='{.spec.host}')"
done

echo ""
echo "Done. Start the halftime surge with ./admin/surge-all.sh start"
