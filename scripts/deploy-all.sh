#!/usr/bin/env bash
# Deploy the NBA scoreboard to every *-devspaces namespace.
# Run this after all participants have logged into Dev Spaces.
# Usage: ./scripts/deploy-all.sh

set -euo pipefail

MANIFESTS="$(cd "$(dirname "$0")/.." && pwd)/manifests"

echo "Ensuring KEDA HTTP ClusterRole exists..."
oc apply -f - <<'RBAC'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: keda-http-scaledobject-editor
rules:
  - apiGroups: ["http.keda.sh"]
    resources: ["httpscaledobjects"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
RBAC

echo ""
echo "Deploying NBA scoreboard to all devspaces namespaces..."

for ns in $(oc get ns -o name | grep '\-devspaces' | cut -d/ -f2 | sort); do
  echo -n "  → $ns ... "
  oc apply -f "$MANIFESTS/deployment.yaml" \
            -f "$MANIFESTS/service.yaml" \
            -f "$MANIFESTS/interceptor-service.yaml" \
            -f "$MANIFESTS/route.yaml" \
            -n "$ns" --quiet 2>&1
  oc create rolebinding keda-http-editor \
    --clusterrole=keda-http-scaledobject-editor \
    --group="system:serviceaccounts:$ns" \
    -n "$ns" --dry-run=client -o yaml 2>&1 | oc apply -f - --quiet 2>&1
  oc create rolebinding scoreboard-deployment-reader \
    --clusterrole=view \
    --serviceaccount="$ns:default" \
    -n "$ns" --dry-run=client -o yaml 2>&1 | oc apply -f - --quiet 2>&1
  echo "done"
done

echo ""
echo "Scoreboard deployed. Run 'oc get route nba-scoreboard -A' to verify routes."
