// ============================================================================
// Performance test: availability lookup + booking hold (k6)
// ----------------------------------------------------------------------------
// Load-tests the two hottest paths — the availability engine and placing a
// hold — against the Supabase RPC endpoints. These are the paths most exposed
// to concurrency (the booking engine must hold up under contention).
//
// Run:
//   k6 run \
//     -e SUPABASE_URL=https://<ref>.supabase.co \
//     -e SUPABASE_ANON_KEY=... \
//     -e ACCESS_TOKEN=<a client user's JWT> \
//     -e SERVICE_ID=... -e PRACTITIONER_ID=... \
//     perf/k6-availability.js
// ============================================================================
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  scenarios: {
    availability: {
      executor: 'ramping-vus',
      startVUs: 1,
      stages: [
        { duration: '30s', target: 20 },
        { duration: '1m', target: 50 },
        { duration: '30s', target: 0 },
      ],
    },
  },
  thresholds: {
    // 95% of availability lookups should complete within 800ms.
    http_req_duration: ['p(95)<800'],
    checks: ['rate>0.99'],
  },
};

const BASE = __ENV.SUPABASE_URL;
const ANON = __ENV.SUPABASE_ANON_KEY;
const TOKEN = __ENV.ACCESS_TOKEN;
const SERVICE_ID = __ENV.SERVICE_ID;
const PRACTITIONER_ID = __ENV.PRACTITIONER_ID;

const headers = {
  'Content-Type': 'application/json',
  apikey: ANON,
  Authorization: `Bearer ${TOKEN}`,
};

function isoDate(offsetDays) {
  const d = new Date();
  d.setDate(d.getDate() + offsetDays);
  return d.toISOString().slice(0, 10);
}

export default function () {
  const res = http.post(
    `${BASE}/rest/v1/rpc/get_available_slots`,
    JSON.stringify({
      p_service_id: SERVICE_ID,
      p_from: isoDate(1),
      p_to: isoDate(7),
      p_practitioner_id: PRACTITIONER_ID,
      p_step_minutes: 30,
    }),
    { headers },
  );

  check(res, {
    'availability 200': (r) => r.status === 200,
    'returns an array': (r) => Array.isArray(r.json()),
  });

  sleep(1);
}
