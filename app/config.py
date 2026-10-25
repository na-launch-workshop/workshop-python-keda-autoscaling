import os

BOOTSTRAP_SERVERS = os.getenv("KAFKA_BOOTSTRAP_SERVERS", "kafka-kafka-bootstrap:9092")
TOPIC = os.getenv("KAFKA_TOPIC", "keda-events")
CONSUMER_GROUP = os.getenv("KAFKA_CONSUMER_GROUP", "keda-consumer-group")

SASL_USERNAME = os.getenv("KAFKA_SASL_USERNAME", "")
SASL_PASSWORD = os.getenv("KAFKA_SASL_PASSWORD", "")

# Slow processing is deliberate — it is what lets a backlog build up in Kafka.
PROCESSING_DELAY_MS = int(os.getenv("DEMO_PROCESSING_DELAY_MS", "2500"))

# Partition count of the keda-events topic, used when reporting lag.
PARTITION_COUNT = int(os.getenv("KAFKA_PARTITION_COUNT", "5"))

PORT = int(os.getenv("PORT", "8080"))


def kafka_config(extra: dict | None = None) -> dict:
    cfg = {"bootstrap.servers": BOOTSTRAP_SERVERS}
    if SASL_USERNAME and SASL_PASSWORD:
        cfg.update({
            "security.protocol": "SASL_PLAINTEXT",
            "sasl.mechanism": "SCRAM-SHA-512",
            "sasl.username": SASL_USERNAME,
            "sasl.password": SASL_PASSWORD,
        })
    if extra:
        cfg.update(extra)
    return cfg
