// import grpc from '@grpc/grpc-js';
// import protoLoader from '@grpc/proto-loader';

// const PROTO_PATH = './src/grpc/payment.proto';
// const PORT = 60000;

// // Carrega o proto
// const packageDef = protoLoader.loadSync(PROTO_PATH);
// const grpcObj = grpc.loadPackageDefinition(packageDef);

// // Cria server
// const server = new grpc.Server();

// // Função que simula o fluxo de microsserviços
// async function simulatePayment(call:any, callback: any) {
//   const orderId = call.request.orderId;

//   // Aqui chamamos os microsserviços sequencialmente (via gRPC)
//   await callMicroservice('Validate', orderId);
//   await callMicroservice('Antifraud', orderId);
//   await callMicroservice('Authorize', orderId);
//   await callMicroservice('Settle', orderId);

//   callback(null, { status: 'ok' });
// }

// // Função genérica de chamada a microsserviço
// function callMicroservice(endpoint: string, orderId:string) {
//   return new Promise((resolve, reject) => {
//     const client = new (grpcObj as any).payment.PaymentStage(`localhost:${getPort(endpoint)}`, grpc.credentials.createInsecure());

//     client[endpoint]({ orderId }, (err: any, res: any) => {
//       if (err) return reject(err);
//       resolve(res);
//     });
//   });
// }

// // Porta de cada microsserviço
// function getPort(endpoint: string) {
//   switch (endpoint) {
//     case 'Validate': return 50051;
//     case 'Antifraud': return 50052;
//     case 'Authorize': return 50053;
//     case 'Settle': return 50054;
//     default: return 60000;
//   }
// }

// // Adiciona serviço PaymentStage
// server.addService((grpcObj as any).payment.PaymentStage.service, { Process: simulatePayment });

// // Inicia server
// server.bindAsync(`0.0.0.0:${PORT}`, grpc.ServerCredentials.createInsecure(), (err, bindPort) => {
//   if (err) {
//     console.error('Erro ao bindar o server:', err);
//     return;
//   }
//   server.start();
//   console.log(`PaymentService gRPC rodando na porta ${bindPort}`);
// });

import grpc from '@grpc/grpc-js';
import protoLoader from '@grpc/proto-loader';


const PORT = process.env.PORT || 60000;

const packageDef = protoLoader.loadSync('./src/grpc/payment.proto');
const grpcObj = grpc.loadPackageDefinition(packageDef) as any;
const server = new grpc.Server();

async function simulatePayment(call: any, callback: any) {
  const orderId = call.request.orderId;

  await callMicroservice('Validate', orderId);
  await callMicroservice('Antifraud', orderId);
  await callMicroservice('Authorize', orderId);
  await callMicroservice('Settle', orderId);

  callback(null, { status: 'ok' });
}

// function callMicroservice(endpoint: string, orderId: string) {
//   return new Promise((resolve, reject) => {
//     const client = new grpcObj.payment.PaymentStage(
//       `localhost:${getPort(endpoint)}`,
//       grpc.credentials.createInsecure()
//     );

//     client[endpoint]({ orderId }, (err: any, res: any) => {
//       if (err) return reject(err);
//       resolve(res);
//     });
//   });
// }

const clients = {
  Validate: new grpcObj.payment.PaymentStage('localhost:50051', grpc.credentials.createInsecure()),
  Antifraud: new grpcObj.payment.PaymentStage('localhost:50052', grpc.credentials.createInsecure()),
  Authorize: new grpcObj.payment.PaymentStage('localhost:50053', grpc.credentials.createInsecure()),
  Settle: new grpcObj.payment.PaymentStage('localhost:50054', grpc.credentials.createInsecure()),
};

function callMicroservice(endpoint: string, orderId: string) {
  return new Promise((resolve, reject) => {
    const key = endpoint as keyof typeof clients;
    clients[key][endpoint]({ orderId }, (err: any, res: any) => {
      if (err) return reject(err);
      resolve(res);
    });
  });
}


function getPort(endpoint: string) {
  switch (endpoint) {
    case 'Validate': return 50051;
    case 'Antifraud': return 50052;
    case 'Authorize': return 50053;
    case 'Settle': return 50054;
    default: return 60000;
  }
}

server.addService(grpcObj.payment.PaymentStage.service, { Process: simulatePayment });
console.log("chegou antes do binding")
server.bindAsync(`0.0.0.0:${PORT}`, grpc.ServerCredentials.createInsecure(), (err, bindPort) => {
  if (err) {
    console.error('Erro ao bindar o server:', err);
    return;
  }
  server.start();
  console.log(`PaymentService rodando na porta ${bindPort}`);
});
