// import grpc from 'k6/net/grpc';
// import { check } from 'k6';

// // init context
// const client = new grpc.Client();
// client.load([], './payment.proto'); // caminho do proto

// export default function () {
//   // conecta ao PaymentService
//   client.connect('localhost:60000', { plaintext: true });

//   // chama apenas Process
//   const response = client.invoke('payment.PaymentStage/Process', { orderId: '123' });

//   check(response, { 'status is OK': (r) => r && r.message.status === 'ok' });

//   client.close();
// }

// import grpc from 'k6/net/grpc';
// import { check } from 'k6';

// const client = new grpc.Client();
// client.load([], './payment.proto');
// let connected = false;

// export const options = {
//   vus: __ENV.VUS ? parseInt(__ENV.VUS) : 50,
//   duration: __ENV.DURATION || '30s'
// };

// export default function () {
//   if (!connected) {
//     client.connect('localhost:60000', { plaintext: true });
//     connected = true;
//   }

//   const response = client.invoke('payment.PaymentStage/Process', { orderId: '123' });

//   check(response, { 'status is OK': (r) => r && r.message.status === 'ok' });
// }

// export function teardown() {
//   if (connected) {
//     client.close();
//   }
// }

// import grpc from 'k6/net/grpc';
// import { check } from 'k6';

// const client = new grpc.Client();
// client.load([], './payment.proto');

// const clients = {};

// export const options = {
//   vus: __ENV.VUS ? parseInt(__ENV.VUS) : 50,
//   duration: __ENV.DURATION || '30s',
// };

// export default function () {
//   const vu = __VU;
//   let vuClient = clients[vu];

//   if (!vuClient) {
//     vuClient = new grpc.Client();
//     vuClient.connect('localhost:60000', { plaintext: true });
//     clients[vu] = vuClient;
//   }

//   const response = vuClient.invoke('payment.PaymentStage/Process', { orderId: '123' });
//   check(response, { 'status is OK': (r) => r && r.message.status === 'ok' });
// }

// export function teardown() {
//   Object.values(clients).forEach((c) => c.close());
// }

import grpc from 'k6/net/grpc';
import { Rate } from 'k6/metrics';

const client = new grpc.Client();
client.load(['.'], 'payment.proto');

const FAILURE_THRESHOLD_MS = Number(__ENV.FAILURE_THRESHOLD_MS || '1000');

const benchmarkTransportFailureRate = new Rate('benchmark_transport_failure_rate');
const benchmarkSlowFailureRate = new Rate('benchmark_slow_failure_rate');
const benchmarkTotalFailureRate = new Rate('benchmark_total_failure_rate');


export default () => {
  if (__ITER == 0) {
    client.connect('localhost:60000', {
      plaintext: true,
    });
  }

  const data = { orderId: '123' };
  const startedAt = Date.now();
  let response = null;
  let transportFailed = false;

  try {
    response = client.invoke('payment.PaymentStage/Process', data);
    transportFailed = response.status !== grpc.StatusOK || response.message?.status !== 'ok';
  } catch (error) {
    transportFailed = true;
  }

  const duration = Date.now() - startedAt;
  const slowFailed = duration > FAILURE_THRESHOLD_MS;

  benchmarkTransportFailureRate.add(transportFailed);
  benchmarkSlowFailureRate.add(slowFailed);
  benchmarkTotalFailureRate.add(transportFailed || slowFailed);
};
