# Benchmark Aggregation Report

Generated: 2026-04-13 05:39:10

## Results Summary

### By Protocol and Concurrency

#### GRPC

**Payload Profile: heavy**

**Stage Concurrency: 50**

| VUs | Latency Avg (ms) | Latency p95 (ms) | Throughput (req/s) | Total Failure % |
|-----|---|---|---|---|
| 200 | 337.4 | 362.5 | 618.12 | 0.0 |
| 400 | 519.64 | 643.34 | 802.35 | 0.14 |
| 800 | 959.51 | 1150.0 | 864.12 | 31.9 |

**Stage Concurrency: 100**

| VUs | Latency Avg (ms) | Latency p95 (ms) | Throughput (req/s) | Total Failure % |
|-----|---|---|---|---|
| 200 | 373.18 | 412.29 | 558.99 | 0.0 |
| 400 | 571.38 | 629.97 | 731.11 | 0.1 |
| 800 | 984.92 | 1100.0 | 844.68 | 39.08 |

**Stage Concurrency: 150**

| VUs | Latency Avg (ms) | Latency p95 (ms) | Throughput (req/s) | Total Failure % |
|-----|---|---|---|---|
| 200 | 380.3 | 427.4 | 548.64 | 0.0 |
| 400 | 583.92 | 659.89 | 716.27 | 0.09 |
| 800 | 1000.0 | 1190.0 | 828.7 | 45.39 |

**Payload Profile: small**

**Stage Concurrency: 50**

| VUs | Latency Avg (ms) | Latency p95 (ms) | Throughput (req/s) | Total Failure % |
|-----|---|---|---|---|
| 100 | 210.0 | 219.67 | 501.18 | 0.0 |
| 200 | 222.14 | 240.29 | 944.51 | 0.0 |
| 400 | 402.18 | 408.52 | 1041.65 | 0.0 |
| 800 | 801.1 | 813.37 | 1040.57 | 0.0 |
| 1000 | 999.09 | 1010.0 | 1041.98 | 81.7 |

**Stage Concurrency: 100**

| VUs | Latency Avg (ms) | Latency p95 (ms) | Throughput (req/s) | Total Failure % |
|-----|---|---|---|---|
| 100 | 210.78 | 220.64 | 501.8 | 0.0 |
| 200 | 224.55 | 248.38 | 938.33 | 0.0 |
| 400 | 279.94 | 309.31 | 1503.9 | 0.0 |
| 800 | 507.69 | 568.34 | 1631.01 | 0.0 |
| 1000 | 637.05 | 727.58 | 1596.61 | 0.0 |

**Stage Concurrency: 150**

| VUs | Latency Avg (ms) | Latency p95 (ms) | Throughput (req/s) | Total Failure % |
|-----|---|---|---|---|
| 200 | 225.37 | 252.97 | 923.73 | 0.0 |
| 400 | 284.96 | 320.85 | 1460.86 | 0.0 |
| 800 | 507.09 | 567.8 | 1617.5 | 0.0 |

**Stage Concurrency: 10000**

| VUs | Latency Avg (ms) | Latency p95 (ms) | Throughput (req/s) | Total Failure % |
|-----|---|---|---|---|
| 100 | 208.48 | 216.69 | 481.86 | 0.0 |
| 200 | 218.97 | 234.54 | 923.57 | 0.0 |
| 400 | 281.62 | 316.88 | 1433.29 | 0.0 |
| 800 | 499.37 | 575.07 | 1602.07 | 0.0 |
| 1000 | 608.08 | 706.79 | 1604.46 | 0.0 |

#### RABBIT

**Payload Profile: heavy**

**Stage Concurrency: 100**

| VUs | Latency Avg (ms) | Latency p95 (ms) | Throughput (req/s) | Total Failure % |
|-----|---|---|---|---|
| 200 | 206.59 | 215.45 | 998.28 | 0.0 |
| 400 | 213.72 | 226.23 | 1927.59 | 0.0 |
| 800 | 409.99 | 431.39 | 1991.24 | 0.0 |

**Stage Concurrency: 150**

| VUs | Latency Avg (ms) | Latency p95 (ms) | Throughput (req/s) | Total Failure % |
|-----|---|---|---|---|
| 200 | 206.67 | 215.04 | 998.86 | 0.0 |
| 400 | 209.46 | 220.89 | 1969.99 | 0.0 |
| 800 | 288.52 | 314.15 | 2847.33 | 0.04 |

**Stage Concurrency: 10000**

| VUs | Latency Avg (ms) | Latency p95 (ms) | Throughput (req/s) | Total Failure % |
|-----|---|---|---|---|
| 200 | 206.69 | 215.47 | 1000.08 | 0.0 |
| 400 | 210.5 | 223.46 | 1961.68 | 0.0 |
| 800 | 269.71 | 307.69 | 3052.08 | 0.06 |

**Payload Profile: small**

**Stage Concurrency: 50**

| VUs | Latency Avg (ms) | Latency p95 (ms) | Throughput (req/s) | Total Failure % |
|-----|---|---|---|---|
| 100 | 208.89 | 242.24 | 497.95 | 0.0 |
| 200 | 211.87 | 255.96 | 977.8 | 0.0 |
| 400 | 402.84 | 415.91 | 1020.11 | 0.0 |
| 800 | 792.91 | 830.69 | 1019.21 | 0.01 |
| 1000 | 985.36 | 1046.67 | 1021.44 | 94.45 |

**Stage Concurrency: 100**

| VUs | Latency Avg (ms) | Latency p95 (ms) | Throughput (req/s) | Total Failure % |
|-----|---|---|---|---|
| 100 | 208.53 | 240.61 | 501.17 | 0.0 |
| 200 | 205.9 | 220.97 | 1010.24 | 0.0 |
| 400 | 210.21 | 225.06 | 1978.68 | 0.0 |
| 800 | 401.96 | 415.9 | 2048.38 | 0.0 |
| 1000 | 500.94 | 519.8 | 2055.16 | 0.0 |

**Stage Concurrency: 150**

| VUs | Latency Avg (ms) | Latency p95 (ms) | Throughput (req/s) | Total Failure % |
|-----|---|---|---|---|
| 100 | 208.38 | 237.66 | 503.31 | 0.0 |
| 200 | 205.99 | 221.49 | 1013.65 | 0.0 |
| 400 | 205.66 | 214.69 | 2030.41 | 0.0 |
| 800 | 269.53 | 296.82 | 3084.63 | 0.0 |
| 1000 | 335.92 | 357.83 | 3099.92 | 0.0 |

**Stage Concurrency: 10000**

| VUs | Latency Avg (ms) | Latency p95 (ms) | Throughput (req/s) | Total Failure % |
|-----|---|---|---|---|
| 100 | 210.12 | 232.78 | 474.63 | 0.0 |
| 200 | 207.34 | 219.84 | 969.84 | 0.0 |
| 400 | 206.7 | 213.18 | 1945.09 | 0.0 |
| 800 | 208.36 | 215.91 | 3856.54 | 0.0 |
| 1000 | 211.74 | 221.27 | 4704.65 | 0.01 |

#### REST

**Payload Profile: heavy**

**Stage Concurrency: 50**

| VUs | Latency Avg (ms) | Latency p95 (ms) | Throughput (req/s) | Total Failure % |
|-----|---|---|---|---|
| 200 | 330.77 | 365.28 | 620.17 | 0.11 |
| 400 | 673.78 | 710.95 | 601.38 | 0.74 |
| 800 | 1360.0 | 1250.0 | 587.66 | 42.63 |

**Stage Concurrency: 100**

| VUs | Latency Avg (ms) | Latency p95 (ms) | Throughput (req/s) | Total Failure % |
|-----|---|---|---|---|
| 200 | 319.59 | 351.28 | 638.38 | 0.0 |
| 400 | 673.42 | 719.21 | 602.37 | 0.74 |
| 800 | 1370.0 | 1310.0 | 581.18 | 47.49 |

**Stage Concurrency: 150**

| VUs | Latency Avg (ms) | Latency p95 (ms) | Throughput (req/s) | Total Failure % |
|-----|---|---|---|---|
| 200 | 330.38 | 365.05 | 621.82 | 0.17 |
| 400 | 665.68 | 707.73 | 610.09 | 0.73 |
| 800 | 1350.0 | 1250.0 | 588.99 | 41.48 |

**Stage Concurrency: 10000**

| VUs | Latency Avg (ms) | Latency p95 (ms) | Throughput (req/s) | Total Failure % |
|-----|---|---|---|---|
| 200 | 330.71 | 360.6 | 622.64 | 0.17 |
| 400 | 675.88 | 715.77 | 601.36 | 0.76 |
| 800 | 1380.0 | 1310.0 | 577.46 | 54.45 |

**Payload Profile: small**

**Stage Concurrency: 50**

| VUs | Latency Avg (ms) | Latency p95 (ms) | Throughput (req/s) | Total Failure % |
|-----|---|---|---|---|
| 100 | 202.84 | 207.87 | 511.57 | 0.0 |
| 200 | 247.9 | 268.24 | 833.32 | 0.03 |
| 400 | 509.01 | 544.25 | 802.95 | 0.41 |
| 800 | 1020.0 | 1077.5 | 785.88 | 26.96 |
| 1000 | 1273.33 | 1246.67 | 783.67 | 60.59 |

**Stage Concurrency: 100**

| VUs | Latency Avg (ms) | Latency p95 (ms) | Throughput (req/s) | Total Failure % |
|-----|---|---|---|---|
| 100 | 202.65 | 207.68 | 514.6 | 0.0 |
| 200 | 243.69 | 262.65 | 850.71 | 0.03 |
| 400 | 503.94 | 544.28 | 814.64 | 0.42 |
| 800 | 1004.58 | 1060.0 | 798.69 | 42.84 |
| 1000 | 1270.0 | 1133.33 | 788.89 | 30.25 |

**Stage Concurrency: 150**

| VUs | Latency Avg (ms) | Latency p95 (ms) | Throughput (req/s) | Total Failure % |
|-----|---|---|---|---|
| 100 | 202.73 | 207.72 | 516.54 | 0.0 |
| 200 | 241.4 | 260.38 | 861.52 | 0.01 |
| 400 | 506.22 | 543.83 | 812.9 | 0.43 |
| 800 | 1013.1 | 1067.5 | 795.55 | 26.77 |
| 1000 | 1283.33 | 1223.33 | 784.21 | 52.41 |

**Stage Concurrency: 10000**

| VUs | Latency Avg (ms) | Latency p95 (ms) | Throughput (req/s) | Total Failure % |
|-----|---|---|---|---|
| 100 | 202.92 | 208.15 | 517.72 | 0.0 |
| 200 | 245.88 | 265.79 | 848.98 | 0.01 |
| 400 | 503.95 | 542.37 | 810.93 | 0.4 |
| 800 | 1007.5 | 1062.5 | 789.88 | 24.41 |
| 1000 | 1270.0 | 1173.33 | 778.87 | 38.89 |

## Raw Result Files

- ./results/grpc/system-benchmark.csv (6289 bytes)
- ./results/rabbit/system-benchmark.csv (7699 bytes)
- ./results/rest/system-benchmark.csv (7837 bytes)

## Next Steps

1. Review the protocol tables and compare throughput vs p95 latency.
2. Check whether total failure rises at higher VU values for each protocol.
3. Compare behavior across stage concurrency values (100, 200, 10000).
