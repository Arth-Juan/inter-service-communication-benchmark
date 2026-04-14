import http from 'k6/http';
import { Rate } from 'k6/metrics';

const FAILURE_THRESHOLD_MS = Number(__ENV.FAILURE_THRESHOLD_MS || '1000');
const PAYMENT_URL = __ENV.PAYMENT_URL || 'http://localhost:3000/payment';
const PAYLOAD_PROFILE = (__ENV.PAYLOAD_PROFILE || 'small').toLowerCase();
const HEAVY_PAYLOAD_BYTES = Number(__ENV.HEAVY_PAYLOAD_BYTES || '32768');
const HEAVY_PAD = 'x'.repeat(Math.max(HEAVY_PAYLOAD_BYTES, 0));

const benchmarkSlowFailureRate = new Rate('benchmark_slow_failure_rate');
const benchmarkTotalFailureRate = new Rate('benchmark_total_failure_rate');

export const options = {
  vus: __ENV.VUS ? parseInt(__ENV.VUS) : 50,
  duration: __ENV.DURATION || '30s'
};

function buildPayload() {
  const orderId = `${PAYLOAD_PROFILE}-${__VU}-${__ITER}`;
  if (PAYLOAD_PROFILE === 'heavy') {
    return { orderId, payload: HEAVY_PAD };
  }

  return { orderId };
}

export default function () {
  const response = http.post(PAYMENT_URL, JSON.stringify(buildPayload()), {
    headers: { 'Content-Type': 'application/json' },
  });

  const transportFailed = response.status < 200 || response.status >= 400;
  const slowFailed = response.timings.duration > FAILURE_THRESHOLD_MS;

  benchmarkSlowFailureRate.add(slowFailed);
  benchmarkTotalFailureRate.add(transportFailed || slowFailed);

}