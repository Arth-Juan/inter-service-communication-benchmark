# Benchmark Matrix (Fair Comparison)

## Goal
Use the same per-stage concurrency cap in REST, gRPC and RabbitMQ.

## Fixed parameters
- Pipeline stages: 4 (validate -> antifraud -> authorize -> settle)
- Business logic per stage: 50ms
- Test duration per point: 1m
- Repetitions per point: 5
- Stage concurrency levels: 100, 200, 10000 (high cap)
- VU levels: set after Docker pilot (override via `VUS_LEVELS_CSV`)
- Failure threshold: requests above 1000ms count as SLO failures

## Matrix to run
Run every protocol with these `STAGE_CONCURRENCY` values:
- 100
- 200
- 10000

If you use 3 VU points after Docker pilot and 5 repetitions, that yields:
3 concurrency x 3 VU x 5 repetitions = 45 points per protocol.

## Commands
For each concurrency value C in {100,200,10000}:

```bash
REPETITIONS=5 STAGE_CONCURRENCY=C ./run-rest-benchmark.sh
REPETITIONS=5 STAGE_CONCURRENCY=C ./run-grpc-benchmark.sh
REPETITIONS=5 STAGE_CONCURRENCY=C ./run-rabbit-benchmark.sh
```

To change the latency threshold used to classify a slow request as failure:

```bash
FAILURE_THRESHOLD_MS=1000 REPETITIONS=5 STAGE_CONCURRENCY=C ./run-rest-benchmark.sh
FAILURE_THRESHOLD_MS=1000 REPETITIONS=5 STAGE_CONCURRENCY=C ./run-grpc-benchmark.sh
FAILURE_THRESHOLD_MS=1000 REPETITIONS=5 STAGE_CONCURRENCY=C ./run-rabbit-benchmark.sh
```

To set VU points after Docker pilot without editing scripts:

```bash
VUS_LEVELS_CSV=80,160,320 REPETITIONS=5 STAGE_CONCURRENCY=100 ./run-rest-benchmark.sh
VUS_LEVELS_CSV=80,160,320 REPETITIONS=5 STAGE_CONCURRENCY=100 ./run-grpc-benchmark.sh
VUS_LEVELS_CSV=80,160,320 REPETITIONS=5 STAGE_CONCURRENCY=100 ./run-rabbit-benchmark.sh
```

## Automated Full Benchmark (Recommended)

Run all protocols across all stage concurrency levels (100, 200, 10000) with a single command:

```bash
# Run with defaults (5 reps, VUs: 80/160/320)
./run-full-benchmark.sh

# Run with custom VU levels
./run-full-benchmark.sh --vus 50,100,200,400 --reps 5

# Output will be in ./benchmark-logs/ with detailed logging
```

This script will:
1. Build Docker images once with each stage concurrency level
2. Run all three protocols (REST, gRPC, RabbitMQ) for each concurrency level
3. Each protocol runs with all VU levels and repetitions automatically
4. Properly start/stop Docker services between runs to avoid interference
5. Log all activity to `./benchmark-logs/full-benchmark_TIMESTAMP.log`
6. Append results to CSV files in `./results/`

After the benchmark completes (takes several hours), aggregate and analyze results:

```bash
./aggregate-results.sh
```

This will:
- Compute statistics (mean, median, std dev, confidence intervals) across all 5 repetitions
- Group results by protocol, stage concurrency, and VU level
- Generate markdown summary with comparison tables
- Output saved to `./results/summary/`

## Manual Docker Workflow

If you prefer to run individual protocols manually:

Build containers once:

```bash
docker compose build
```

Run REST stack and benchmark against external services:

```bash
STAGE_CONCURRENCY=100 docker compose up -d rest-validation rest-antifraud rest-authorization rest-settle rest-payment
USE_EXTERNAL_SERVICES=true PAYMENT_URL=http://localhost:3000/payment VUS_LEVELS_CSV=80,160,320 REPETITIONS=5 STAGE_CONCURRENCY=100 ./run-rest-benchmark.sh
docker compose down
```

Run gRPC stack and benchmark against external services:

```bash
STAGE_CONCURRENCY=100 docker compose up -d grpc-validation grpc-antifraud grpc-authorization grpc-settle grpc-payment
USE_EXTERNAL_SERVICES=true PAYMENT_GRPC_TARGET=localhost:60000 VUS_LEVELS_CSV=80,160,320 REPETITIONS=5 STAGE_CONCURRENCY=100 ./run-grpc-benchmark.sh
docker compose down
```

Run Rabbit stack and benchmark against external services:

```bash
STAGE_CONCURRENCY=100 docker compose up -d rabbitmq rabbit-validation rabbit-antifraud rabbit-authorization rabbit-settle rabbit-broker
USE_EXTERNAL_SERVICES=true PAYMENT_URL=http://localhost:3005/payment VUS_LEVELS_CSV=80,160,320 REPETITIONS=5 STAGE_CONCURRENCY=100 ./run-rabbit-benchmark.sh
docker compose down
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
