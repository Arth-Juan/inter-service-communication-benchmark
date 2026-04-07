import express from "express";
import amqp from "amqplib";
import { randomUUID } from "crypto";

const steps = ["validate_queue", "antifraud_queue", "authorize_queue", "settle_queue"];

const app = express();
app.use(express.json());

// variáveis globais (reutilizadas)
let ch: amqp.Channel;
let replyQueue: amqp.Replies.AssertQueue;

// controle de correlação
const pending = new Map<string, (value: { status: number }) => void>();

// 🔹 init AMQP UMA VEZ
async function startAmqp() {
  const conn = await amqp.connect("amqp://localhost");
  ch = await conn.createChannel();

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
async function simulatePayment() {
  const correlationId = randomUUID();

  const payload = {
    id: correlationId,
    value: 100,
  };

  return new Promise<{ status: number }>((resolve) => {
    // registra estado
    pending.set(correlationId, resolve);

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
  await simulatePayment();
  res.status(200).json({ status: "ok" });
});

// 🔹 bootstrap
async function main() {
  await startAmqp();

  app.listen(3000, () => {
    console.log("Payment running on port 3000");
  });
}

main();