#!/bin/bash

#####################################################################
# Results Aggregator Script
# Computes statistics across repetitions and generates summary reports
# Usage: ./aggregate-results.sh
#####################################################################

set -e

RESULTS_DIR="./results"
SUMMARY_DIR="./results/summary"
OUTPUT_FILE="${SUMMARY_DIR}/aggregate-summary_$(date +%Y%m%d_%H%M%S).md"
OUTPUT_CSV_FILE="${SUMMARY_DIR}/aggregate-summary_$(date +%Y%m%d_%H%M%S).csv"

mkdir -p "$SUMMARY_DIR"

echo "Aggregating benchmark results..."
echo ""

# Create Python script for statistical analysis
PYTHON_SCRIPT="/tmp/aggregate_stats.py"
cat > "$PYTHON_SCRIPT" << 'PYTHON_EOF'
import os
import csv
import json
import re
from collections import defaultdict
from statistics import mean, median, stdev
import sys
from datetime import datetime

results_dir = sys.argv[1] if len(sys.argv) > 1 else "./results"
output_file = sys.argv[2] if len(sys.argv) > 2 else "./results/summary/aggregate-summary.md"
output_csv_file = sys.argv[3] if len(sys.argv) > 3 else "./results/summary/aggregate-summary.csv"

def parse_num(value):
    if value is None:
        return None
    s = str(value).strip()
    if not s:
        return None
    # Accept strings like 258.37ms, 1.57s, 0.00%, 970.64
    m = re.search(r'-?\d+(?:\.\d+)?', s)
    if not m:
        return None
    num = float(m.group(0))
    if s.endswith('s') and not s.endswith('ms'):
        num *= 1000.0
    return num

# Collect all protocol CSV files recursively
csv_files = []
for root, _, files in os.walk(results_dir):
    for f in files:
        if f.endswith('.csv') and f == 'system-benchmark.csv':
            csv_files.append(os.path.join(root, f))

# Group results by protocol, payload_profile, stage_concurrency, and vus
data = defaultdict(lambda: defaultdict(list))

for filepath in sorted(csv_files):
    protocol = os.path.basename(os.path.dirname(filepath)).upper()
    protocol_cpu_avg_col = f"{protocol.lower()}_cpu_avg_pct"
    protocol_cpu_peak_col = f"{protocol.lower()}_cpu_peak_pct"
    try:
        with open(filepath, 'r', newline='') as f:
            reader = csv.DictReader(f)
            for row in reader:
                try:
                    stage_concurrency = row.get('stage_concurrency', 'unknown')
                    payload_profile = row.get('payload_profile', 'small')
                    vus = row.get('vus', 'unknown')

                    # Extract metrics
                    metrics = {
                        'latency_avg': parse_num(row.get('latency_avg_ms')),
                        'latency_p95': parse_num(row.get('latency_p95_ms')),
                        'throughput': parse_num(row.get('throughput_rps')),
                        'total_failure': parse_num(row.get('total_failure_pct')),
                        'slow_failure': parse_num(row.get('slow_failure_pct')),
                        'mem_used_mb': parse_num(row.get('mem_used_mb')),
                        'cpu_avg_pct': parse_num(row.get(protocol_cpu_avg_col)),
                        'cpu_peak_pct': parse_num(row.get(protocol_cpu_peak_col)),
                    }

                    key = f"{protocol}|{payload_profile}|{stage_concurrency}|{vus}"
                    for metric_name, metric_value in metrics.items():
                        if metric_value is not None:
                            data[key][metric_name].append(metric_value)
                except (ValueError, KeyError) as e:
                    print(f"Warning: Skipping row in {filepath}: {e}", file=sys.stderr)
    except Exception as e:
        print(f"Warning: Could not read {filepath}: {e}", file=sys.stderr)

# Generate statistics
results = {}
for key in sorted(data.keys()):
    parts = key.split('|')
    protocol = parts[0]
    payload_profile = parts[1]
    stage_conc = parts[2]
    vus = parts[3]
    
    results[key] = {
        'protocol': protocol,
        'payload_profile': payload_profile,
        'stage_concurrency': stage_conc,
        'vus': vus,
        'metrics': {}
    }
    
    for metric_name, values in data[key].items():
        if len(values) > 0:
            stat = {
                'n': len(values),
                'mean': round(mean(values), 2),
                'median': round(median(values), 2),
                'min': round(min(values), 2),
                'max': round(max(values), 2),
            }

            if len(values) > 1:
                stat['stdev'] = round(stdev(values), 2)

            results[key]['metrics'][metric_name] = stat

# Build grouped view for markdown
grouped = {}
for _, entry in results.items():
    p = entry['protocol']
    pp = entry['payload_profile']
    c = entry['stage_concurrency']
    v = entry['vus']
    grouped.setdefault(p, {}).setdefault(pp, {}).setdefault(c, {})[v] = entry['metrics']

lines = []
lines.append('# Benchmark Aggregation Report')
lines.append('')
lines.append(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
lines.append('')
lines.append('## Results Summary')
lines.append('')

if grouped:
    lines.append('### By Protocol and Concurrency')
    lines.append('')
    for protocol in sorted(grouped.keys()):
        lines.append(f'#### {protocol}')
        lines.append('')
        for payload_profile in sorted(grouped[protocol].keys()):
            lines.append(f'**Payload Profile: {payload_profile}**')
            lines.append('')
            for stage_conc in sorted(grouped[protocol][payload_profile].keys(), key=lambda x: int(x) if str(x).isdigit() else x):
                lines.append(f'**Stage Concurrency: {stage_conc}**')
                lines.append('')
                lines.append('| VUs | Latency Avg (ms) | Latency p95 (ms) | Throughput (req/s) | Total Failure % | CPU Avg % | CPU Peak % | Mem Used (MB) |')
                lines.append('|-----|---|---|---|---|---|---|---|')
                for vus in sorted(grouped[protocol][payload_profile][stage_conc].keys(), key=lambda x: int(x) if str(x).isdigit() else x):
                    metrics = grouped[protocol][payload_profile][stage_conc][vus]
                    lat_avg = metrics.get('latency_avg', {}).get('mean', '-')
                    lat_p95 = metrics.get('latency_p95', {}).get('mean', '-')
                    throughput = metrics.get('throughput', {}).get('mean', '-')
                    failure = metrics.get('total_failure', {}).get('mean', '-')
                    cpu_avg = metrics.get('cpu_avg_pct', {}).get('mean', '-')
                    cpu_peak = metrics.get('cpu_peak_pct', {}).get('mean', '-')
                    mem_used = metrics.get('mem_used_mb', {}).get('mean', '-')
                    lines.append(f'| {vus} | {lat_avg} | {lat_p95} | {throughput} | {failure} | {cpu_avg} | {cpu_peak} | {mem_used} |')
                lines.append('')
else:
    lines.append('No valid benchmark rows were found.')
    lines.append('')

lines.append('## Raw Result Files')
lines.append('')
if csv_files:
    for path in sorted(csv_files):
        try:
            size = os.path.getsize(path)
            lines.append(f'- {path} ({size} bytes)')
        except OSError:
            lines.append(f'- {path}')
else:
    lines.append('No CSV files found')

lines.append('')
lines.append('## Next Steps')
lines.append('')
lines.append('1. Review the protocol tables and compare throughput vs p95 latency.')
lines.append('2. Check whether total failure rises at higher VU values for each protocol.')
lines.append('3. Compare behavior across stage concurrency values (100, 200, 10000).')

with open(output_file, 'w') as f:
    f.write('\n'.join(lines) + '\n')

# Write a single, graph-friendly consolidated CSV (one row per protocol/payload/stage/vus group)
csv_headers = [
    'protocol',
    'payload_profile',
    'stage_concurrency',
    'vus',
    'samples',
    'latency_avg_mean_ms',
    'latency_avg_median_ms',
    'latency_avg_stdev_ms',
    'latency_p95_mean_ms',
    'latency_p95_median_ms',
    'latency_p95_stdev_ms',
    'throughput_mean_rps',
    'throughput_median_rps',
    'throughput_stdev_rps',
    'total_failure_mean_pct',
    'total_failure_median_pct',
    'total_failure_stdev_pct',
    'slow_failure_mean_pct',
    'slow_failure_median_pct',
    'slow_failure_stdev_pct',
    'cpu_avg_mean_pct',
    'cpu_avg_median_pct',
    'cpu_avg_stdev_pct',
    'cpu_peak_mean_pct',
    'cpu_peak_median_pct',
    'cpu_peak_stdev_pct',
    'mem_used_mean_mb',
    'mem_used_median_mb',
    'mem_used_stdev_mb',
]

def stat_value(metrics, metric_name, key, default=''):
    return metrics.get(metric_name, {}).get(key, default)

def sort_key(entry):
    protocol = entry['protocol']
    payload = entry['payload_profile']
    stage = entry['stage_concurrency']
    vus = entry['vus']
    stage_num = int(stage) if str(stage).isdigit() else stage
    vus_num = int(vus) if str(vus).isdigit() else vus
    return (protocol, payload, stage_num, vus_num)

sorted_entries = sorted(results.values(), key=sort_key)
with open(output_csv_file, 'w', newline='') as cf:
    writer = csv.DictWriter(cf, fieldnames=csv_headers)
    writer.writeheader()
    for entry in sorted_entries:
        metrics = entry['metrics']
        samples = stat_value(metrics, 'throughput', 'n', 0)
        if samples == 0:
            samples = max(
                stat_value(metrics, 'latency_avg', 'n', 0),
                stat_value(metrics, 'latency_p95', 'n', 0),
                stat_value(metrics, 'total_failure', 'n', 0),
                stat_value(metrics, 'cpu_avg_pct', 'n', 0),
                stat_value(metrics, 'mem_used_mb', 'n', 0),
            )

        writer.writerow({
            'protocol': entry['protocol'],
            'payload_profile': entry['payload_profile'],
            'stage_concurrency': entry['stage_concurrency'],
            'vus': entry['vus'],
            'samples': samples,
            'latency_avg_mean_ms': stat_value(metrics, 'latency_avg', 'mean'),
            'latency_avg_median_ms': stat_value(metrics, 'latency_avg', 'median'),
            'latency_avg_stdev_ms': stat_value(metrics, 'latency_avg', 'stdev'),
            'latency_p95_mean_ms': stat_value(metrics, 'latency_p95', 'mean'),
            'latency_p95_median_ms': stat_value(metrics, 'latency_p95', 'median'),
            'latency_p95_stdev_ms': stat_value(metrics, 'latency_p95', 'stdev'),
            'throughput_mean_rps': stat_value(metrics, 'throughput', 'mean'),
            'throughput_median_rps': stat_value(metrics, 'throughput', 'median'),
            'throughput_stdev_rps': stat_value(metrics, 'throughput', 'stdev'),
            'total_failure_mean_pct': stat_value(metrics, 'total_failure', 'mean'),
            'total_failure_median_pct': stat_value(metrics, 'total_failure', 'median'),
            'total_failure_stdev_pct': stat_value(metrics, 'total_failure', 'stdev'),
            'slow_failure_mean_pct': stat_value(metrics, 'slow_failure', 'mean'),
            'slow_failure_median_pct': stat_value(metrics, 'slow_failure', 'median'),
            'slow_failure_stdev_pct': stat_value(metrics, 'slow_failure', 'stdev'),
            'cpu_avg_mean_pct': stat_value(metrics, 'cpu_avg_pct', 'mean'),
            'cpu_avg_median_pct': stat_value(metrics, 'cpu_avg_pct', 'median'),
            'cpu_avg_stdev_pct': stat_value(metrics, 'cpu_avg_pct', 'stdev'),
            'cpu_peak_mean_pct': stat_value(metrics, 'cpu_peak_pct', 'mean'),
            'cpu_peak_median_pct': stat_value(metrics, 'cpu_peak_pct', 'median'),
            'cpu_peak_stdev_pct': stat_value(metrics, 'cpu_peak_pct', 'stdev'),
            'mem_used_mean_mb': stat_value(metrics, 'mem_used_mb', 'mean'),
            'mem_used_median_mb': stat_value(metrics, 'mem_used_mb', 'median'),
            'mem_used_stdev_mb': stat_value(metrics, 'mem_used_mb', 'stdev'),
        })

print(json.dumps({'output_file': output_file, 'output_csv_file': output_csv_file, 'groups': len(results), 'csv_files': len(csv_files)}))
PYTHON_EOF

if ! command -v python3 &> /dev/null; then
    echo "Python3 not found. Cannot aggregate results."
    exit 1
fi

python3 "$PYTHON_SCRIPT" "$RESULTS_DIR" "$OUTPUT_FILE" "$OUTPUT_CSV_FILE" >/tmp/aggregate-results.meta.json

echo ""
cat "$OUTPUT_FILE"
echo ""
echo "Full report saved to: $OUTPUT_FILE"
echo "Consolidated CSV saved to: $OUTPUT_CSV_FILE"
