# Comparative Study of Inter-Microservice Communication Patterns
## Performance Benchmark: REST vs gRPC vs RabbitMQ

---

## Abstract

This study evaluates and compares three communication patterns commonly used between microservices: synchronous HTTP/REST, synchronous RPC via gRPC, and asynchronous message-passing via RabbitMQ. A controlled pipeline simulation of four sequential payment processing stages (validation, anti-fraud, authorization, settlement) is used as the experimental workload. Each stage performs a fixed 50ms simulated operation under a bounded concurrency cap, ensuring protocol-agnostic fairness. Load is varied across six levels (50–1600 virtual users) and key performance indicators — throughput, latency, and system resource usage — are collected and compared across protocols.

> **NOTE:** Results currently reflect a single run at STAGE_CONCURRENCY=200. Final abstract values should be updated after repeated trials and full matrix execution.

---

## 1. Introduction

Microservice architectures must choose a communication strategy that balances performance, reliability, and operational complexity. REST over HTTP/1.1 remains the most widely adopted pattern due to its simplicity. gRPC leverages HTTP/2 and Protocol Buffers for lower-overhead binary communication. Message brokers like RabbitMQ decouple producers and consumers, enabling asynchronous flows with explicit backpressure via queue semantics.

This study does not evaluate architectural fitness or operational complexity. Its sole focus is comparative performance behavior under controlled load.

**Research Question:**  
Under equal concurrency caps and equivalent business logic, how do REST, gRPC, and RabbitMQ differ in throughput, latency distribution, and resource usage as offered load increases?

**Hypotheses:**
1. gRPC will exhibit lower median and tail latency than REST at equal VU levels due to HTTP/2 multiplexing and binary serialization.
2. RabbitMQ will sustain competitive throughput at high load but with higher and less predictable end-to-end latency due to broker intermediation.
3. All three protocols will exhibit a saturation knee point beyond which throughput plateaus and latency increases sharply.

---

## 2. Methodology

### 2.1 System Under Test

A four-stage payment pipeline built in Node.js (TypeScript):

| Stage       | Port (REST) | Port (gRPC) | Queue (Rabbit)    |
|-------------|-------------|-------------|-------------------|
| Validation  | 3001        | 50051       | validation_queue  |
| Anti-fraud  | 3002        | 50052       | antifraud_queue   |
| Authorization| 3003       | 50053       | authorization_queue|
| Settlement  | 3004        | 50054       | settle_queue      |

Each stage simulates work with `sleep(50ms)`. Concurrency is bounded by:
- REST/gRPC: `AsyncSemaphore(STAGE_CONCURRENCY)` per stage handler.
- RabbitMQ: `channel.prefetch(STAGE_CONCURRENCY)` per consumer.

### 2.2 Load Generator

k6 (version: _TODO: pin version_) with a closed-loop model. Each virtual user (VU) executes requests sequentially without artificial inter-request think time.

VU levels tested: **50, 200, 400, 800, 1200, 1600**  
Test duration per level: **60 seconds**  
Warm-up: _TODO: none currently — warm-up period not yet isolated_

### 2.3 Fixed Parameters

| Parameter             | Value          |
|-----------------------|----------------|
| Stage count           | 4              |
| Business logic/stage  | 50ms sleep     |
| Stage Concurrency     | 200            |
| Test duration         | 60s per level  |
| Payload               | `{ orderId: "123" }` |
| Host                  | localhost      |
| Repetitions per point | 1 _(TODO: increase to ≥3)_ |

### 2.4 Metrics Collected

| Metric            | Unit   | Source         |
|-------------------|--------|----------------|
| Throughput        | req/s  | k6 iterations  |
| Latency avg       | ms     | k6 summary     |
| Latency p95       | ms     | k6 summary     |
| Load average (1m) | -      | /proc/loadavg  |
| Memory used       | MB     | free -m        |

> **NOTE:** p99 latency is not currently captured. Queue depth / message lag is not currently captured for RabbitMQ.

---

## 3. Results

### 3.1 Throughput (req/s) — STAGE_CONCURRENCY=200

| VUs  | REST       | gRPC       | RabbitMQ   |
|------|------------|------------|------------|
| 50   | 265.34     | 260.21     | 209.19     |
| 200  | 1036.99    | 933.33     | 790.85     |
| 400  | 1365.36    | 1734.80    | 1400.54    |
| 800  | 1331.71    | 2458.83    | 2216.43    |
| 1200 | 1320.52    | 2454.98    | 2242.67    |
| 1600 | 1310.81    | 2432.64    | 2245.69    |

### 3.2 Average Latency (ms) — STAGE_CONCURRENCY=200

| VUs  | REST    | gRPC    | RabbitMQ |
|------|---------|---------|----------|
| 50   | 203.57  | 208.86  | 258.31   |
| 200  | 208.30  | 232.78  | 272.52   |
| 400  | 315.23  | 249.57  | 296.03   |
| 800  | 631.24  | 348.98  | 385.01   |
| 1200 | 922.45  | 513.56  | 568.31   |
| 1600 | 1130.00 | 642.46  | 744.82   |

### 3.3 p95 Latency (ms) — STAGE_CONCURRENCY=200

| VUs  | REST    | gRPC    | RabbitMQ |
|------|---------|---------|----------|
| 50   | 208.59  | 216.68  | 303.45   |
| 200  | 216.43  | 264.75  | 340.68   |
| 400  | 333.71  | 286.03  | 352.23   |
| 800  | 655.44  | 384.40  | 439.14   |
| 1200 | 889.34  | 580.45  | 628.86   |
| 1600 | 897.79  | 763.46  | 830.98   |

### 3.4 Memory Usage (MB)

| VUs  | REST  | gRPC  | RabbitMQ |
|------|-------|-------|----------|
| 50   | 2660  | 2932  | 2664     |
| 200  | 2884  | 3321  | 2757     |
| 400  | 2940  | 3417  | 2888     |
| 800  | 3016  | 3546  | 2984     |
| 1200 | 3091  | 3610  | 3035     |
| 1600 | 3071  | 3712  | 3052     |

### 3.5 Observations

- REST throughput saturates early (~1365 req/s at 400 VUs) and degrades slightly at higher load, with latency growing steeply.
- gRPC achieves the highest throughput (~2458 req/s at 800 VUs), consistent with HTTP/2 multiplexing benefits, and maintains the lowest latency under heavy load.
- RabbitMQ achieves competitive throughput (~2245 req/s) with moderate latency growth, consistent with broker-side buffering absorbing burst load.
- All three protocols show a saturation knee between 400–800 VUs at this concurrency level.

> **NOTE:** These observations are from a single run. Conclusions should not be finalized until multiple repetitions are available and variance is documented.

---

## 4. Threats to Validity

### 4.1 Internal Validity
- Single run per data point. Results may reflect transient system noise.
- Load average metric is captured at a single snapshot, not averaged over the full test window.
- Warm-up phase is not isolated; early iterations may inflate latency averages.
- gRPC k6 test reconnects on error, which may artificially reduce measured error rates.

### 4.2 Construct Validity
- Latency definition differs across protocols:
  - REST/gRPC: time from k6 request send to response received (client-side round-trip).
  - RabbitMQ: time from HTTP request to producer through broker pipeline to final HTTP response back (broker add latency that REST/gRPC don't have in the same path).
- Throughput in RabbitMQ is measured at the k6/HTTP producer level, not at the final consumer ack level.

### 4.3 External Validity
- All services run on localhost. Real network latency, TLS, and infrastructure variability are not present.
- Workload is synthetic (fixed sleep). Real CPU, I/O, serialization, and DB contention are not modeled.
- k6 uses a closed-loop model; open-loop arrival patterns may yield different saturation behavior.

---

## 5. Conclusion

_TODO: Write after final multi-run data is available._

Preliminary findings suggest:
- gRPC is the highest-throughput option under sustained high load in this setup, benefiting from HTTP/2 connection reuse and binary framing.
- REST saturates earlier and shows steeper latency growth, consistent with HTTP/1.1 per-request connection overhead.
- RabbitMQ demonstrates stable throughput under high load comparable to gRPC, with a latency floor elevated by broker round-trip, but with the structural advantage of decoupled producers and consumers (not measurable in this synchronous benchmark design).

---

## 6. Reproducibility

### Software Versions
- Node.js: _TODO: document_
- k6: _TODO: document_
- RabbitMQ: _TODO: document_
- amqplib: _TODO: document_
- @grpc/grpc-js: _TODO: document_

### Run Commands
```bash
STAGE_CONCURRENCY=200 ./run-rest-benchmark.sh
STAGE_CONCURRENCY=200 ./run-grpc-benchmark.sh
STAGE_CONCURRENCY=200 ./run-rabbit-benchmark.sh
```

### Raw Data
Results stored under `results/rest/`, `results/grpc/`, `results/rabbit/` per VU level.

---

*Study conducted as part of Software Engineer certification requirements — April 2026.*
