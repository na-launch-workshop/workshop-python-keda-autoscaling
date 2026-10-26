import os
import random
import time
from pathlib import Path

from fastapi import FastAPI
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles

try:
    from kubernetes import client as k8s_client, config as k8s_config
    _NAMESPACE = Path("/var/run/secrets/kubernetes.io/serviceaccount/namespace").read_text().strip()
    k8s_config.load_incluster_config()
    _apps_v1 = k8s_client.AppsV1Api()
    _K8S = True
except Exception:
    _K8S = False
    _NAMESPACE = "unknown"

app = FastAPI(title="Scoreboard")

import threading
_semaphore = threading.Semaphore(12)
_total = 0
_ok = 0
_fail = 0
_lock = threading.Lock()

# Simulated live game state — increments slightly over time
_score = {"knicks": 108, "spurs": 102, "quarter": 4, "clock": "3:24", "period": "Q4"}
_last_update = time.time()


def _tick_score() -> None:
    global _last_update
    now = time.time()
    if now - _last_update > 15:
        _last_update = now
        team = random.choice(["knicks", "spurs"])
        pts = random.choice([1, 2, 3])
        _score[team] += pts


@app.get("/api/score")
def get_score():
    global _total, _ok, _fail
    acquired = _semaphore.acquire(blocking=False)
    with _lock:
        _total += 1
    if not acquired:
        time.sleep(0.5)
        with _lock:
            _fail += 1
        return JSONResponse({"error": "overloaded"}, status_code=503)
    try:
        _tick_score()
        time.sleep(0.4)
        with _lock:
            _ok += 1
        return JSONResponse({
            **_score,
            "pod": os.environ.get("HOSTNAME", "unknown"),
        })
    finally:
        _semaphore.release()


@app.get("/api/health")
def health():
    return {"status": "ok"}


@app.get("/api/metrics")
def get_metrics():
    with _lock:
        return JSONResponse({
            "total": _total,
            "ok":    _ok,
            "fail":  _fail,
            "rate":  round(_ok / _total * 100) if _total > 0 else 0,
        })


@app.get("/api/status")
def get_status():
    if not _K8S:
        return JSONResponse({"replicas": -1, "ready": -1, "available": -1, "namespace": _NAMESPACE})
    try:
        d = _apps_v1.read_namespaced_deployment("nba-scoreboard", _NAMESPACE)
        core_v1 = k8s_client.CoreV1Api()
        pods = core_v1.list_namespaced_pod(_NAMESPACE, label_selector="app=nba-scoreboard")
        pod_names = [
            p.metadata.name
            for p in pods.items
            if p.status.phase == "Running" and all(
                c.ready for c in (p.status.container_statuses or [])
            )
        ]
        return JSONResponse({
            "replicas":  d.status.replicas or 0,
            "ready":     d.status.ready_replicas or 0,
            "available": d.status.available_replicas or 0,
            "pods":      pod_names,
            "namespace": _NAMESPACE,
        })
    except Exception as e:
        return JSONResponse({"replicas": -1, "ready": -1, "available": -1, "pods": [], "error": str(e), "namespace": _NAMESPACE})


app.mount("/", StaticFiles(directory=Path(__file__).parent / "static", html=True), name="static")
