#!/bin/bash

#####################################################################
# Full Benchmark Automation Script
# Automatically runs all protocols across all stage concurrency levels
# Usage: ./run-full-benchmark.sh [--vus VUS_CSV] [--reps REPETITIONS]
#####################################################################

set -e

# Default configuration
REPETITIONS="${REPETITIONS:-3}"
VUS_LEVELS_CSV="${VUS_LEVELS_CSV:-100,200,400,800,1000}"
STAGE_CONCURRENCY_LEVELS=(50 100 150 10000)  # IGNORE: 10000 is a placeholder for "max concurrency")
SKIP_BUILD="${SKIP_BUILD:-false}"
PAYLOAD_PROFILE="${PAYLOAD_PROFILE:-heavy}"

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --vus)
            VUS_LEVELS_CSV="$2"
            shift 2
            ;;
        --reps)
            REPETITIONS="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--vus VUS_CSV] [--reps REPETITIONS]"
            exit 1
            ;;
    esac
done

# Logging setup
LOGS_DIR="./benchmark-logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
MASTER_LOG="${LOGS_DIR}/full-benchmark_${TIMESTAMP}.log"

mkdir -p "$LOGS_DIR"

log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${message}" | tee -a "$MASTER_LOG"
}

# Cleanup function
cleanup() {
    log "INFO" "Cleaning up running containers..."
    docker compose down 2>/dev/null || true
}

trap cleanup EXIT

log "INFO" "=========================================="
log "INFO" "Starting Full Benchmark Suite"
log "INFO" "=========================================="
log "INFO" "Configuration:"
log "INFO" "  VUS Levels: $VUS_LEVELS_CSV"
log "INFO" "  Repetitions per point: $REPETITIONS"
log "INFO" "  Stage concurrency levels: ${STAGE_CONCURRENCY_LEVELS[@]}"
log "INFO" "  Payload profile: $PAYLOAD_PROFILE"
log "INFO" "  Skip build: $SKIP_BUILD"
log "INFO" "  Log directory: $LOGS_DIR"
log "INFO" "=========================================="

if [[ "$SKIP_BUILD" != "true" ]]; then
    log "INFO" "Building Docker images once before test matrix..."
    if docker compose build >> "$MASTER_LOG" 2>&1; then
        log "INFO" "✓ Docker images built successfully"
    else
        log "ERROR" "Failed to build Docker images"
        exit 1
    fi
fi

# Track overall results
declare -A COMPLETED_BENCHMARKS
TOTAL_BENCHMARKS=$((${#STAGE_CONCURRENCY_LEVELS[@]} * 3))
COMPLETED_COUNT=0

# Main benchmark loop
for STAGE_CONCURRENCY in "${STAGE_CONCURRENCY_LEVELS[@]}"; do
    log "INFO" ""
    log "INFO" "=========================================="
    log "INFO" "Starting stage concurrency level: $STAGE_CONCURRENCY"
    log "INFO" "=========================================="
    
    # Run REST benchmark
    PROTOCOL="REST"
    log "INFO" ""
    log "INFO" "--- Starting $PROTOCOL benchmark (concurrency=$STAGE_CONCURRENCY) ---"
    
    if STAGE_CONCURRENCY=$STAGE_CONCURRENCY \
       docker compose up -d rest-validation rest-antifraud rest-authorization rest-settle rest-payment >> "$MASTER_LOG" 2>&1; then
        
        sleep 15  # Give services time to start
        
        if STAGE_CONCURRENCY=$STAGE_CONCURRENCY \
           USE_EXTERNAL_SERVICES=true \
           PAYMENT_URL=http://localhost:3000/payment \
              PAYLOAD_PROFILE="$PAYLOAD_PROFILE" \
           VUS_LEVELS_CSV="$VUS_LEVELS_CSV" \
           REPETITIONS=$REPETITIONS \
           ./run-rest-benchmark.sh >> "$MASTER_LOG" 2>&1; then
            log "INFO" "✓ $PROTOCOL benchmark completed (concurrency=$STAGE_CONCURRENCY)"
            ((++COMPLETED_COUNT))
        else
            log "ERROR" "✗ $PROTOCOL benchmark failed (concurrency=$STAGE_CONCURRENCY)"
        fi
        
        log "INFO" "Stopping $PROTOCOL services..."
        docker compose down >> "$MASTER_LOG" 2>&1 || true
        sleep 15
    else
        log "ERROR" "Failed to start REST services"
    fi

    # Run gRPC benchmark
    PROTOCOL="gRPC"
    log "INFO" ""
    log "INFO" "--- Starting $PROTOCOL benchmark (concurrency=$STAGE_CONCURRENCY) ---"
    
    if STAGE_CONCURRENCY=$STAGE_CONCURRENCY \
       docker compose up -d grpc-validation grpc-antifraud grpc-authorization grpc-settle grpc-payment >> "$MASTER_LOG" 2>&1; then
        
        sleep 15  # Give services time to start
        
        if STAGE_CONCURRENCY=$STAGE_CONCURRENCY \
           USE_EXTERNAL_SERVICES=true \
           PAYMENT_GRPC_TARGET=localhost:60000 \
              PAYLOAD_PROFILE="$PAYLOAD_PROFILE" \
           VUS_LEVELS_CSV="$VUS_LEVELS_CSV" \
           REPETITIONS=$REPETITIONS \
           ./run-grpc-benchmark.sh >> "$MASTER_LOG" 2>&1; then
            log "INFO" "✓ $PROTOCOL benchmark completed (concurrency=$STAGE_CONCURRENCY)"
            ((++COMPLETED_COUNT))
        else
            log "ERROR" "✗ $PROTOCOL benchmark failed (concurrency=$STAGE_CONCURRENCY)"
        fi
        
        log "INFO" "Stopping $PROTOCOL services..."
        docker compose down >> "$MASTER_LOG" 2>&1 || true
        sleep 15
    else
        log "ERROR" "Failed to start gRPC services"
    fi

    # Run RabbitMQ benchmark
    PROTOCOL="RabbitMQ"
    log "INFO" ""
    log "INFO" "--- Starting $PROTOCOL benchmark (concurrency=$STAGE_CONCURRENCY) ---"
    
    if STAGE_CONCURRENCY=$STAGE_CONCURRENCY \
       docker compose up -d rabbitmq rabbit-validation rabbit-antifraud rabbit-authorization rabbit-settle rabbit-broker >> "$MASTER_LOG" 2>&1; then
        
        sleep 15  # RabbitMQ needs more time due to healthcheck
        
        if STAGE_CONCURRENCY=$STAGE_CONCURRENCY \
           USE_EXTERNAL_SERVICES=true \
           PAYMENT_URL=http://localhost:3005/payment \
              PAYLOAD_PROFILE="$PAYLOAD_PROFILE" \
           VUS_LEVELS_CSV="$VUS_LEVELS_CSV" \
           REPETITIONS=$REPETITIONS \
           ./run-rabbit-benchmark.sh >> "$MASTER_LOG" 2>&1; then
            log "INFO" "✓ $PROTOCOL benchmark completed (concurrency=$STAGE_CONCURRENCY)"
            ((++COMPLETED_COUNT))
        else
            log "ERROR" "✗ $PROTOCOL benchmark failed (concurrency=$STAGE_CONCURRENCY)"
        fi
        
        log "INFO" "Stopping $PROTOCOL services..."
        docker compose down >> "$MASTER_LOG" 2>&1 || true
        sleep 15
    else
        log "ERROR" "Failed to start RabbitMQ services"
    fi

done

log "INFO" ""
log "INFO" "=========================================="
log "INFO" "Benchmark Suite Complete"
log "INFO" "=========================================="
log "INFO" "Completed: $COMPLETED_COUNT / $TOTAL_BENCHMARKS benchmarks"
log "INFO" "Full log: $MASTER_LOG"
log "INFO" "Results: $(ls -1 results/*.csv 2>/dev/null | head -5)..."
log "INFO" "=========================================="

if [[ $COMPLETED_COUNT -eq $TOTAL_BENCHMARKS ]]; then
    log "INFO" "✓ All benchmarks completed successfully!"
    exit 0
else
    log "ERROR" "✗ Some benchmarks failed. Check log for details."
    exit 1
fi
