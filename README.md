# 🚀 Module: Event-Driven Autoscaling with KEDA

Scale based on real-time business demand with KEDA to improve resource efficiency and cost management.

**Technology Stack:**

- KEDA (Kubernetes Event-driven Autoscaling)
- Python (FastAPI)
- Kafka

---

## 🎯 **Scenario**

Python workshop demonstrating event-driven autoscaling with KEDA and Kafka.

## 🧩 **Challenge**

What this lab shows:

- [ ] A Kafka topic (`keda-events`) that buffers work
- [ ] A Python consumer that processes messages slowly (2.5s per message) to simulate backlog
- [ ] How KEDA scales a deployment from 0 to N pods based on Kafka consumer lag
- [ ] How tuning `ScaledObject` parameters changes drain time

### Flow

1. **Produce messages** — flood the `keda-events` topic with a large backlog
2. **Deploy the consumer manually** — watch 1 pod drain slowly with no autoscaling
3. **Create a ScaledObject** — hand KEDA control and watch it scale pods up/down automatically

### Kafka UI

Monitor topic lag and consumer group activity in real time:

```
https://<kafka-ui-url>
```

Go to **Consumer Groups → keda-consumer-group** to see lag per partition.

### DevSpaces commands

| Command | What it does |
|---|---|
| 1. Produce Messages | Sends 3000 messages to `keda-events` |
| 2. Deploy Consumer | Scales the consumer deployment to 1 pod (no autoscaling) |
| 3. Apply ScaledObject | Applies `manifests/scaledobject.yaml` to enable KEDA autoscaling |

### Creating the ScaledObject

Create `manifests/scaledobject.yaml` in DevSpaces with the following content.

Replace `<your-namespace>` with your namespace (e.g. `bruce-devspaces`):

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: workshop-python-keda-autoscaling
spec:
  scaleTargetRef:
    name: workshop-python-keda-autoscaling
  minReplicaCount: 0
  maxReplicaCount: 5
  pollingInterval: 10
  cooldownPeriod: 60
  triggers:
    - type: kafka
      metadata:
        bootstrapServers: kafka-kafka-bootstrap.<your-namespace>.svc.cluster.local:9092
        consumerGroup: keda-consumer-group
        topic: keda-events
        lagThreshold: "10"
        activationLagThreshold: "1"
        offsetResetPolicy: "earliest"
```

Then run **Apply ScaledObject** to deploy it.

### Key ScaledObject parameters to experiment with

| Parameter | Effect |
|---|---|
| `maxReplicaCount` | Maximum pods KEDA can scale to (max 5 — matches partition count) |
| `lagThreshold` | Target lag per pod. Lower = more pods sooner |
| `pollingInterval` | How often KEDA checks lag (seconds) |
| `cooldownPeriod` | How long to wait before scaling back to 0 (seconds) |
