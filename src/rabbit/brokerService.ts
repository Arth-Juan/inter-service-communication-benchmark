import express from "express";
import amqp from "amqplib";
import { randomUUID } from "crypto";

const steps = ["validate_queue", "antifraud_queue", "authorize_queue", "settle_queue"];
const PORT = Number(process.env.PORT || '3000');
const AMQP_URL = process.env.AMQP_URL || 'amqp://localhost';
const REQUEST_TIMEOUT_MS = Number(process.env.REQUEST_TIMEOUT_MS || '5000');
const RABBIT_INGRESS_MODE = (process.env.RABBIT_INGRESS_MODE || 'native').toLowerCase();
const RABBIT_INGRESS_MAX_INFLIGHT = Number(
  process.env.RABBIT_INGRESS_MAX_INFLIGHT || process.env.STAGE_CONCURRENCY || '100'
);
const RABBIT_INGRESS_REJECT_STATUS = Number(process.env.RABBIT_INGRESS_REJECT_STATUS || '503');

const app = express();
app.use(express.json());

// variáveis globais (reutilizadas)
let ch: amqp.Channel;
let replyQueue: amqp.Replies.AssertQueue;

// controle de correlação
const pending = new Map<string, (value: { status: number }) => void>();
let inFlightRequests = 0;

function isIngressLimitedMode() {
  return RABBIT_INGRESS_MODE === 'limited';
}

// 🔹 init AMQP UMA VEZ
async function startAmqp() {
  const conn = await amqp.connect(AMQP_URL);
  ch = await conn.createChannel();

  // Ensure all pipeline queues exist before the HTTP server starts receiving traffic.
  for (const queue of steps) {
    await ch.assertQueue(queue, { durable: true });
  }

  replyQueue = await ch.assertQueue("", { exclusive: true });

  // um único consumer global (CRÍTICO)
  ch.consume(
    replyQueue.queue,
    (msg) => {
      if (!msg) return;

      const correlationId = msg.properties.correlationId;
      const resolve = pending.get(correlationId);

      if (!resolve) return;

      resolve({ status: 200 });
      pending.delete(correlationId);
    },
    { noAck: true }
  );

  console.log("AMQP ready");
}

// 🔹 simulatePayment correto
async function simulatePayment(requestPayload: any) {
  const correlationId = randomUUID();

  const payload = requestPayload && typeof requestPayload === 'object'
    ? requestPayload
    : { orderId: correlationId };

  return new Promise<{ status: number }>((resolve) => {
    // registra estado
    const timeout = setTimeout(() => {
      pending.delete(correlationId);
      resolve({ status: 504 });
    }, REQUEST_TIMEOUT_MS);

    pending.set(correlationId, (value) => {
      clearTimeout(timeout);
      resolve(value);
    });

    // send to first step only (sequential processing)
    ch.sendToQueue(
      steps[0] as string,
      Buffer.from(JSON.stringify(payload)),
      {
        correlationId,
        replyTo: replyQueue.queue,
      }
    );
  });
}

// 🔹 endpoint
app.post("/payment", async (req, res) => {
  if (isIngressLimitedMode() && inFlightRequests >= RABBIT_INGRESS_MAX_INFLIGHT) {
    res.status(RABBIT_INGRESS_REJECT_STATUS).json({
      status: 'busy',
      reason: 'ingress_limit',
      inFlight: inFlightRequests,
      maxInFlight: RABBIT_INGRESS_MAX_INFLIGHT,
    });
    return;
  }

  if (isIngressLimitedMode()) {
    inFlightRequests += 1;
  }

  let result: { status: number };
  try {
    result = await simulatePayment(req.body);
  } catch (error) {
    res.status(500).json({ status: 'error', reason: 'broker_failure' });
    return;
  } finally {
    if (isIngressLimitedMode()) {
      inFlightRequests = Math.max(0, inFlightRequests - 1);
    }
  }

  if (result.status !== 200) {
    res.status(result.status).json({ status: "timeout" });
    return;
  }

  res.status(200).json({ status: "ok" });
});

// 🔹 bootstrap
async function main() {
  await startAmqp();

  console.log(
    `Rabbit broker ingress mode=${RABBIT_INGRESS_MODE}, maxInFlight=${RABBIT_INGRESS_MAX_INFLIGHT}, rejectStatus=${RABBIT_INGRESS_REJECT_STATUS}`
  );

  app.listen(PORT, () => {
    console.log(`Payment running on port ${PORT}`);
  });
}

main();