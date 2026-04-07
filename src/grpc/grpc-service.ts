// import grpc from '@grpc/grpc-js';
// import protoLoader from '@grpc/proto-loader';
// import { sleep } from '../utils.ts';

// const PORT = process.env.PORT;
// const NAME = process.env.NAME || 'stage';

// const packageDef = protoLoader.loadSync('./src/grpc/payment.proto');
// const grpcObj = grpc.loadPackageDefinition(packageDef) as any;
// const server = new grpc.Server();

// server.addService(grpcObj.payment.PaymentStage.service, {
//   Process: async (call: any, callback: any) => {
//     console.log(`${NAME} received request for order ${call.request.orderId}`);
//     await sleep(50);
//     callback(null, { status: 'ok' });
//   },
// });

// server.bindAsync(`0.0.0.0:${PORT}`, grpc.ServerCredentials.createInsecure(), () => {
//   console.log(`${NAME} gRPC server running on port ${PORT}`);
// });
import grpc from '@grpc/grpc-js';
import protoLoader from '@grpc/proto-loader';
import { AsyncSemaphore, sleep } from '../utils.ts';

const PROTO_PATH = './src/grpc/payment.proto';
const PORT = process.env.PORT || 50051;
const NAME = process.env.NAME || 'validation';
const STAGE_CONCURRENCY = Number(process.env.STAGE_CONCURRENCY || '50');
const gate = new AsyncSemaphore(STAGE_CONCURRENCY);

const packageDef = protoLoader.loadSync(PROTO_PATH);
const grpcObj = grpc.loadPackageDefinition(packageDef) as any;
const server = new grpc.Server();

// Mapeia NAME -> método RPC
const methodMap: Record<string, string> = {
  validation: 'Validate',
  antifraud: 'Antifraud',
  authorization: 'Authorize',
  settle: 'Settle',
};

// Descobre qual método implementar
const rpcMethod = methodMap[NAME];
if (!rpcMethod) {
  throw new Error(`Nome de microsserviço inválido: ${NAME}`);
}

// Implementa o método correspondente
const serviceImpl: Record<string, any> = {};
serviceImpl[rpcMethod] = async (call: any, callback: any) => {
  const release = await gate.acquire();
  try {
    await sleep(50);
    callback(null, { status: 'ok' });
  } catch (error) {
    callback(error, null);
  } finally {
    release();
  }
};

// Registra serviço
server.addService(grpcObj.payment.PaymentStage.service, serviceImpl);

server.bindAsync(`0.0.0.0:${PORT}`, grpc.ServerCredentials.createInsecure(), (err, bindPort) => {
  if (err) {
    console.error('Erro ao bindar o server:', err);
    return;
  }
  server.start();
  console.log(`${NAME} rodando na porta ${bindPort}, método ${rpcMethod}, stageConcurrency=${STAGE_CONCURRENCY}`);
});
