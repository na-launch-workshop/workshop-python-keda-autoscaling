#!/usr/bin/env bash
# Deploy a scoreboard into every participant namespace (*-devspaces, excluding openshift-devspaces).
# Run after participants have started their workspaces — the namespaces don't exist before.
# Re-runnable: namespaces that already have a scoreboard are skipped, so run it again for latecomers.
# Prerequisites: logged in as cluster-admin, admin/admin-setup.sh already run (image built).
# Usage: ./admin/deploy-all.sh [namespace ...]
#
# Permissions are normally set up separately (Kevin's project). This script only checks
# them and grants what is missing, so it never overlaps with existing bindings:
#   - workspace can create HTTPScaledObjects   → ClusterRole keda-http-scaledobject-editor (rbac.yaml)
#   - workspace can patch its Route, and the scoreboard can read its Deployment/Pods → edit

set -euo pipefail
cd "$(dirname "$0")"

NAMESPACES="${*:-$(oc get ns -o name | grep -- '-devspaces$' | cut -d/ -f2 | grep -v '^openshift-' | sort)}"

# Check as a service account in the namespace — grants go to the namespace's SA group,
# which covers both the workspace SA and the scoreboard's default SA.
can() {
  oc auth can-i "$1" "$2" -n "$3" -q \
    --as="system:serviceaccount:$3:default" \
    --as-group="system:serviceaccounts:$3" --as-group=system:serviceaccounts --as-group=system:authenticated
}

ensure_permissions() {
  local ns=$1 granted=""
  if ! can create httpscaledobjects.http.keda.sh "$ns"; then
    oc adm policy add-role-to-group keda-http-scaledobject-editor "system:serviceaccounts:$ns" -n "$ns" >/dev/null 2>&1
    granted="$granted keda-http-scaledobject-editor"
  fi
  if ! can patch routes "$ns" || ! can list pods "$ns" || ! can get deployments.apps "$ns"; then
    oc adm policy add-role-to-group edit "system:serviceaccounts:$ns" -n "$ns" >/dev/null 2>&1
    granted="$granted edit"
  fi
  if [ -n "$granted" ]; then echo "granted:$granted"; else echo "permissions ok"; fi
}

echo "=== NBA Scoreboard — Deploy to participant namespaces ==="
echo ""

if ! oc get clusterrole keda-http-scaledobject-editor >/dev/null 2>&1; then
  oc apply -f rbac.yaml >/dev/null
  echo "   Created ClusterRole keda-http-scaledobject-editor"
fi

for ns in $NAMESPACES; do
  perms=$(ensure_permissions "$ns")

  # Skip if already deployed — re-applying route.yaml would undo a participant's
  # switch to the KEDA interceptor.
  if oc get deployment nba-scoreboard -n "$ns" >/dev/null 2>&1; then
    echo "   = $ns (already deployed; $perms)"
    continue
  fi

  oc apply -n "$ns" \
    -f manifests/deployment.yaml \
    -f manifests/service.yaml \
    -f manifests/interceptor-service.yaml \
    -f manifests/route.yaml >/dev/null 2>&1
  echo "   + $ns → https://$(oc get route nba-scoreboard -n "$ns" -o jsonpath='{.spec.host}') ($perms)"
done

echo ""
echo "Done. Start the halftime surge with ./admin/surge-all.sh start"
