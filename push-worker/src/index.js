// خادم تنبيهات هَدْي — Cloudflare Worker + D1
//
// الفكرة: التطبيق يرسل إلى الخادم قائمة بمواعيد التنبيهات القادمة (أرقام فقط).
// كل دقيقة يفحص الخادم (Cron) المواعيد المستحقة ويرسل Web Push فارغاً إلى الجهاز،
// فيستيقظ عامل الخدمة في الجهاز ويعرض التنبيه (التفاصيل محفوظة في الجهاز نفسه).

const PUSH_HOST = /(^|\.)(googleapis\.com|push\.services\.mozilla\.com|push\.apple\.com|notify\.windows\.com)$/;
const MAX_TIMES = 800;
const MAX_BODY = 64 * 1024;
const PER_RUN = 40; // حد الطلبات الخارجية في الخطة المجانية ≈ 50 لكل تشغيل

// ───────────── أدوات ─────────────
const enc = new TextEncoder();

function b64url(buf) {
  const bytes = buf instanceof Uint8Array ? buf : new Uint8Array(buf);
  let s = '';
  for (let i = 0; i < bytes.length; i++) s += String.fromCharCode(bytes[i]);
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function b64urlToBytes(str) {
  const p = str.replace(/-/g, '+').replace(/_/g, '/') + '==='.slice((str.length + 3) % 4);
  const raw = atob(p);
  const out = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) out[i] = raw.charCodeAt(i);
  return out;
}

let vapidCache = null;

async function getVapid(env) {
  if (vapidCache) return vapidCache;
  const jwk = JSON.parse(env.VAPID_PRIVATE_JWK);
  const key = await crypto.subtle.importKey(
    'jwk',
    { kty: jwk.kty, crv: jwk.crv, x: jwk.x, y: jwk.y, d: jwk.d },
    { name: 'ECDSA', namedCurve: 'P-256' },
    false,
    ['sign']
  );
  const x = b64urlToBytes(jwk.x);
  const y = b64urlToBytes(jwk.y);
  const raw = new Uint8Array(65);
  raw[0] = 4;
  raw.set(x, 1);
  raw.set(y, 33);
  vapidCache = { key, publicKey: b64url(raw) };
  return vapidCache;
}

export async function vapidAuth(env, endpoint) {
  const { key, publicKey } = await getVapid(env);
  const head = b64url(enc.encode(JSON.stringify({ typ: 'JWT', alg: 'ES256' })));
  const body = b64url(
    enc.encode(
      JSON.stringify({
        aud: new URL(endpoint).origin,
        exp: Math.floor(Date.now() / 1000) + 12 * 3600,
        sub: env.VAPID_SUBJECT || 'mailto:admin@example.com'
      })
    )
  );
  const sig = await crypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, key, enc.encode(head + '.' + body));
  return `vapid t=${head}.${body}.${b64url(sig)}, k=${publicKey}`;
}

function allowedEndpoint(env, endpoint) {
  try {
    const u = new URL(endpoint);
    if (env.ALLOW_ANY_PUSH_HOST === '1') return true; // للاختبار المحلي فقط
    return u.protocol === 'https:' && PUSH_HOST.test(u.hostname);
  } catch (_) {
    return false;
  }
}

function cors(env, extra) {
  return {
    'Access-Control-Allow-Origin': env.ALLOWED_ORIGIN || '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Access-Control-Max-Age': '86400',
    ...(extra || {})
  };
}

function json(env, data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: cors(env, { 'Content-Type': 'application/json; charset=utf-8' })
  });
}

// ───────────── المسارات ─────────────
async function handleSubscribe(request, env) {
  const text = await request.text();
  if (text.length > MAX_BODY) return json(env, { error: 'too large' }, 413);
  let data;
  try {
    data = JSON.parse(text);
  } catch (_) {
    return json(env, { error: 'bad json' }, 400);
  }
  const endpoint = data && data.subscription && data.subscription.endpoint;
  if (!endpoint || !allowedEndpoint(env, endpoint)) return json(env, { error: 'bad endpoint' }, 400);

  const now = Math.floor(Date.now() / 1000);
  const times = Array.from(
    new Set(
      (Array.isArray(data.times) ? data.times : [])
        .map((t) => Math.floor(Number(t)))
        .filter((t) => Number.isFinite(t) && t > now - 3600 && t < now + 8 * 86400)
    )
  ).slice(0, MAX_TIMES);

  const stmts = [
    env.DB.prepare(
      'INSERT INTO subs (endpoint, created, last_seen) VALUES (?1, ?2, ?2) ' +
        'ON CONFLICT(endpoint) DO UPDATE SET last_seen = ?2'
    ).bind(endpoint, now),
    env.DB.prepare('DELETE FROM due WHERE endpoint = ?1').bind(endpoint)
  ];
  for (let i = 0; i < times.length; i += 50) {
    const chunk = times.slice(i, i + 50);
    const marks = chunk.map((_, j) => `(?1, ?${j + 2})`).join(',');
    stmts.push(env.DB.prepare(`INSERT OR IGNORE INTO due (endpoint, t) VALUES ${marks}`).bind(endpoint, ...chunk));
  }
  await env.DB.batch(stmts);
  return json(env, { ok: true, count: times.length });
}

async function handleUnsubscribe(request, env) {
  let data;
  try {
    data = await request.json();
  } catch (_) {
    return json(env, { error: 'bad json' }, 400);
  }
  const endpoint = data && data.endpoint;
  if (!endpoint) return json(env, { error: 'bad endpoint' }, 400);
  await env.DB.batch([
    env.DB.prepare('DELETE FROM due WHERE endpoint = ?1').bind(endpoint),
    env.DB.prepare('DELETE FROM subs WHERE endpoint = ?1').bind(endpoint)
  ]);
  return json(env, { ok: true });
}

// ───────────── الإرسال المجدول ─────────────
export async function sendPush(env, endpoint) {
  const res = await fetch(endpoint, {
    method: 'POST',
    headers: {
      Authorization: await vapidAuth(env, endpoint),
      TTL: '900',
      Urgency: 'high'
    }
  });
  return res.status;
}

export async function runDue(env, nowMs = Date.now()) {
  const now = Math.floor(nowMs / 1000);
  const horizon = now + 20;

  await env.DB.batch([
    env.DB.prepare('DELETE FROM due WHERE t < ?1').bind(now - 1800),
    env.DB.prepare('DELETE FROM subs WHERE last_seen < ?1').bind(now - 30 * 86400),
    env.DB.prepare('DELETE FROM due WHERE endpoint NOT IN (SELECT endpoint FROM subs)')
  ]);

  const rows = await env.DB.prepare('SELECT DISTINCT endpoint FROM due WHERE t <= ?1 LIMIT ?2')
    .bind(horizon, PER_RUN)
    .all();

  const results = [];
  for (const r of rows.results || []) {
    let status = 0;
    try {
      status = await sendPush(env, r.endpoint);
    } catch (_) {
      status = 0;
    }
    if (status >= 200 && status < 300) {
      await env.DB.prepare('DELETE FROM due WHERE endpoint = ?1 AND t <= ?2').bind(r.endpoint, horizon).run();
    } else if (status === 404 || status === 410) {
      await env.DB.batch([
        env.DB.prepare('DELETE FROM due WHERE endpoint = ?1').bind(r.endpoint),
        env.DB.prepare('DELETE FROM subs WHERE endpoint = ?1').bind(r.endpoint)
      ]);
    }
    // أي خطأ آخر: نترك الصفوف وتُعاد المحاولة في الدقيقة التالية (حتى 30 دقيقة).
    results.push({ endpoint: r.endpoint, status });
  }
  return results;
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors(env) });
    try {
      if (url.pathname === '/config' && request.method === 'GET') {
        const { publicKey } = await getVapid(env);
        return json(env, { publicKey });
      }
      if (url.pathname === '/subscribe' && request.method === 'POST') return await handleSubscribe(request, env);
      if (url.pathname === '/unsubscribe' && request.method === 'POST') return await handleUnsubscribe(request, env);
      if (url.pathname === '/') return new Response('hady-push ok', { headers: cors(env) });
      return json(env, { error: 'not found' }, 404);
    } catch (e) {
      return json(env, { error: String((e && e.message) || e) }, 500);
    }
  },

  async scheduled(_event, env, ctx) {
    ctx.waitUntil(runDue(env));
  }
};
