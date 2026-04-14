#!/bin/bash
set -e   # sai se algum comando falhar

# Configurações
VUS_LEVELS=(200 400 800)
if [[ -n "${VUS_LEVELS_CSV:-}" ]]; then
  IFS=',' read -r -a VUS_LEVELS <<< "$VUS_LEVELS_CSV"
fi

DURATION="1m"
TEST_FILE="./src/grpc/grpcTest.js"
RESULT_DIR="./results/grpc"
CSV_FILE="$RESULT_DIR/system-benchmark.csv"
STAGE_CONCURRENCY="${STAGE_CONCURRENCY:-100}"
FAILURE_THRESHOLD_MS="${FAILURE_THRESHOLD_MS:-1000}"
REPETITIONS="${REPETITIONS:-5}"
STARTUP_WAIT_SECONDS="${STARTUP_WAIT_SECONDS:-10}"
COOLDOWN_SECONDS="${COOLDOWN_SECONDS:-10}"
USE_EXTERNAL_SERVICES="${USE_EXTERNAL_SERVICES:-false}"
PAYMENT_GRPC_TARGET="${PAYMENT_GRPC_TARGET:-localhost:60000}"
PAYLOAD_PROFILE="${PAYLOAD_PROFILE:-small}"
K6_API_ADDRESS="${K6_API_ADDRESS:-127.0.0.1:0}"
READINESS_RETRIES="${READINESS_RETRIES:-60}"
READINESS_SLEEP_SECONDS="${READINESS_SLEEP_SECONDS:-1}"

wait_for_grpc_ready() {
  local target="$1"
  local host="${target%:*}"
  local port="${target##*:}"

  for _ in $(seq 1 "$READINESS_RETRIES"); do
    if timeout 1 bash -lc "echo > /dev/tcp/${host}/${port}" >/dev/null 2>&1; then
      return 0
    fi
    sleep "$READINESS_SLEEP_SECONDS"
  done
  return 1
}

sample_grpc_cpu_sum_pct() {
  docker stats --no-stream --format '{{.Name}} {{.CPUPerc}}' 2>/dev/null | awk '
    /grpc-/ {
      gsub("%", "", $2);
      sum += ($2 + 0);
      found = 1;
    }
    END {
      if (found) {
        printf "%.2f\n", sum;
      } else {
        printf "0.00\n";
      }
    }
  '
}

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

# Cria cabeçalho apenas se o CSV ainda não existir.
if [[ ! -f "$CSV_FILE" ]]; then
  echo "vus,repetition,stage_concurrency,payload_profile,failure_threshold_ms,loadavg_1m,mem_used_mb,latency_avg_ms,latency_p95_ms,throughput_rps,transport_failure_pct,slow_failure_pct,total_failure_pct,grpc_cpu_avg_pct,grpc_cpu_peak_pct" > "$CSV_FILE"
else
  CURRENT_HEADER=$(head -n 1 "$CSV_FILE")
  if [[ "$CURRENT_HEADER" != *"grpc_cpu_avg_pct"* || "$CURRENT_HEADER" != *"payload_profile"* ]]; then
    TMP_CSV=$(mktemp)
    echo "vus,repetition,stage_concurrency,payload_profile,failure_threshold_ms,loadavg_1m,mem_used_mb,latency_avg_ms,latency_p95_ms,throughput_rps,transport_failure_pct,slow_failure_pct,total_failure_pct,grpc_cpu_avg_pct,grpc_cpu_peak_pct" > "$TMP_CSV"
    tail -n +2 "$CSV_FILE" | awk -F',' 'NF > 0 { print $1 "," $2 "," $3 ",small," $4 "," $5 "," $6 "," $7 "," $8 "," $9 "," $10 "," $11 "," $12 ",NA,NA" }' >> "$TMP_CSV"
    mv "$TMP_CSV" "$CSV_FILE"
  fi
fi

for VUS in "${VUS_LEVELS[@]}"
do
  for REP in $(seq 1 "$REPETITIONS")
  do
    echo "==========================================="
    echo "Running Test with $VUS VUs (repetition $REP/$REPETITIONS)"
    echo "==========================================="

    RUN_DIR="$RESULT_DIR/stage-${STAGE_CONCURRENCY}/payload-${PAYLOAD_PROFILE}/${VUS}VUs/repeat-${REP}"
    mkdir -p "$RUN_DIR"

    SUMMARY_FILE="$RUN_DIR/${VUS}vus-summary.txt"
    JSON_FILE="$RUN_DIR/${VUS}vus.json"

    # 1️ Inicia serviços gRPC
    if [[ "$USE_EXTERNAL_SERVICES" != "true" ]]; then
      STAGE_CONCURRENCY="$STAGE_CONCURRENCY" npm run start:grpc &
      # 2️ Espera os serviços estarem prontos
      echo "Aguardando PaymentService gRPC iniciar..."
      sleep "$STARTUP_WAIT_SECONDS"
    else
      echo "Aguardando endpoint gRPC ficar pronto em $PAYMENT_GRPC_TARGET..."
      if ! wait_for_grpc_ready "$PAYMENT_GRPC_TARGET"; then
        echo "Endpoint gRPC não ficou pronto em tempo hábil: $PAYMENT_GRPC_TARGET"
        exit 1
      fi
    fi

    # 3️ Mede loadavg/mem antes do teste
    LOADAVG=$(awk '{print $1}' /proc/loadavg)
    MEM_USED=$(free -m | awk '/Mem:/ {print $3}')

    # 4️ Executa k6
    CPU_SAMPLE_FILE=""
    CPU_SAMPLER_PID=""

    if [[ "$USE_EXTERNAL_SERVICES" == "true" ]]; then
      CPU_SAMPLE_FILE=$(mktemp)
    fi

    FAILURE_THRESHOLD_MS="$FAILURE_THRESHOLD_MS" PAYMENT_GRPC_TARGET="$PAYMENT_GRPC_TARGET" PAYLOAD_PROFILE="$PAYLOAD_PROFILE" k6 run "$TEST_FILE" --address "$K6_API_ADDRESS" --vus "$VUS" --duration "$DURATION" --out json="$JSON_FILE" > "$SUMMARY_FILE" &
    K6_PID=$!

    if [[ "$USE_EXTERNAL_SERVICES" == "true" ]]; then
      (
        while kill -0 "$K6_PID" 2>/dev/null; do
          sample_grpc_cpu_sum_pct >> "$CPU_SAMPLE_FILE" || true
          sleep 1
        done
      ) &
      CPU_SAMPLER_PID=$!
    fi

    wait "$K6_PID"

    if [[ -n "$CPU_SAMPLER_PID" ]]; then
      wait "$CPU_SAMPLER_PID" 2>/dev/null || true
    fi

    # 5️ Atualiza loadavg/mem durante teste
    LOADAVG=$(awk '{print $1}' /proc/loadavg)
    MEM_USED=$(free -m | awk '/Mem:/ {print $3}')

    # 6️ Extrai latência do summary
    LATENCY_AVG=$(extract_trend_stat "$SUMMARY_FILE" "grpc_req_duration" "avg")
    LATENCY_P95=$(extract_trend_stat "$SUMMARY_FILE" "grpc_req_duration" "p(95)")
    THROUGHPUT=$(extract_counter_rate "$SUMMARY_FILE" "iterations")
    TRANSPORT_FAILURE_PCT=$(extract_rate_pct "$SUMMARY_FILE" "benchmark_transport_failure_rate")
    SLOW_FAILURE_PCT=$(extract_rate_pct "$SUMMARY_FILE" "benchmark_slow_failure_rate")
    TOTAL_FAILURE_PCT=$(extract_rate_pct "$SUMMARY_FILE" "benchmark_total_failure_rate")

    GRPC_CPU_AVG_PCT=""
    GRPC_CPU_PEAK_PCT=""
    if [[ -n "$CPU_SAMPLE_FILE" && -s "$CPU_SAMPLE_FILE" ]]; then
      GRPC_CPU_AVG_PCT=$(awk '{sum+=$1; n++} END { if (n>0) printf "%.2f", sum/n; else printf "0.00" }' "$CPU_SAMPLE_FILE")
      GRPC_CPU_PEAK_PCT=$(awk 'BEGIN {max=0} { if ($1+0 > max) max=$1+0 } END { printf "%.2f", max }' "$CPU_SAMPLE_FILE")
    else
      GRPC_CPU_AVG_PCT="NA"
      GRPC_CPU_PEAK_PCT="NA"
    fi

    if [[ -n "$CPU_SAMPLE_FILE" ]]; then
      rm -f "$CPU_SAMPLE_FILE"
    fi

    # 7️ Adiciona linha no CSV
    echo "$VUS,$REP,$STAGE_CONCURRENCY,$PAYLOAD_PROFILE,$FAILURE_THRESHOLD_MS,$LOADAVG,$MEM_USED,$LATENCY_AVG,$LATENCY_P95,$THROUGHPUT,$TRANSPORT_FAILURE_PCT,$SLOW_FAILURE_PCT,$TOTAL_FAILURE_PCT,$GRPC_CPU_AVG_PCT,$GRPC_CPU_PEAK_PCT" >> "$CSV_FILE"

    # 8️ Finaliza serviços gRPC
    if [[ "$USE_EXTERNAL_SERVICES" != "true" ]]; then
      echo "Finalizando serviços gRPC..."
      kill -15 $(lsof -ti :50051) $(lsof -ti :50052) $(lsof -ti :50053) $(lsof -ti :50054) $(lsof -ti :60000) 2>/dev/null
    fi
    sleep "$COOLDOWN_SECONDS"
  done
done

echo "==========================================="
echo "Benchmark gRPC finalizado. CSV consolidado: $CSV_FILE"