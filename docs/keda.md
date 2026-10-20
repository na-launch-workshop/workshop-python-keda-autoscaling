# KEDA

KEDA scales a deployment from zero to many replicas based on external signals.

In this workshop the signal is Kafka lag:

- the REST API publishes events
- the worker processes them slowly
- backlog builds in Kafka
- KEDA increases replicas
- backlog drains and replicas fall back down

KEDA Kafka scaler reference:

https://keda.sh/docs/latest/scalers/apache-kafka/
