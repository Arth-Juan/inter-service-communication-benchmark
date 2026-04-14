#!/bin/bash

VUS_LEVELS=(200 400 800)
if [[ -n "${VUS_LEVELS_CSV:-}" ]]; then
  IFS=',' read -r -a VUS_LEVELS <<< "$VUS_LEVELS_CSV"
fi

DURATION="1m"
TEST_FILE="./src/rabbit/rabbitTest.js"
RESULT_DIR="./results/rabbit"
CSV_FILE="$RESULT_DIR/system-benchmark.csv"
STAGE_CONCURRENCY="${STAGE_CONCURRENCY:-100}"
FAILURE_THRESHOLD_MS="${FAILURE_THRESHOLD_MS:-1000}"
REPETITIONS="${REPETITIONS:-5}"
STARTUP_WAIT_SECONDS="${STARTUP_WAIT_SECONDS:-10}"
COOLDOWN_SECONDS="${COOLDOWN_SECONDS:-10}"
USE_EXTERNAL_SERVICES="${USE_EXTERNAL_SERVICES:-false}"
PAYMENT_URL="${PAYMENT_URL:-http://localhost:3000/payment}"
PAYLOAD_PROFILE="${PAYLOAD_PROFILE:-small}"
RABBIT_INGRESS_MODE="${RABBIT_INGRESS_MODE:-native}"
RABBIT_INGRESS_MAX_INFLIGHT="${RABBIT_INGRESS_MAX_INFLIGHT:-$STAGE_CONCURRENCY}"
K6_API_ADDRESS="${K6_API_ADDRESS:-127.0.0.1:0}"
READINESS_RETRIES="${READINESS_RETRIES:-60}"
READINESS_SLEEP_SECONDS="${READINESS_SLEEP_SECONDS:-1}"

wait_for_http_ready() {
  local url="$1"
  for _ in $(seq 1 "$READINESS_RETRIES"); do
    if curl -fsS -m 2 -X POST -H 'Content-Type: application/json' -d '{"orderId":"readiness"}' "$url" >/dev/null 2>&1; then
      return 0
    fi
    sleep "$READINESS_SLEEP_SECONDS"
  done
  return 1
}

sample_rabbit_cpu_sum_pct() {
  docker stats --no-stream --format '{{.Name}} {{.CPUPerc}}' 2>/dev/null | awk '
    /rabbit-/ || /bench-rabbitmq/ {
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

if [[ ! -f "$CSV_FILE" ]]; then
  echo "vus,repetition,stage_concurrency,payload_profile,rabbit_ingress_mode,rabbit_ingress_max_inflight,failure_threshold_ms,loadavg_1m,mem_used_mb,latency_avg_ms,latency_p95_ms,throughput_rps,transport_failure_pct,slow_failure_pct,total_failure_pct,rabbit_cpu_avg_pct,rabbit_cpu_peak_pct" > "$CSV_FILE"
else
  CURRENT_HEADER=$(head -n 1 "$CSV_FILE")
  if [[ "$CURRENT_HEADER" != *"rabbit_cpu_avg_pct"* || "$CURRENT_HEADER" != *"payload_profile"* || "$CURRENT_HEADER" != *"rabbit_ingress_mode"* ]]; then
    TMP_CSV=$(mktemp)
    echo "vus,repetition,stage_concurrency,payload_profile,rabbit_ingress_mode,rabbit_ingress_max_inflight,failure_threshold_ms,loadavg_1m,mem_used_mb,latency_avg_ms,latency_p95_ms,throughput_rps,transport_failure_pct,slow_failure_pct,total_failure_pct,rabbit_cpu_avg_pct,rabbit_cpu_peak_pct" > "$TMP_CSV"
    tail -n +2 "$CSV_FILE" | awk -F',' 'NF > 0 { print $1 "," $2 "," $3 ",small,native," $3 "," $4 "," $5 "," $6 "," $7 "," $8 "," $9 "," $10 "," $11 "," $12 ",NA,NA" }' >> "$TMP_CSV"
    mv "$TMP_CSV" "$CSV_FILE"
  fi
fi

for VUS in "${VUS_LEVELS[@]}"
do
  for REP in $(seq 1 "$REPETITIONS")
  do
    echo "==========================================="
    echo "Running RabbitMQ Test with $VUS VUs (repetition $REP/$REPETITIONS)"
    echo "==========================================="

    RUN_DIR="$RESULT_DIR/stage-${STAGE_CONCURRENCY}/payload-${PAYLOAD_PROFILE}/${VUS}VUs/repeat-${REP}"
    mkdir -p "$RUN_DIR"

    SUMMARY_FILE="$RUN_DIR/${VUS}vus-summary.txt"
    JSON_FILE="$RUN_DIR/${VUS}vus.json"

    # Start Rabbit services
    if [[ "$USE_EXTERNAL_SERVICES" != "true" ]]; then
      STAGE_CONCURRENCY="$STAGE_CONCURRENCY" RABBIT_INGRESS_MODE="$RABBIT_INGRESS_MODE" RABBIT_INGRESS_MAX_INFLIGHT="$RABBIT_INGRESS_MAX_INFLIGHT" npm run start:rabbit &

      echo "Aguardando serviços Rabbit iniciarem..."
      sleep "$STARTUP_WAIT_SECONDS"
    else
      echo "Aguardando endpoint Rabbit ficar pronto em $PAYMENT_URL..."
      if ! wait_for_http_ready "$PAYMENT_URL"; then
        echo "Endpoint Rabbit não ficou pronto em tempo hábil: $PAYMENT_URL"
        exit 1
      fi
    fi

    # Métricas antes
    LOADAVG=$(awk '{print $1}' /proc/loadavg)
    MEM_USED=$(free -m | awk '/Mem:/ {print $3}')

    # Run k6
    CPU_SAMPLE_FILE=""
    CPU_SAMPLER_PID=""

    if [[ "$USE_EXTERNAL_SERVICES" == "true" ]]; then
      CPU_SAMPLE_FILE=$(mktemp)
    fi

    FAILURE_THRESHOLD_MS="$FAILURE_THRESHOLD_MS" PAYMENT_URL="$PAYMENT_URL" PAYLOAD_PROFILE="$PAYLOAD_PROFILE" k6 run "$TEST_FILE" --address "$K6_API_ADDRESS" --vus "$VUS" --duration "$DURATION" --out json="$JSON_FILE" > "$SUMMARY_FILE" &
    K6_PID=$!

    if [[ "$USE_EXTERNAL_SERVICES" == "true" ]]; then
      (
        while kill -0 "$K6_PID" 2>/dev/null; do
          sample_rabbit_cpu_sum_pct >> "$CPU_SAMPLE_FILE" || true
          sleep 1
        done
      ) &
      CPU_SAMPLER_PID=$!
    fi

    wait "$K6_PID"

    if [[ -n "$CPU_SAMPLER_PID" ]]; then
      wait "$CPU_SAMPLER_PID" 2>/dev/null || true
    fi

    # Métricas depois
    LOADAVG=$(awk '{print $1}' /proc/loadavg)
    MEM_USED=$(free -m | awk '/Mem:/ {print $3}')

    LATENCY_AVG=$(extract_trend_stat "$SUMMARY_FILE" "http_req_duration" "avg")
    LATENCY_P95=$(extract_trend_stat "$SUMMARY_FILE" "http_req_duration" "p(95)")
    THROUGHPUT=$(extract_counter_rate "$SUMMARY_FILE" "http_reqs")
    TRANSPORT_FAILURE_PCT=$(extract_rate_pct "$SUMMARY_FILE" "http_req_failed")
    SLOW_FAILURE_PCT=$(extract_rate_pct "$SUMMARY_FILE" "benchmark_slow_failure_rate")
    TOTAL_FAILURE_PCT=$(extract_rate_pct "$SUMMARY_FILE" "benchmark_total_failure_rate")

    RABBIT_CPU_AVG_PCT=""
    RABBIT_CPU_PEAK_PCT=""
    if [[ -n "$CPU_SAMPLE_FILE" && -s "$CPU_SAMPLE_FILE" ]]; then
      RABBIT_CPU_AVG_PCT=$(awk '{sum+=$1; n++} END { if (n>0) printf "%.2f", sum/n; else printf "0.00" }' "$CPU_SAMPLE_FILE")
      RABBIT_CPU_PEAK_PCT=$(awk 'BEGIN {max=0} { if ($1+0 > max) max=$1+0 } END { printf "%.2f", max }' "$CPU_SAMPLE_FILE")
    else
      RABBIT_CPU_AVG_PCT="NA"
      RABBIT_CPU_PEAK_PCT="NA"
    fi

    if [[ -n "$CPU_SAMPLE_FILE" ]]; then
      rm -f "$CPU_SAMPLE_FILE"
    fi

    echo "$VUS,$REP,$STAGE_CONCURRENCY,$PAYLOAD_PROFILE,$RABBIT_INGRESS_MODE,$RABBIT_INGRESS_MAX_INFLIGHT,$FAILURE_THRESHOLD_MS,$LOADAVG,$MEM_USED,$LATENCY_AVG,$LATENCY_P95,$THROUGHPUT,$TRANSPORT_FAILURE_PCT,$SLOW_FAILURE_PCT,$TOTAL_FAILURE_PCT,$RABBIT_CPU_AVG_PCT,$RABBIT_CPU_PEAK_PCT" >> "$CSV_FILE"

    if [[ "$USE_EXTERNAL_SERVICES" != "true" ]]; then
      echo "Finalizando serviços Rabbit..."
      pkill -f baseRabbitService
      pkill -f brokerService
    fi

    sleep "$COOLDOWN_SECONDS"
  done
done

echo "==========================================="
echo "Benchmark Rabbit finalizado. CSV: $CSV_FILE"