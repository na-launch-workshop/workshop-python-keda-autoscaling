import logging

from confluent_kafka import Consumer, TopicPartition

from app import config

log = logging.getLogger(__name__)


class LagReporter:
    """Reads committed offsets vs. end offsets so the dashboard can show lag."""

    def __init__(self) -> None:
        # A consumer that never subscribes: it only issues OffsetFetch / metadata
        # requests, so it never joins the consumer group or steals partitions.
        self._consumer = Consumer(
            {
                "bootstrap.servers": config.BOOTSTRAP_SERVERS,
                "group.id": config.CONSUMER_GROUP,
                "enable.auto.commit": False,
            }
        )

    def close(self) -> None:
        self._consumer.close()

    def status(self) -> dict:
        result = {"topic": config.TOPIC, "consumerGroup": config.CONSUMER_GROUP}

        try:
            partitions = [TopicPartition(config.TOPIC, p) for p in range(config.PARTITION_COUNT)]
            committed = self._consumer.committed(partitions, timeout=5.0)

            total_lag = 0
            lag_per_partition = {}
            for tp in committed:
                _, end_offset = self._consumer.get_watermark_offsets(tp, timeout=5.0, cached=False)
                committed_offset = tp.offset if tp.offset >= 0 else 0
                lag = max(0, end_offset - committed_offset)
                lag_per_partition[str(tp.partition)] = lag
                total_lag += lag

            result["totalLag"] = total_lag
            result["lagPerPartition"] = lag_per_partition
        except Exception as e:  # noqa: BLE001 - surface any Kafka problem to the dashboard
            log.warning("Unable to read lag: %s", e)
            result["totalLag"] = -1
            result["error"] = str(e)

        return result
