# Module: Event-Driven Autoscaling with KEDA HTTP Add-on

**Technology Stack:** Python · FastAPI · KEDA · OpenShift

---

## Scenario

It's Game 5 of the NBA Finals. The Knicks are up 3-1 and MSG is packed. Fans across the city are hitting your scoreboard app every few seconds to check the score.

At halftime, traffic spikes. Your single pod is overwhelmed. The success rate drops. Requests fail.

Your job: create a KEDA `HTTPScaledObject` that automatically scales the scoreboard under load — and back to zero when things are quiet.

---

## Prerequisites

- Dev Spaces workspace open with this repository on the `http-scoring` branch
- Run **"1. Install dependencies"** from the command palette
- Your scoreboard URL: check with your instructor or run `oc get route nba-scoreboard`

---

## Step 1 — Open the scoreboard

Visit your scoreboard URL in a browser. You should see the live game — Knicks vs Spurs, Q4, scores updating every few seconds.

The **Activity Log** and **Success Rate** gauge on the right should both show 100%.

---

## Step 2 — Run the surge

Run **"4. Run surge (simulate halftime traffic)"** from the command palette.

Watch the dashboard — the success rate will drop and the activity log will fill with failures. This is what happens when one pod handles more traffic than it can process.

Leave the surge running.

---

## Step 3 — Build the HTTPScaledObject

Create a new file: `manifests/httpscaledobject.yaml`

Build it from scratch using the structure below. Each field is explained — understand what you're writing before you apply it.

```yaml
apiVersion: http.keda.sh/v1alpha1
kind: HTTPScaledObject
metadata:
  name: nba-scoreboard
spec:
  hosts:
    - <YOUR-HOSTNAME>        # hostname only — no https://
  scaleTargetRef:
    name: nba-scoreboard     # name of the Deployment to scale
    kind: Deployment
    apiVersion: apps/v1
    port: 8080               # port the app listens on
    service: nba-scoreboard  # the Service in front of the Deployment
  replicas:
    min: 0                   # scale to zero when idle
    max: 4                   # max pods
  scalingMetric:
    requestRate:
      granularity: 1s        # measure request rate per second
      targetValue: 10        # target requests/s per pod before scaling out
      window: 1m             # lookback window for rate calculation
```

**Key fields to understand:**

| Field | What it does |
|-------|-------------|
| `hosts` | The hostname KEDA intercepts — must match your Route exactly |
| `scaleTargetRef` | Which Deployment KEDA controls |
| `replicas.min: 0` | True scale-to-zero — no idle pods, no idle cost |
| `replicas.max: 4` | Upper limit on pods |
| `targetValue: 10` | Once requests exceed 10/s per pod, add another pod |

---

## Step 4 — Apply and watch

Run **"3. Apply HTTPScaledObject + enable KEDA routing"** from the command palette.

This does two things:
1. Applies your `HTTPScaledObject` — KEDA starts managing the deployment
2. Switches the Route to go through the KEDA interceptor

Watch the dashboard:
- The **pod grid** will start lighting up as KEDA scales out
- The **success rate** will climb back toward 100%
- The **activity log** will show the recovery in real time

---

## Step 5 — Stop the surge and watch scale-in

Stop the surge (`Ctrl+C` in the surge terminal).

After the cooldown period, KEDA will scale the deployment back toward `min: 0`. The pod grid lights will go out one by one.

---

## Stretch goal — tune the ScaledObject

Edit `manifests/httpscaledobject.yaml`:
- Change `targetValue` to `5` and re-apply — KEDA scales out sooner
- Change `max` to `10` and re-apply — more pods available under extreme load
- Change `min` to `1` and re-apply — no cold start on first request

Each change takes effect within the next KEDA polling cycle (~10s).
