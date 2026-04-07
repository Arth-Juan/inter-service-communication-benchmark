import express from 'express';
import { call, sleep } from '../utils.ts';

const app = express();

app.use(express.json());

app.post('/payment', async (req, res) => {

  // simulatee a payment being processed
  await simulatePayment()

  res.status(200).json({ status: 'ok' });
});

app.listen(3000, () => {
  console.log('REST service starting');
  console.log('Payment running on port 3000')
});

const payload = { orderId: "123" }
// Pretends it is a complex system, using this abstraction to ensure better results
async function simulatePayment() {
  

  await call("http://localhost:3001/validate",payload);
  await call("http://localhost:3002/antifraud",payload);
  await call("http://localhost:3003/authorize",payload);
  await call("http://localhost:3004/settle",payload);

}

