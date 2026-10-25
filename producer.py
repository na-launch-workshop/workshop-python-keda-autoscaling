"""Floods the keda-events topic so KEDA has a backlog to react to.

Usage: python producer.py [count]
"""

import json
import os
import sys
import uuid

from confluent_kafka import Producer


def main() -> None:
    count = int(sys.argv[1]) if len(sys.argv) > 1 else 100
    bootstrap_servers = os.getenv("KAFKA_BOOTSTRAP_SERVERS", "kafka-kafka-bootstrap:9092")
    topic = os.getenv("KAFKA_TOPIC", "keda-events")

    sasl_username = os.getenv("KAFKA_SASL_USERNAME", "")
    sasl_password = os.getenv("KAFKA_SASL_PASSWORD", "")
    kafka_cfg = {"bootstrap.servers": bootstrap_servers}
    if sasl_username and sasl_password:
        kafka_cfg.update({
            "security.protocol": "SASL_PLAINTEXT",
            "sasl.mechanism": "SCRAM-SHA-512",
            "sasl.username": sasl_username,
            "sasl.password": sasl_password,
        })
    producer = Producer(kafka_cfg)

    print(f"Sending {count} messages to topic '{topic}'...")
    for i in range(1, count + 1):
        value = json.dumps({"id": i, "message": f"work item {i} of {count}"})
        producer.produce(topic, key=str(uuid.uuid4()), value=value)
        producer.poll(0)
        print(f"\r  Sent {i} / {count}", end="")

    producer.flush()
    print(f"\n{count} messages sent. Watch the lag build in Kafka UI.")


if __name__ == "__main__":
    main()
