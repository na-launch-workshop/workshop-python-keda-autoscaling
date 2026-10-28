# 🚀 Module: Event-Driven Autoscaling with KEDA

NBA Finals Scoreboard — Game 5

**Technology Stack:**

- Python
- FastAPI
- KEDA
- OpenShift

---

## 🎯 **Scenario**

It's Game 5 of the NBA Finals. The Knicks are up 3-1 and MSG is packed. Fans across the city are hitting your scoreboard app every few seconds to check the score.

At halftime, traffic spikes. Your single pod is overwhelmed. The success rate drops. Requests fail.

Your job: create a KEDA `HTTPScaledObject` that automatically scales the scoreboard under load — and back down when things are quiet.

---

## 📋 Prerequisites

- Dev Spaces workspace open with this repository
- Your scoreboard is already deployed in your namespace by the instructor

---

## 🧩 **Challenge**

### Step 1 — Open your scoreboard

Run **"1. Get my scoreboard URL"** from the command palette and open `https://<hostname>` in a browser. Keep the hostname handy — you'll need it in Step 3.

You should see the live game — Knicks vs Spurs, Q4, scores updating every few seconds. The **Activity Log** and **Success Rate** gauge on the right should both show 100%.

---

### Step 2 — Halftime

When everyone is ready, the instructor starts the halftime surge — a flood of fans hitting every scoreboard at once.

Watch your dashboard — the success rate will drop and the activity log will fill with failures. This is what happens when one pod handles more traffic than it can process.

The surge keeps running while you work on Step 3.

---

### Step 3 — Build the HTTPScaledObject

Create a new file: `manifests/httpscaledobject.yaml`

Build it from scratch using the structure below. Each field is explained — understand what you're writing before you apply it.

```yaml
apiVersion: http.keda.sh/v1alpha1
kind: HTTPScaledObject
metadata:
  name: nba-scoreboard
spec:
  hosts:
    - <YOUR-HOSTNAME>        # from "1. Get my scoreboard URL" — hostname only, no https://
  scaleTargetRef:
    name: nba-scoreboard     # name of the Deployment to scale
    kind: Deployment
    apiVersion: apps/v1
    port: 8080               # port the app listens on
    service: nba-scoreboard  # the Service in front of the Deployment
  replicas:
    min: 0                   # scale to zero when idle
    max: 4                   # max pods
  scaledownPeriod: 60        # seconds of low traffic before scaling in
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
| `scaledownPeriod: 60` | How long traffic must stay low before KEDA removes pods (default is 300s) |
| `targetValue: 10` | Once requests exceed 10/s per pod, add another pod |

---

### Step 4 — Apply and watch

Run **"2. Apply HTTPScaledObject + enable KEDA routing"** from the command palette.

This does two things:

1. Applies your `HTTPScaledObject` — KEDA starts managing the deployment
2. Switches the Route to go through the KEDA interceptor, so KEDA can count requests

Watch the dashboard:

- The **pod grid** will start lighting up as KEDA scales out
- The **success rate** will climb back toward 100%
- The **activity log** will show the recovery in real time

Run **"3. Watch my pods"** to follow the replica count from the terminal too.

---

### Step 5 — Watch scale-in

The instructor stops the surge.

About a minute later (`scaledownPeriod: 60`), KEDA starts removing pods. The pod grid lights will go out one by one — down to **one pod**.

Why not zero? The dashboard is served by the scoreboard itself and polls it every second, so an open browser tab is real traffic. To see true scale-to-zero, close the browser tab and keep **"3. Watch my pods"** running.

After another minute `READY` drops to `0/0`. Open the URL again and KEDA wakes a pod back up — the first request waits for the cold start.

---

### Stretch goal — tune the HTTPScaledObject

Edit `manifests/httpscaledobject.yaml` and re-apply with `oc apply -f manifests/httpscaledobject.yaml`:

- Change `targetValue` to `5` — KEDA scales out sooner
- Change `max` to `10` — more pods available under extreme load
- Change `min` to `1` — no cold start on first request
- Change `scaledownPeriod` to `300` — pods stay around longer after a spike

Ask the instructor to surge your scoreboard again to see the effect.
