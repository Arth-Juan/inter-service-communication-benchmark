#!/bin/bash

# Configurações
VUS_LEVELS=(50 200 400 800 1200 1600)
DURATION="1m"
TEST_FILE="./src/rest/restTest.js"
RESULT_DIR="./results/rest"
CSV_FILE="$RESULT_DIR/system-benchmark.csv"
STAGE_CONCURRENCY="${STAGE_CONCURRENCY:-50}"

mkdir -p "$RESULT_DIR"

# Cria CSV consolidado
echo "vus,stage_concurrency,loadavg_1m,mem_used_mb,latency_avg_ms,latency_p95_ms,throughput_rps" > "$CSV_FILE"

for VUS in "${VUS_LEVELS[@]}"
do
  echo "==========================================="
  echo "Running Test with $VUS VUs"
  echo "==========================================="

  mkdir -p "$RESULT_DIR/${VUS}VUs"

  SUMMARY_FILE="$RESULT_DIR/${VUS}VUs/${VUS}vus-summary.txt"
  JSON_FILE="$RESULT_DIR/${VUS}VUs/${VUS}vus.json"

  # 1️ Initiate all REST Services
  STAGE_CONCURRENCY="$STAGE_CONCURRENCY" npm run start:rest &
  echo "Aguardando PaymentService REST iniciar..."
  # 2️ Await Node UP
  sleep 10

  # 3️ Measure loadavg e memory before test
  LOADAVG=$(awk '{print $1}' /proc/loadavg)
  MEM_USED=$(free -m | awk '/Mem:/ {print $3}')

  # 4️ Run  k6
  k6 run "$TEST_FILE" --vus "$VUS" --duration "$DURATION" --out json="$JSON_FILE" > "$SUMMARY_FILE"

  # 5️ Update loadavg/mem during test
  LOADAVG=$(awk '{print $1}' /proc/loadavg)
  MEM_USED=$(free -m | awk '/Mem:/ {print $3}')

  # 6️ Extrai latência do summary
  LATENCY_AVG=$(grep "http_req_duration..............:" "$SUMMARY_FILE" | awk '{for(i=1;i<=NF;i++){if($i ~ /^avg=/){split($i,a,"="); print a[2]}}}')
  LATENCY_P95=$(grep "http_req_duration..............:" "$SUMMARY_FILE" | awk '{for(i=1;i<=NF;i++){if($i ~ /^p\(95\)=/){split($i,a,"="); print a[2]}}}')
  THROUGHPUT=$(grep "http_reqs\." "$SUMMARY_FILE" | awk '{for(i=1;i<=NF;i++){if($i ~ /\/s$/){sub("/s","",$i); print $i; exit}}}')

  # 7️ Adiciona linha no CSV
  echo "$VUS,$STAGE_CONCURRENCY,$LOADAVG,$MEM_USED,$LATENCY_AVG,$LATENCY_P95,$THROUGHPUT" >> "$CSV_FILE"

  # 8️ Mata os serviços REST
  echo "Finalizando serviços REST..."
  kill -15 $(lsof -ti :3001) $(lsof -ti :3002) $(lsof -ti :3003) $(lsof -ti :3004) $(lsof -ti :3000) 2>/dev/null
  sleep 10   # pausa para resfriamento antes do próximo teste
  done

echo "==========================================="
echo "Benchmark REST finalizado. CSV consolidado: $CSV_FILE"