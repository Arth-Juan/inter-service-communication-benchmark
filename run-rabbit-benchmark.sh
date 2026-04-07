#!/bin/bash

VUS_LEVELS=(50 200 400 800 1200 1600)
DURATION="1m"
TEST_FILE="./src/rabbit/rabbitTest.js"
RESULT_DIR="./results/rabbit"
CSV_FILE="$RESULT_DIR/system-benchmark.csv"
STAGE_CONCURRENCY="${STAGE_CONCURRENCY:-50}"

mkdir -p "$RESULT_DIR"

echo "vus,stage_concurrency,loadavg_1m,mem_used_mb,latency_avg_ms,latency_p95_ms,throughput_rps" > "$CSV_FILE"

for VUS in "${VUS_LEVELS[@]}"
do
  echo "==========================================="
  echo "Running RabbitMQ Test with $VUS VUs"
  echo "==========================================="

  mkdir -p "$RESULT_DIR/${VUS}VUs"

  SUMMARY_FILE="$RESULT_DIR/${VUS}VUs/${VUS}vus-summary.txt"
  JSON_FILE="$RESULT_DIR/${VUS}VUs/${VUS}vus.json"

  # Start Rabbit services
  STAGE_CONCURRENCY="$STAGE_CONCURRENCY" npm run start:rabbit &
  
  echo "Aguardando serviços Rabbit iniciarem..."
  sleep 10

  # Métricas antes
  LOADAVG=$(awk '{print $1}' /proc/loadavg)
  MEM_USED=$(free -m | awk '/Mem:/ {print $3}')

  # Run k6
  k6 run "$TEST_FILE" --vus "$VUS" --duration "$DURATION" --out json="$JSON_FILE" > "$SUMMARY_FILE"

  # Métricas depois
  LOADAVG=$(awk '{print $1}' /proc/loadavg)
  MEM_USED=$(free -m | awk '/Mem:/ {print $3}')

  LATENCY_AVG=$(grep "http_req_duration" "$SUMMARY_FILE" | awk '{for(i=1;i<=NF;i++){if($i ~ /^avg=/){split($i,a,"="); print a[2]}}}')
  LATENCY_P95=$(grep "http_req_duration" "$SUMMARY_FILE" | awk '{for(i=1;i<=NF;i++){if($i ~ /^p\(95\)=/){split($i,a,"="); print a[2]}}}')
  THROUGHPUT=$(grep "http_reqs\." "$SUMMARY_FILE" | awk '{for(i=1;i<=NF;i++){if($i ~ /\/s$/){sub("/s","",$i); print $i; exit}}}')

  echo "$VUS,$STAGE_CONCURRENCY,$LOADAVG,$MEM_USED,$LATENCY_AVG,$LATENCY_P95,$THROUGHPUT" >> "$CSV_FILE"

  echo "Finalizando serviços Rabbit..."
  pkill -f baseRabbitService
  pkill -f brokerService

  sleep 10
done

echo "==========================================="
echo "Benchmark Rabbit finalizado. CSV: $CSV_FILE"