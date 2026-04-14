import grpc from '@grpc/grpc-js';
import protoLoader from '@grpc/proto-loader';


const PORT = process.env.PORT || 60000;
const VALIDATE_ADDR = process.env.VALIDATE_ADDR || 'localhost:50051';
const ANTIFRAUD_ADDR = process.env.ANTIFRAUD_ADDR || 'localhost:50052';
const AUTHORIZE_ADDR = process.env.AUTHORIZE_ADDR || 'localhost:50053';
const SETTLE_ADDR = process.env.SETTLE_ADDR || 'localhost:50054';

const packageDef = protoLoader.loadSync('./src/grpc/payment.proto');
const grpcObj = grpc.loadPackageDefinition(packageDef) as any;
const server = new grpc.Server();

type PaymentRequest = {
  orderId: string;
  payload?: Buffer | Uint8Array;
};

async function simulatePayment(call: any, callback: any) {
  const request: PaymentRequest = {
    orderId: call.request.orderId,
    payload: call.request.payload,
  };

  await callMicroservice('Validate', request);
  await callMicroservice('Antifraud', request);
  await callMicroservice('Authorize', request);
  await callMicroservice('Settle', request);

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
  Validate: new grpcObj.payment.PaymentStage(VALIDATE_ADDR, grpc.credentials.createInsecure()),
  Antifraud: new grpcObj.payment.PaymentStage(ANTIFRAUD_ADDR, grpc.credentials.createInsecure()),
  Authorize: new grpcObj.payment.PaymentStage(AUTHORIZE_ADDR, grpc.credentials.createInsecure()),
  Settle: new grpcObj.payment.PaymentStage(SETTLE_ADDR, grpc.credentials.createInsecure()),
};

function callMicroservice(endpoint: string, request: PaymentRequest) {
  return new Promise((resolve, reject) => {
    const key = endpoint as keyof typeof clients;
    clients[key][endpoint](request, (err: any, res: any) => {
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
