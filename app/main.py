import os
import random
import time
from pathlib import Path

from fastapi import FastAPI
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles

app = FastAPI(title="Scoreboard")

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
    _tick_score()
    time.sleep(0.4)          # deliberate delay — makes the pod overwhelm-able under surge
    return JSONResponse({
        **_score,
        "pod": os.environ.get("HOSTNAME", "unknown"),
    })


@app.get("/api/health")
def health():
    return {"status": "ok"}


app.mount("/", StaticFiles(directory=Path(__file__).parent / "static", html=True), name="static")
