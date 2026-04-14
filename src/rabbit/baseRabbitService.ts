import amqp from 'amqplib';

const QUEUE = process.env.QUEUE!;
const NEXT_QUEUE = process.env.NEXT_QUEUE;
const NAME = process.env.NAME || 'service';
const STAGE_CONCURRENCY = Number(process.env.STAGE_CONCURRENCY || process.env.PREFETCH || '50');
const AMQP_URL = process.env.AMQP_URL || 'amqp://localhost';

async function start() {
  const conn = await amqp.connect(AMQP_URL);
  const channel = await conn.createChannel();

  // Bound in-flight messages per stage for fair protocol comparison.
  channel.prefetch(STAGE_CONCURRENCY);

  await channel.assertQueue(QUEUE, { durable: true });
  if (NEXT_QUEUE) {
    await channel.assertQueue(NEXT_QUEUE, { durable: true });
  }

  console.log(`[${NAME}] listening on ${QUEUE} with stageConcurrency=${STAGE_CONCURRENCY}`);

  channel.consume(QUEUE, async (msg) => {
    if (!msg) return;

    try {
      const data = JSON.parse(msg.content.toString());

      // Simulates business logic processing time.
      await new Promise((r) => setTimeout(r, 50));

      if (NEXT_QUEUE) {
        channel.sendToQueue(
          NEXT_QUEUE,
          Buffer.from(JSON.stringify(data)),
          {
            correlationId: msg.properties.correlationId,
            replyTo: msg.properties.replyTo,
          }
        );
      } else {
        channel.sendToQueue(
          msg.properties.replyTo,
          Buffer.from(JSON.stringify({ ok: true })),
          {
            correlationId: msg.properties.correlationId,
          }
        );
      }

      channel.ack(msg);
    } catch (error) {
      console.error(`[${NAME}] failed to process message`, error);
      channel.nack(msg, false, false);
    }
  });
}

start().catch((error) => {
  console.error(`[${NAME}] startup failed`, error);
  process.exit(1);
});
