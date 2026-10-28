import http from 'k6/http';

export const options = {
  scenarios: {
    orders: { executor: 'constant-arrival-rate', rate: Number(__ENV.RATE), timeUnit: '1s', duration: '60s', preAllocatedVUs: 100, maxVUs: 1000 },
  },
  summaryTrendStats: ['avg', 'p(95)', 'p(99)'],
};

export default function () {
  http.post(__ENV.URL, null, { timeout: '5s' });
}
