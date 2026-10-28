#!/usr/bin/env bash
# Instructor halftime surge — floods participant scoreboards from inside the cluster.
# One surge Deployment per participant runs in the nba-surge namespace and hits their
# Route hostname, so traffic goes through the KEDA interceptor once they switch to it.
# Prerequisites: logged in as cluster-admin, scoreboards deployed (admin/deploy-all.sh).
# Usage: ./admin/surge-all.sh start  [namespace ...]   # default: every scoreboard; LEAD=20 s countdown
#        ./admin/surge-all.sh stop   [namespace ...]   # default: all surges
#        ./admin/surge-all.sh status
#
# Multiple clusters: `oc login` to each once, then list their contexts (oc config get-contexts)
# in CLUSTERS and every command runs against all of them, e.g.
#   CLUSTERS="east west" ./admin/surge-all.sh start
# Without CLUSTERS, the current oc context is used.

set -euo pipefail

SURGE_NS=nba-surge
IMAGE=image-registry.openshift-image-registry.svc:5000/workspace-images/nba-scoreboard:latest
CONCURRENCY="${CONCURRENCY:-20}"
CTX=""

# oc against the cluster currently being processed
kc() { oc ${CTX:+--context="$CTX"} "$@"; }

routes() {
  if [ $# -gt 0 ]; then
    for ns in "$@"; do
      kc get route nba-scoreboard -n "$ns" -o jsonpath='{.metadata.namespace} {.spec.host}{"\n"}' 2>/dev/null || true
    done
  else
    kc get route -A -l app=nba-scoreboard \
      -o jsonpath='{range .items[*]}{.metadata.namespace} {.spec.host}{"\n"}{end}'
  fi
}

start() {
  kc get ns "$SURGE_NS" >/dev/null 2>&1 || kc create ns "$SURGE_NS" >/dev/null
  # One apply for every participant, so all surge pods are created together
  local yaml
  yaml=$(routes "$@" | while read -r ns host; do
    [ -n "$host" ] || continue
    cat <<YAML
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: surge-$ns
  labels:
    app: nba-surge
    target: $ns
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nba-surge
      target: $ns
  template:
    metadata:
      labels:
        app: nba-surge
        target: $ns
    spec:
      # surge.py ignores SIGTERM — without this, stop takes the default 30s to kick in
      terminationGracePeriodSeconds: 1
      containers:
        - name: surge
          image: $IMAGE
          # Wait for the shared go time, so every participant (on every cluster) surges together
          command: ["sh", "-c", "echo waiting for halftime; while [ \$(date +%s) -lt $GO_AT ]; do sleep 0.2; done; exec python surge.py https://$host/api/score $CONCURRENCY 86400"]
          env:
            - name: SURGE_INSECURE
              value: "1"
            - name: PYTHONUNBUFFERED
              value: "1"
          resources:
            requests:
              cpu: 100m
              memory: 64Mi
            limits:
              cpu: 500m
              memory: 128Mi
YAML
    echo "   ⚡ $ns → https://$host" >&2
  done)
  if [ -z "$yaml" ]; then echo "   no scoreboards found"; return; fi
  echo "$yaml" | kc apply -n "$SURGE_NS" -f - >/dev/null
}

stop() {
  if [ $# -gt 0 ]; then
    for ns in "$@"; do
      kc delete deployment -n "$SURGE_NS" -l "app=nba-surge,target=$ns" --ignore-not-found
    done
  else
    kc delete deployment -n "$SURGE_NS" -l app=nba-surge --ignore-not-found
  fi
}

status() {
  local found=""
  for d in $(kc get deployment -n "$SURGE_NS" -l app=nba-surge -o name 2>/dev/null); do
    found=1
    echo "   ${d#deployment.apps/}: $(kc logs -n "$SURGE_NS" "$d" --tail=1 2>/dev/null | sed 's/^ *//')"
  done
  [ -n "$found" ] || echo "   no surges running"
}

cmd="${1:-}"; shift || true
case "$cmd" in
  start|stop|status) ;;
  *) sed -n '2,13p' "$0"; exit 1 ;;
esac

if [ "$cmd" = start ]; then
  # Every surge pod waits for this moment, so all participants on all clusters start together
  GO_AT=$(( $(date +%s) + ${LEAD:-20} ))
  out=$(mktemp -d)
  i=0
  for CTX in ${CLUSTERS:-current}; do
    [ "$CTX" = current ] && CTX=""
    i=$((i + 1))
    ( echo "== $(kc whoami --show-server)"; start "$@" ) >"$out/$i" 2>&1 &
  done
  wait
  cat "$out"/*; rm -rf "$out"
  echo ""
  while [ "$(date +%s)" -lt "$GO_AT" ]; do
    printf '\r   🏀 halftime in %2ss ' $(( GO_AT - $(date +%s) )); sleep 1
  done
  printf '\r   🏀 HALFTIME — surge running            \n'
  exit 0
fi

for CTX in ${CLUSTERS:-current}; do
  [ "$CTX" = current ] && CTX=""
  echo "== $(kc whoami --show-server)"
  "$cmd" "$@"
done
