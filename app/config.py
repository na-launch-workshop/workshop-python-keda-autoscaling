import os

BOOTSTRAP_SERVERS = os.getenv("KAFKA_BOOTSTRAP_SERVERS", "kafka-kafka-bootstrap:9092")
TOPIC = os.getenv("KAFKA_TOPIC", "keda-events")
CONSUMER_GROUP = os.getenv("KAFKA_CONSUMER_GROUP", "keda-consumer-group")

# Slow processing is deliberate — it is what lets a backlog build up in Kafka.
PROCESSING_DELAY_MS = int(os.getenv("DEMO_PROCESSING_DELAY_MS", "2500"))

# Partition count of the keda-events topic, used when reporting lag.
PARTITION_COUNT = int(os.getenv("KAFKA_PARTITION_COUNT", "5"))

PORT = int(os.getenv("PORT", "8080"))
