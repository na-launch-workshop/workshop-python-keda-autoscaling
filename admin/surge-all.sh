#!/usr/bin/env bash
# Instructor halftime surge — floods participant scoreboards from inside the cluster.
# One surge Deployment per participant runs in the nba-surge namespace and hits their
# Route hostname, so traffic goes through the KEDA interceptor once they switch to it.
# Prerequisites: logged in as cluster-admin, scoreboards deployed (admin/deploy-all.sh).
# Usage: ./admin/surge-all.sh start  [namespace ...]   # default: every scoreboard
#        ./admin/surge-all.sh stop   [namespace ...]   # default: all surges
#        ./admin/surge-all.sh status

set -euo pipefail

SURGE_NS=nba-surge
IMAGE=image-registry.openshift-image-registry.svc:5000/openshift/nba-scoreboard:latest
CONCURRENCY="${CONCURRENCY:-20}"

routes() {
  if [ $# -gt 0 ]; then
    for ns in "$@"; do
      oc get route nba-scoreboard -n "$ns" -o jsonpath='{.metadata.namespace} {.spec.host}{"\n"}'
    done
  else
    oc get route -A -l app=nba-scoreboard \
      -o jsonpath='{range .items[*]}{.metadata.namespace} {.spec.host}{"\n"}{end}'
  fi
}

start() {
  oc get ns "$SURGE_NS" >/dev/null 2>&1 || oc create ns "$SURGE_NS" >/dev/null
  routes "$@" | while read -r ns host; do
    [ -n "$host" ] || continue
    oc apply -n "$SURGE_NS" -f - >/dev/null <<YAML
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
      containers:
        - name: surge
          image: $IMAGE
          command: ["python", "surge.py", "https://$host/api/score", "$CONCURRENCY", "86400"]
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
    echo "   ⚡ surging $ns → https://$host"
  done
}

stop() {
  if [ $# -gt 0 ]; then
    for ns in "$@"; do
      oc delete deployment -n "$SURGE_NS" -l "app=nba-surge,target=$ns" --ignore-not-found
    done
  else
    oc delete deployment -n "$SURGE_NS" -l app=nba-surge --ignore-not-found
  fi
}

status() {
  for d in $(oc get deployment -n "$SURGE_NS" -l app=nba-surge -o name 2>/dev/null); do
    echo "${d#deployment.apps/}: $(oc logs -n "$SURGE_NS" "$d" --tail=1 2>/dev/null | sed 's/^ *//')"
  done
}

cmd="${1:-}"; shift || true
case "$cmd" in
  start)  start "$@" ;;
  stop)   stop "$@" ;;
  status) status ;;
  *) sed -n '2,9p' "$0"; exit 1 ;;
esac
