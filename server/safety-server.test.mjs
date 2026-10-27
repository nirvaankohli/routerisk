import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';
import { createSafetyServer } from './safety-server.mjs';

const calls = [];
const config = {
  TWILIO_ACCOUNT_SID: `AC${'0'.repeat(32)}`,
  TWILIO_AUTH_TOKEN: 'test-only-token',
  TWILIO_FROM_NUMBER: '+15550000000',
  PARENT_PHONE: '+15551112222',
  ROUTERISK_PAIRING_TOKEN: 'test-pairing-token'
};

const server = createSafetyServer(config, async (url, options) => {
  calls.push({ url, body: new URLSearchParams(options.body) });
  return { ok: true, json: async () => ({ sid: `test-${calls.length}` }) };
});

let baseURL;
before(async () => {
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  baseURL = `http://127.0.0.1:${server.address().port}`;
});
after(async () => { await new Promise(resolve => server.close(resolve)); });

function event(eventName, id) {
  return {
    event: eventName,
    eventID: id,
    recipient: '(555) 111-2222',
    destination: 'Princeton University',
    latitude: 40.35,
    longitude: -74.65
  };
}

async function send(body, token = config.ROUTERISK_PAIRING_TOKEN) {
  return fetch(`${baseURL}/api/notify`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
    body: JSON.stringify(body)
  });
}

test('departure sends one SMS and duplicate ID does not resend', async () => {
  const body = event('departure', '11111111-1111-1111-1111-111111111111');
  body.timeText = '2:02 P.M.';
  assert.equal((await send(body)).status, 200);
  assert.equal((await send(body)).status, 200);
  assert.equal(calls.length, 1);
  assert.match(calls[0].url, /Messages\.json$/);
  assert.equal(calls[0].body.get('To'), '+15551112222');
  assert.equal(calls[0].body.get('Body'), 'Your child has started a route to Princeton University. ETA: 2:02 P.M.');
});

test('possible crash sends a message and an outbound call', async () => {
  assert.equal((await send(event('possibleCrash', '22222222-2222-2222-2222-222222222222'))).status, 200);
  assert.equal(calls.length, 3);
  assert.match(calls[1].url, /Messages\.json$/);
  assert.equal(calls[1].body.get('Body'), 'RouteRisk’s crash detection system noticed a possible crash during your child’s route to Princeton University. Please check on your child. This is not a confirmed crash.');
  assert.match(calls[2].url, /Calls\.json$/);
  assert.match(calls[2].body.get('Twiml'), /not a confirmed crash/);
});

test('rejects other recipients and invalid access codes', async () => {
  const body = event('arrival', '33333333-3333-3333-3333-333333333333');
  assert.equal((await send(body, 'wrong')).status, 401);
  body.recipient = '+15559998888';
  assert.equal((await send(body)).status, 403);
  assert.equal(calls.length, 3);
});

test('health check requires the pairing token', async () => {
  assert.equal((await fetch(`${baseURL}/health`)).status, 401);
  assert.equal((await fetch(`${baseURL}/health`, { headers: { Authorization: 'Bearer wrong' } })).status, 401);
  assert.equal((await fetch(`${baseURL}/health`, { headers: { Authorization: `Bearer ${config.ROUTERISK_PAIRING_TOKEN}` } })).status, 200);
});

test('arrival includes the actual arrival time', async () => {
  const body = event('arrival', '44444444-4444-4444-4444-444444444444');
  body.timeText = '2:03 P.M.';
  assert.equal((await send(body)).status, 200);
  assert.equal(calls[3].body.get('Body'), 'Your child has arrived at Princeton University at 2:03 P.M.');
});

test('rejects invalid time text', async () => {
  const body = event('departure', '55555555-5555-5555-5555-555555555555');
  body.timeText = '2:02 P.M. Extra';
  assert.equal((await send(body)).status, 400);
  assert.equal(calls.length, 4);
});
