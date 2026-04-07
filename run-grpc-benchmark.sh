#!/bin/bash
set -e   # sai se algum comando falhar

# Configurações
VUS_LEVELS=(50 200 400 800 1200 1600)
DURATION="1m"
TEST_FILE="./src/grpc/grpcTest.js"
RESULT_DIR="./results/grpc"
CSV_FILE="$RESULT_DIR/system-benchmark.csv"
STAGE_CONCURRENCY="${STAGE_CONCURRENCY:-50}"
FAILURE_THRESHOLD_MS="${FAILURE_THRESHOLD_MS:-1000}"

extract_metric_line() {
  local summary_file="$1"
  local metric_name="$2"
  grep -E "^[[:space:]]*${metric_name}[.[:space:]]*:" "$summary_file"
}

extract_trend_stat() {
  local summary_file="$1"
  local metric_name="$2"
  local stat_name="$3"
  extract_metric_line "$summary_file" "$metric_name" | awk -v stat_name="$stat_name" '{for (i = 1; i <= NF; i++) { if (index($i, stat_name "=") == 1) { split($i, a, "="); print a[2]; exit } }}'
}

extract_rate_pct() {
  local summary_file="$1"
  local metric_name="$2"
  extract_metric_line "$summary_file" "$metric_name" | awk '{for (i = 1; i <= NF; i++) { if ($i ~ /%$/) { print $i; exit } }}'
}

extract_counter_rate() {
  local summary_file="$1"
  local metric_name="$2"
  extract_metric_line "$summary_file" "$metric_name" | awk '{for (i = 1; i <= NF; i++) { if ($i ~ /\/s$/) { value = $i; sub("/s", "", value); print value; exit } }}'
}

mkdir -p "$RESULT_DIR"

# CSV consolidado
echo "vus,stage_concurrency,failure_threshold_ms,loadavg_1m,mem_used_mb,latency_avg_ms,latency_p95_ms,throughput_rps,transport_failure_pct,slow_failure_pct,total_failure_pct" > "$CSV_FILE"

for VUS in "${VUS_LEVELS[@]}"
do
  echo "==========================================="
  echo "Running Test with $VUS VUs"
  echo "==========================================="

  mkdir -p "$RESULT_DIR/${VUS}VUs"

  SUMMARY_FILE="$RESULT_DIR/${VUS}VUs/${VUS}vus-summary.txt"
  JSON_FILE="$RESULT_DIR/${VUS}VUs/${VUS}vus.json"

  # 1️ Inicia serviços gRPC
  STAGE_CONCURRENCY="$STAGE_CONCURRENCY" npm run start:grpc &
  # 2️ Espera os serviços estarem prontos
  echo "Aguardando PaymentService gRPC iniciar..."
  sleep 10
  

  # 3️ Mede loadavg/mem antes do teste
  LOADAVG=$(awk '{print $1}' /proc/loadavg)
  MEM_USED=$(free -m | awk '/Mem:/ {print $3}')

  # 4️ Executa k6
  FAILURE_THRESHOLD_MS="$FAILURE_THRESHOLD_MS" k6 run "$TEST_FILE" --vus "$VUS" --duration "$DURATION" --out json="$JSON_FILE" > "$SUMMARY_FILE"

  # 5️ Atualiza loadavg/mem durante teste
  LOADAVG=$(awk '{print $1}' /proc/loadavg)
  MEM_USED=$(free -m | awk '/Mem:/ {print $3}')

  # 6️ Extrai latência do JSON (mais confiável que summary)
  LATENCY_AVG=$(extract_trend_stat "$SUMMARY_FILE" "grpc_req_duration" "avg")
  LATENCY_P95=$(extract_trend_stat "$SUMMARY_FILE" "grpc_req_duration" "p(95)")
  THROUGHPUT=$(extract_counter_rate "$SUMMARY_FILE" "iterations")
  TRANSPORT_FAILURE_PCT=$(extract_rate_pct "$SUMMARY_FILE" "benchmark_transport_failure_rate")
  SLOW_FAILURE_PCT=$(extract_rate_pct "$SUMMARY_FILE" "benchmark_slow_failure_rate")
  TOTAL_FAILURE_PCT=$(extract_rate_pct "$SUMMARY_FILE" "benchmark_total_failure_rate")

  # 7️ Adiciona linha no CSV
  echo "$VUS,$STAGE_CONCURRENCY,$FAILURE_THRESHOLD_MS,$LOADAVG,$MEM_USED,$LATENCY_AVG,$LATENCY_P95,$THROUGHPUT,$TRANSPORT_FAILURE_PCT,$SLOW_FAILURE_PCT,$TOTAL_FAILURE_PCT" >> "$CSV_FILE"

  # 8️ Finaliza serviços gRPC
  echo "Finalizando serviços gRPC..."
  kill -15 $(lsof -ti :50051) $(lsof -ti :50052) $(lsof -ti :50053) $(lsof -ti :50054) $(lsof -ti :60000) 2>/dev/null
  sleep 10   # pausa antes do próximo teste
done

echo "==========================================="
echo "Benchmark gRPC finalizado. CSV consolidado: $CSV_FILE"