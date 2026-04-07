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
import { check, sleep } from 'k6';

// Instância global do cliente
const client = new grpc.Client();

// Carrega o seu arquivo .proto (certifique-se que o caminho está correto)
client.load(['.'], 'payment.proto');


export default () => {
  // Conecta ao seu microserviço Node.js
  if (__ITER == 0) {
    client.connect('localhost:60000', {
      plaintext: true, // Geralmente true para ambientes de desenvolvimento/local
    });
  }

  const data = { orderId: '123' };
  let response;
  // Exemplo chamando o estágio de Processamento
  try{
    response = client.invoke('payment.PaymentStage/Process', data);} catch (e) {
    console.error('Erro na chamada gRPC:', e);
      client.connect('localhost:60000', {
      plaintext: true, // Geralmente true para ambientes de desenvolvimento/local
    });
    response = client.invoke('payment.PaymentStage/Process', data)
  }

  // Validação da resposta
  check(response, { 'status is OK': (r) => r && r.message.status === 'ok' });

  // Fecha a conexão para liberar recursos do k6
    //client.close();
};
