import { createServer as createHTTPServer } from 'node:http';
import { timingSafeEqual } from 'node:crypto';
import { fileURLToPath } from 'node:url';

const required = ['TWILIO_ACCOUNT_SID', 'TWILIO_FROM_NUMBER', 'PARENT_PHONE', 'ROUTERISK_PAIRING_TOKEN'];

function normalizePhone(value) {
  if (typeof value !== 'string') return null;
  const digits = value.replace(/\D/g, '');
  if (digits.length === 10) return `+1${digits}`;
  if (digits.length >= 11 && digits.length <= 15) return `+${digits}`;
  return null;
}

function authorized(header, token) {
  if (!header?.startsWith('Bearer ') || !token) return false;
  const given = Buffer.from(header.slice(7));
  const expected = Buffer.from(token);
  return given.length === expected.length && timingSafeEqual(given, expected);
}

function json(response, status, body) {
  response.writeHead(status, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' });
  response.end(JSON.stringify(body));
}

async function readJSON(request) {
  if (!request.headers['content-type']?.startsWith('application/json')) throw new RequestError(415, 'JSON required');
  let content = '';
  for await (const chunk of request) {
    content += chunk;
    if (content.length > 4096) throw new RequestError(413, 'Request too large');
  }
  try { return JSON.parse(content); }
  catch { throw new RequestError(400, 'Invalid JSON'); }
}

class RequestError extends Error {
  constructor(status, message) { super(message); this.status = status; }
}

function validate(body, allowedPhone) {
  if (!body || !['departure', 'arrival', 'possibleCrash'].includes(body.event)) throw new RequestError(400, 'Invalid event');
  if (normalizePhone(body.recipient) !== normalizePhone(allowedPhone)) throw new RequestError(403, 'Recipient not allowed');
  if (typeof body.destination !== 'string' || !body.destination.trim() || body.destination.length > 100) throw new RequestError(400, 'Invalid destination');
  if (typeof body.eventID !== 'string' || !/^[0-9a-fA-F-]{36}$/.test(body.eventID)) throw new RequestError(400, 'Invalid event ID');
  if ((body.latitude == null) !== (body.longitude == null)) throw new RequestError(400, 'Invalid location');
  if (body.latitude != null && (!Number.isFinite(body.latitude) || !Number.isFinite(body.longitude) || Math.abs(body.latitude) > 90 || Math.abs(body.longitude) > 180)) {
    throw new RequestError(400, 'Invalid location');
  }
  if (body.timeText != null && (typeof body.timeText !== 'string' || !/^(?:[1-9]|1[0-2]):[0-5][0-9] [AP]\.M\.$/.test(body.timeText))) {
    throw new RequestError(400, 'Invalid time');
  }
  return {
    event: body.event,
    eventID: body.eventID,
    recipient: normalizePhone(body.recipient),
    destination: body.destination.trim().replace(/[\u0000-\u001f]/g, ' '),
    timeText: body.timeText ?? null,
    location: body.latitude == null ? null : `https://maps.apple.com/?ll=${body.latitude.toFixed(6)},${body.longitude.toFixed(6)}`
  };
}

function messageFor(event) {
  if (event.event === 'departure') {
    return `Your child has started a route to ${event.destination}.${event.timeText ? ` ETA: ${event.timeText}` : ''}`;
  }
  if (event.event === 'arrival') {
    return `Your child has arrived at ${event.destination}${event.timeText ? ` at ${event.timeText}` : '.'}`;
  }
  return `RouteRisk’s crash detection system noticed a possible crash during your child’s route to ${event.destination}. Please check on your child. This is not a confirmed crash.`;
}

function xmlEscape(value) {
  return value.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;').replaceAll("'", '&apos;');
}

async function twilioCreate(config, resource, form, fetchImpl) {
  const url = `https://api.twilio.com/2010-04-01/Accounts/${config.TWILIO_ACCOUNT_SID}/${resource}.json`;
  const username = config.TWILIO_API_KEY_SID || config.TWILIO_ACCOUNT_SID;
  const password = config.TWILIO_API_KEY_SECRET || config.TWILIO_AUTH_TOKEN;
  const authorization = Buffer.from(`${username}:${password}`).toString('base64');
  const response = await fetchImpl(url, {
    method: 'POST',
    headers: { Authorization: `Basic ${authorization}`, 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams(form)
  });
  if (!response.ok) throw new Error(`Twilio ${resource} request failed with status ${response.status}`);
  const result = await response.json();
  return result.sid;
}

export function createSafetyServer(config = process.env, fetchImpl = fetch) {
  const hasCredentials = Boolean(config.TWILIO_API_KEY_SID && config.TWILIO_API_KEY_SECRET) || Boolean(config.TWILIO_AUTH_TOKEN);
  const ready = required.every(key => Boolean(config[key])) && hasCredentials && Boolean(normalizePhone(config.PARENT_PHONE));
  const completed = new Map();
  const inFlight = new Map();
  const lastByEvent = new Map();

  async function deliver(event) {
    const now = Date.now();
    const cooldown = event.event === 'possibleCrash' ? 10 * 60_000 : 30_000;
    const last = lastByEvent.get(event.event) ?? 0;
    if (now - last < cooldown) throw new RequestError(429, 'Please wait before sending another update');

    const messageSid = await twilioCreate(config, 'Messages', {
      To: event.recipient, From: config.TWILIO_FROM_NUMBER, Body: messageFor(event)
    }, fetchImpl);
    if (event.event !== 'possibleCrash') {
      lastByEvent.set(event.event, now);
      return { status: 'queued', messageSid };
    }

    lastByEvent.set(event.event, now);
    const speech = `RouteRisk noticed a possible crash during a trip to ${event.destination}. Please contact your child to check on them. This is not a confirmed crash.`;
    const callSid = await twilioCreate(config, 'Calls', {
      To: event.recipient,
      From: config.TWILIO_FROM_NUMBER,
      Twiml: `<Response><Say>${xmlEscape(speech)}</Say></Response>`
    }, fetchImpl);
    return { status: 'queued', messageSid, callSid };
  }

  return createHTTPServer(async (request, response) => {
    if (request.method === 'GET' && request.url === '/health') {
      if (!ready) { json(response, 503, { ready: false }); return; }
      if (!authorized(request.headers.authorization, config.ROUTERISK_PAIRING_TOKEN)) {
        json(response, 401, { error: 'Unauthorized' });
        return;
      }
      json(response, 200, { ready: true });
      return;
    }
    if (request.method !== 'POST' || request.url !== '/api/notify') {
      json(response, 404, { error: 'Not found' });
      return;
    }
    if (!ready) { json(response, 503, { error: 'Service not configured' }); return; }
    if (!authorized(request.headers.authorization, config.ROUTERISK_PAIRING_TOKEN)) {
      json(response, 401, { error: 'Unauthorized' });
      return;
    }
    try {
      const event = validate(await readJSON(request), config.PARENT_PHONE);
      const existing = completed.get(event.eventID);
      if (existing) { json(response, 200, existing); return; }
      let pending = inFlight.get(event.eventID);
      if (!pending) {
        pending = deliver(event);
        inFlight.set(event.eventID, pending);
      }
      let result;
      try { result = await pending; }
      finally { inFlight.delete(event.eventID); }
      completed.set(event.eventID, result);
      setTimeout(() => completed.delete(event.eventID), 60 * 60_000).unref();
      json(response, 200, result);
    } catch (error) {
      const status = error instanceof RequestError ? error.status : 502;
      json(response, status, { error: error instanceof RequestError ? error.message : 'Delivery failed' });
    }
  });
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const server = createSafetyServer();
  const port = Number(process.env.PORT ?? 8787);
  const host = process.env.HOST ?? '127.0.0.1';
  server.listen(port, host, () => {
    process.stdout.write(`RouteRisk safety service listening on ${host}:${port}\n`);
  });
}
