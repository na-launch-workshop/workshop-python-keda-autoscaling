# Python

This project uses [FastAPI](https://fastapi.tiangolo.com/) for the web layer and
[confluent-kafka](https://github.com/confluentinc/confluent-kafka-python) for Kafka access.

## Layout

| Path | Purpose |
|---|---|
| `app/main.py` | FastAPI app: starts the consumer, serves `/status` and the dashboard |
| `app/consumer.py` | Background thread that consumes `keda-events` slowly |
| `app/status.py` | Reads committed vs. end offsets to report consumer lag |
| `app/config.py` | Environment-driven configuration |
| `producer.py` | Standalone script that floods the topic |

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

The dashboard is then served at `http://localhost:8080/` and the raw lag JSON at
`http://localhost:8080/status`.

## Producing a backlog

```shell script
python3.11 producer.py 3000
```

## Configuration

All settings are read from the environment:

| Variable | Default |
|---|---|
| `KAFKA_BOOTSTRAP_SERVERS` | `kafka-kafka-bootstrap:9092` |
| `KAFKA_TOPIC` | `keda-events` |
| `KAFKA_CONSUMER_GROUP` | `keda-consumer-group` |
| `DEMO_PROCESSING_DELAY_MS` | `2500` |
| `KAFKA_PARTITION_COUNT` | `5` |
| `PORT` | `8080` |

## Related Guides

- FastAPI ([guide](https://fastapi.tiangolo.com/)): Build the application
- confluent-kafka-python ([guide](https://docs.confluent.io/kafka-clients/python/current/overview.html)): Publish and consume Kafka records
- KEDA Kafka scaler ([guide](https://keda.sh/docs/latest/scalers/apache-kafka/)): Scale deployments from Kafka lag
