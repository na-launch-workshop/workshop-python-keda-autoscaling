# Python

This project uses [FastAPI](https://fastapi.tiangolo.com/) for the web layer and the
[Kubernetes Python client](https://github.com/kubernetes-client/python) to report pod status.

## Layout

| Path | Purpose |
|---|---|
| `app/main.py` | FastAPI app: score, metrics and status APIs, serves the dashboard |
| `app/static/index.html` | Scoreboard dashboard — polls the APIs below |
| `surge.py` | Standalone script that floods `/api/score` with concurrent requests |
| `manifests/` | Deployment, Service, Route and interceptor Service for your namespace |
| `scripts/` | Admin-only cluster setup (image build, permissions) |

## API

| Endpoint | Purpose |
|---|---|
| `GET /api/score` | Current game score. Handles at most 12 concurrent requests per pod (0.4s each); beyond that returns `503` |
| `GET /api/metrics` | Success rate over the last 30s, as seen by the pod answering the request |
| `GET /api/status` | Replica counts and ready pod names for the `nba-scoreboard` Deployment |
| `GET /api/health` | Liveness check |

## Installing dependencies

The `udi-rhel9` workspace image defaults `python3` to 3.9, but FastAPI needs 3.10 or newer.
The image also ships 3.11, so call it explicitly:

```shell script
python3.11 -m pip install --user -r requirements.txt
```

## Running the application in dev mode

```shell script
python3.11 -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8080
```

The dashboard is then served at `http://localhost:8080/`. Outside the cluster the pod
status panel is empty — `/api/status` needs in-cluster credentials.

## Producing a surge

```shell script
python3.11 surge.py <url> [concurrency] [duration_seconds]
python3.11 surge.py http://localhost:8080/api/score 20 60
```

## Related Guides

- FastAPI ([guide](https://fastapi.tiangolo.com/)): Build the application
- Kubernetes Python client ([guide](https://github.com/kubernetes-client/python)): Read Deployment and Pod status
- KEDA HTTP Add-on ([guide](https://github.com/kedacore/http-add-on)): Scale deployments from HTTP traffic
