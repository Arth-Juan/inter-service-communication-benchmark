import express from 'express';
import { call } from '../utils.ts';

const app = express();

app.use(express.json());

app.post('/payment', async (req, res) => {
  const payload = req.body && Object.keys(req.body).length > 0 ? req.body : { orderId: '123' };
  // simulatee a payment being processed
  await simulatePayment(payload);
  res.status(200).json({ status: 'ok' });
});

app.listen(3000, () => {
  console.log('REST service starting');
  console.log('Payment running on port 3000')
});

const STAGE_VALIDATE_URL = process.env.STAGE_VALIDATE_URL || 'http://localhost:3001/validate';
const STAGE_ANTIFRAUD_URL = process.env.STAGE_ANTIFRAUD_URL || 'http://localhost:3002/antifraud';
const STAGE_AUTHORIZE_URL = process.env.STAGE_AUTHORIZE_URL || 'http://localhost:3003/authorize';
const STAGE_SETTLE_URL = process.env.STAGE_SETTLE_URL || 'http://localhost:3004/settle';

// Pretends it is a complex system, using this abstraction to ensure better results
async function simulatePayment(payload: any) {

  await call(STAGE_VALIDATE_URL, payload);
  await call(STAGE_ANTIFRAUD_URL, payload);
  await call(STAGE_AUTHORIZE_URL, payload);
  await call(STAGE_SETTLE_URL, payload);

}

