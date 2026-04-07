# Benchmark Matrix (Fair Comparison)

## Goal
Use the same per-stage concurrency cap in REST, gRPC and RabbitMQ.

## Fixed parameters
- Pipeline stages: 4 (validate -> antifraud -> authorize -> settle)
- Business logic per stage: 50ms
- Test duration per point: 1m
- VU levels: 50, 200, 400, 800, 1200, 1600
- Failure threshold: requests above 1000ms count as SLO failures

## Matrix to run
Run every protocol with these `STAGE_CONCURRENCY` values:
- 10
- 25
- 50
- 100

This yields 4 x 6 = 24 points per protocol.

## Commands
For each concurrency value C in {10,25,50,100}:

```bash
STAGE_CONCURRENCY=C ./run-rest-benchmark.sh
STAGE_CONCURRENCY=C ./run-grpc-benchmark.sh
STAGE_CONCURRENCY=C ./run-rabbit-benchmark.sh
```

To change the latency threshold used to classify a slow request as failure:

```bash
FAILURE_THRESHOLD_MS=1000 STAGE_CONCURRENCY=C ./run-rest-benchmark.sh
FAILURE_THRESHOLD_MS=1000 STAGE_CONCURRENCY=C ./run-grpc-benchmark.sh
FAILURE_THRESHOLD_MS=1000 STAGE_CONCURRENCY=C ./run-rabbit-benchmark.sh
```

## How simultaneous requests are capped
- REST: semaphore in each stage service handler.
- gRPC: semaphore in each stage RPC method.
- RabbitMQ: `channel.prefetch(STAGE_CONCURRENCY)` in each worker stage.

## Interpreting throughput
A rough upper bound per stage with 50ms service time is:

Throughput_stage ~= STAGE_CONCURRENCY / 0.05 = 20 * STAGE_CONCURRENCY req/s

Because the pipeline has equal stages, system throughput tends to bottleneck near that value (minus protocol overhead and queueing effects).

## Anti-bias rule
Never change `STAGE_CONCURRENCY` for only one protocol. Always compare at the same value.
