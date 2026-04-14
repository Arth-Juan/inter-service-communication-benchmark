import grpc from 'k6/net/grpc';
import { Rate } from 'k6/metrics';
import encoding from 'k6/encoding';

const client = new grpc.Client();
client.load(['.'], 'payment.proto');

const FAILURE_THRESHOLD_MS = Number(__ENV.FAILURE_THRESHOLD_MS || '1000');
const PAYMENT_GRPC_TARGET = __ENV.PAYMENT_GRPC_TARGET || 'localhost:60000';
const PAYLOAD_PROFILE = (__ENV.PAYLOAD_PROFILE || 'small').toLowerCase();
const HEAVY_PAYLOAD_BYTES = Number(__ENV.HEAVY_PAYLOAD_BYTES || '32768');
const SMALL_PAYLOAD = { orderId: 'small-fixed' };
const HEAVY_PAYLOAD_RAW = 'x'.repeat(Math.max(HEAVY_PAYLOAD_BYTES, 0));
const HEAVY_PAYLOAD = {
  orderId: 'heavy-fixed',
  // k6 expects bytes fields as base64-encoded strings.
  payload: encoding.b64encode(HEAVY_PAYLOAD_RAW),
};

const benchmarkTransportFailureRate = new Rate('benchmark_transport_failure_rate');
const benchmarkSlowFailureRate = new Rate('benchmark_slow_failure_rate');
const benchmarkTotalFailureRate = new Rate('benchmark_total_failure_rate');
let loggedInvokeError = false;


export default () => {
  if (__ITER == 0) {
    client.connect(PAYMENT_GRPC_TARGET, {
      plaintext: true,
    });
  }

  const data = PAYLOAD_PROFILE === 'heavy' ? HEAVY_PAYLOAD : SMALL_PAYLOAD;
  const startedAt = Date.now();
  let response = null;
  let transportFailed = false;

  try {
    response = client.invoke('payment.PaymentStage/Process', data);
    transportFailed = !response || response.status !== grpc.StatusOK || response.message?.status !== 'ok';
  } catch (error) {
    transportFailed = true;
    if (!loggedInvokeError) {
      loggedInvokeError = true;
      console.error(`gRPC invoke failed: ${String(error)}`);
    }
  }

  const duration = Date.now() - startedAt;
  const slowFailed = duration > FAILURE_THRESHOLD_MS;

  benchmarkTransportFailureRate.add(transportFailed);
  benchmarkSlowFailureRate.add(slowFailed);
  benchmarkTotalFailureRate.add(transportFailed || slowFailed);
};
