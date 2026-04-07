#!/bin/bash
set -e   # sai se algum comando falhar

# Configurações
VUS_LEVELS=(50 200 400 800 1200 1600)
DURATION="1m"
TEST_FILE="./src/grpc/grpcTest.js"
RESULT_DIR="./results/grpc"
CSV_FILE="$RESULT_DIR/system-benchmark.csv"
STAGE_CONCURRENCY="${STAGE_CONCURRENCY:-50}"

mkdir -p "$RESULT_DIR"

# CSV consolidado
echo "vus,stage_concurrency,loadavg_1m,mem_used_mb,latency_avg_ms,latency_p95_ms,throughput_rps" > "$CSV_FILE"

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
  k6 run "$TEST_FILE" --vus "$VUS" --duration "$DURATION" --out json="$JSON_FILE" > "$SUMMARY_FILE"

  # 5️ Atualiza loadavg/mem durante teste
  LOADAVG=$(awk '{print $1}' /proc/loadavg)
  MEM_USED=$(free -m | awk '/Mem:/ {print $3}')

  # 6️ Extrai latência do JSON (mais confiável que summary)
  LATENCY_AVG=$(grep "grpc_req_duration....:" "$SUMMARY_FILE" | awk '{for(i=1;i<=NF;i++){if($i ~ /^avg=/){split($i,a,"="); print a[2]}}}')
  LATENCY_P95=$(grep "grpc_req_duration....:" "$SUMMARY_FILE" | awk '{for(i=1;i<=NF;i++){if($i ~ /^p\(95\)=/){split($i,a,"="); print a[2]}}}')
  THROUGHPUT=$(grep "iterations\." "$SUMMARY_FILE" | awk '{for(i=1;i<=NF;i++){if($i ~ /\/s$/){sub("/s","",$i); print $i; exit}}}')

  # 7️ Adiciona linha no CSV
  echo "$VUS,$STAGE_CONCURRENCY,$LOADAVG,$MEM_USED,$LATENCY_AVG,$LATENCY_P95,$THROUGHPUT" >> "$CSV_FILE"

  # 8️ Finaliza serviços gRPC
  echo "Finalizando serviços gRPC..."
  kill -15 $(lsof -ti :50051) $(lsof -ti :50052) $(lsof -ti :50053) $(lsof -ti :50054) $(lsof -ti :60000) 2>/dev/null
  sleep 10   # pausa antes do próximo teste
done

echo "==========================================="
echo "Benchmark gRPC finalizado. CSV consolidado: $CSV_FILE"