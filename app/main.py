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
import collections
_semaphore = threading.Semaphore(12)
_window = collections.deque()   # (timestamp, success)
_wlock = threading.Lock()
WINDOW = 30                     # rolling window in seconds

def _record(success: bool) -> None:
    now = time.time()
    cutoff = now - WINDOW
    with _wlock:
        _window.append((now, success))
        while _window and _window[0][0] < cutoff:
            _window.popleft()

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
    acquired = _semaphore.acquire(blocking=False)
    if not acquired:
        time.sleep(0.5)
        _record(False)
        return JSONResponse({"error": "overloaded"}, status_code=503)
    try:
        _tick_score()
        time.sleep(0.4)
        _record(True)
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
    now = time.time()
    cutoff = now - WINDOW
    with _wlock:
        recent = list(_window)
    recent = [(t, s) for t, s in recent if t >= cutoff]
    total = len(recent)
    ok    = sum(1 for _, s in recent if s)
    fail  = total - ok
    rate  = round(ok / total * 100) if total > 0 else 100
    return JSONResponse({"total": total, "ok": ok, "fail": fail, "rate": rate})


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
