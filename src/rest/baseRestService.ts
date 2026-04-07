import express from 'express';
import { AsyncSemaphore, sleep } from '../utils.ts';
const app = express();

app.use(express.json());

const PORT = process.env.PORT!;
const ENDPOINT = process.env.ENDPOINT!;
const NAME = process.env.NAME!;
const STAGE_CONCURRENCY = Number(process.env.STAGE_CONCURRENCY || '50');
const gate = new AsyncSemaphore(STAGE_CONCURRENCY);

// using this abstraction to ensure better results, every part of the payment distribution will be just a sleep function
app.post(`/${ENDPOINT}`, async (req, res) => {
  const release = await gate.acquire();
  try {
    await sleep(50);
    res.json({ ok: true });
  } finally {
    release();
  }
});

app.listen(PORT, () => {
  console.log(`${NAME} running on PORT ${PORT} with stageConcurrency=${STAGE_CONCURRENCY}`);
});