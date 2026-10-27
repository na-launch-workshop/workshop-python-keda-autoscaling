#!/usr/bin/env bash
# Admin setup — run once before the workshop on a new cluster.
# Prerequisites: logged in as cluster-admin, KEDA and KEDA HTTP add-on installed.
# Usage: ./admin/admin-setup.sh
#
# Day-of checklist — once repos are pushed to GitLab on the provisioned cluster,
# edit these CLUSTER-SPECIFIC values in GitLab (not GitHub, which stays on the test cluster):
#   1. admin/manifests/interceptor-service.yaml  Endpoints ip  → interceptor Service ClusterIP:
#        oc get svc keda-add-ons-http-interceptor-proxy -n keda -o jsonpath='{.spec.clusterIP}'
#   2. devfile.yaml  "1. Get my scoreboard URL"  apps domain:
#        oc get ingresses.config cluster -o jsonpath='{.spec.domain}'
#   3. admin/buildconfig.yaml  git uri → GitLab repo (only if app code will change there)
#
# Workshop flow (instructor):
#   ./admin/admin-setup.sh          build the image (this script)
#   participants start their workspaces
#   ./admin/deploy-all.sh           scoreboard into every *-devspaces namespace (re-run for latecomers)
#   ./admin/surge-all.sh start      halftime surge for everyone
#   ./admin/surge-all.sh stop       end of surge — participants watch scale-in

set -euo pipefail
cd "$(dirname "$0")"

echo "=== NBA Scoreboard — Admin Setup ==="
echo ""

echo "Creating ImageStream and BuildConfig in openshift namespace..."
oc apply -f buildconfig.yaml

echo "Starting image build (this takes ~2 minutes)..."
oc start-build nba-scoreboard -n openshift --follow

echo ""
echo "Setup complete. Once participants have started their workspaces, run ./admin/deploy-all.sh"
