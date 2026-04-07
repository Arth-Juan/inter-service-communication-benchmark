import http from 'k6/http';

export const options = {
  vus: __ENV.VUS ? parseInt(__ENV.VUS) : 50,
  duration: __ENV.DURATION || '30s'
};

export default function () {
  http.post('http://localhost:3000/payment', JSON.stringify({ orderId: '123' }), {
    headers: { 'Content-Type': 'application/json' },
  });

}