import http from 'k6/http';

export const options = { vus: 30, duration: '15s' };

export default function () {
  http.get(__ENV.URL);
}
