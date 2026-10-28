import http from 'k6/http';

const RATE = Number(__ENV.RATE || 100);
const DURATION = __ENV.DURATION || '30m';
const CATALOG_SIZE = 5000;

const sameLoadFor = (target) => ({
  executor: 'constant-arrival-rate',
  rate: RATE,
  timeUnit: '1s',
  duration: DURATION,
  preAllocatedVUs: 50,
  maxVUs: 1000,
  exec: 'shop',
  env: { TARGET: target },
});

const targets = (__ENV.TARGETS || 'bad=http://bad,good=http://good').split(',');

export const options = {
  scenarios: Object.fromEntries(targets.map((t) => {
    const [name, url] = t.split('=');
    return [name, sameLoadFor(url)];
  })),
  summaryTrendStats: ['avg', 'p(95)', 'p(99)'],
};

const randomInt = (max) => Math.floor(Math.random() * max);

export function shop() {
  const base = __ENV.TARGET;
  if (Math.random() < 0.3) {
    http.get(`${base}/products?category=hogar&page=${1 + randomInt(5)}`, {
      timeout: '5s',
      tags: { name: 'GET /products' },
    });
    return;
  }
  const items = Array.from({ length: 1 + randomInt(4) }, () => ({
    product_id: randomInt(CATALOG_SIZE),
    quantity: 1 + randomInt(3),
  }));
  http.post(`${base}/orders`, JSON.stringify({ customer_id: randomInt(1e6), items }), {
    timeout: '5s',
    headers: { 'Content-Type': 'application/json' },
    tags: { name: 'POST /orders' },
  });
}
