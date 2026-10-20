import logging
import threading
import time
from datetime import datetime, timezone

from confluent_kafka import Consumer, KafkaError

from app import config

log = logging.getLogger(__name__)


class KafkaEventConsumer:
    """Consumes `keda-events` on a background thread, slowly, to simulate work."""

    def __init__(self) -> None:
        self._stop = threading.Event()
        self._thread = threading.Thread(target=self._run, name="kafka-consumer", daemon=True)

    def start(self) -> None:
        self._thread.start()

    def stop(self) -> None:
        self._stop.set()
        self._thread.join(timeout=30)

    def _run(self) -> None:
        consumer = Consumer(
            {
                "bootstrap.servers": config.BOOTSTRAP_SERVERS,
                "group.id": config.CONSUMER_GROUP,
                "auto.offset.reset": "earliest",
                "enable.auto.commit": True,
                "max.poll.interval.ms": 300000,
            }
        )
        consumer.subscribe([config.TOPIC])
        log.info("Subscribed to %s as %s", config.TOPIC, config.CONSUMER_GROUP)

        try:
            while not self._stop.is_set():
                msg = consumer.poll(1.0)
                if msg is None:
                    continue
                if msg.error():
                    if msg.error().code() != KafkaError._PARTITION_EOF:
                        log.error("Consumer error: %s", msg.error())
                    continue

                value = msg.value().decode("utf-8", errors="replace")
                log.info("Processing: %s", value)
                time.sleep(config.PROCESSING_DELAY_MS / 1000.0)
                log.info("Completed at %s: %s", datetime.now(timezone.utc).isoformat(), value)
        finally:
            consumer.close()
            log.info("Consumer closed")
