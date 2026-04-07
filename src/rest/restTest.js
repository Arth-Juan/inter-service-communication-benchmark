import http from 'k6/http';
import { Rate } from 'k6/metrics';

const FAILURE_THRESHOLD_MS = Number(__ENV.FAILURE_THRESHOLD_MS || '1000');

const benchmarkSlowFailureRate = new Rate('benchmark_slow_failure_rate');
const benchmarkTotalFailureRate = new Rate('benchmark_total_failure_rate');

export const options = {
  vus: __ENV.VUS ? parseInt(__ENV.VUS) : 50,
  duration: __ENV.DURATION || '30s'
};

export default function () {
  const response = http.post('http://localhost:3000/payment', JSON.stringify({ orderId: '123' }), {
    headers: { 'Content-Type': 'application/json' },
  });

  const transportFailed = response.status < 200 || response.status >= 400;
  const slowFailed = response.timings.duration > FAILURE_THRESHOLD_MS;

  benchmarkSlowFailureRate.add(slowFailed);
  benchmarkTotalFailureRate.add(transportFailed || slowFailed);

}