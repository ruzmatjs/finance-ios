/**
 * FinanceApp - Telegram hisobot Worker'i
 *
 * Mini App (docs/index.html) oylik jamlanmani shu yerga yuboradi, Worker esa
 * bot orqali foydalanuvchining shaxsiy chatiga xabar tashlaydi.
 * Bot tokeni faqat shu yerda (Cloudflare secret) - mijoz kodida hech qachon bo'lmaydi.
 *
 * Endpointlar:
 *   POST /sync    {initData, months, cur}  -> jamlanmani KV'ga saqlaydi
 *   POST /report  {initData, month, cur}   -> hisobotni darhol yuboradi
 *   GET  /                                 -> holat
 * Cron: har oyning 1-sanasi 05:00 UTC (10:00 Toshkent) - o'tgan oy hisoboti.
 */

const MONTHS = ['', 'Yanvar', 'Fevral', 'Mart', 'Aprel', 'May', 'Iyun',
  'Iyul', 'Avgust', 'Sentabr', 'Oktabr', 'Noyabr', 'Dekabr'];

const enc = new TextEncoder();

async function hmac(keyBytes, msg) {
  const key = await crypto.subtle.importKey('raw', keyBytes, { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  return new Uint8Array(await crypto.subtle.sign('HMAC', key, enc.encode(msg)));
}

const toHex = (buf) => [...buf].map((b) => b.toString(16).padStart(2, '0')).join('');

/** Telegram Mini App initData imzosini tekshiradi. Muvaffaqiyatda user obyektini qaytaradi. */
async function verifyInitData(initData, botToken, maxAgeSec = 86400) {
  if (!initData) return null;
  const params = new URLSearchParams(initData);
  const hash = params.get('hash');
  if (!hash) return null;
  params.delete('hash');

  const checkString = [...params.entries()]
    .sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0))
    .map(([k, v]) => k + '=' + v)
    .join('\n');

  const secret = await hmac(enc.encode('WebAppData'), botToken);
  const sig = toHex(await hmac(secret, checkString));
  if (sig !== hash) return null;

  const authDate = parseInt(params.get('auth_date') || '0', 10);
  if (!authDate || (Date.now() / 1000 - authDate) > maxAgeSec) return null;

  try { return JSON.parse(params.get('user') || 'null'); } catch { return null; }
}

const fmtNum = (n) => String(Math.round(Math.abs(n || 0))).replace(/\B(?=(\d{3})+(?!\d))/g, ' ');
const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

function monthTitle(mk) {
  const [y, m] = mk.split('-');
  return MONTHS[parseInt(m, 10)] + ' ' + y;
}

/** Kategoriyalar ro'yxatini raqamlangan satrlarga aylantiradi. */
function catLines(cats, total) {
  return cats.map(([name, sum], i) => {
    const pct = total > 0 ? Math.round((sum / total) * 100) : 0;
    return (i + 1) + '. ' + esc(name) + ' — ' + fmtNum(sum) + ' (' + pct + '%)';
  });
}

/** {income, expense, cats, incCats} -> HTML xabar (to'liq daromad/xarajat taqsimoti) */
function buildReport(mk, d, cur) {
  cur = cur || 'soʻm';
  const income = d.income || 0;
  const expense = d.expense || 0;
  const net = income - expense;
  const expCats = d.cats || [];
  const incCats = d.incCats || [];

  const lines = [
    '📊 <b>' + monthTitle(mk) + ' — oylik hisobot</b>',
    '',
    '💰 Daromad:  <b>' + fmtNum(income) + ' ' + cur + '</b>',
    '💸 Xarajat:  <b>' + fmtNum(expense) + ' ' + cur + '</b>',
    (net >= 0 ? '📈' : '📉') + ' Qoldiq:   <b>' + (net >= 0 ? '+' : '−') + fmtNum(net) + ' ' + cur + '</b>',
  ];

  if (net >= 0 && income > 0) {
    lines.push('', 'Daromadning <b>' + Math.round((net / income) * 100) + '%</b> i qoldi.');
  } else if (net < 0) {
    lines.push('', '⚠️ Xarajat daromaddan <b>' + fmtNum(-net) + ' ' + cur + '</b> koʻp.');
  }

  if (incCats.length) {
    lines.push('', '💰 <b>Daromadlar</b> (' + incCats.length + ' ta kategoriya)');
    lines.push(...catLines(incCats, income));
  }

  if (expCats.length) {
    lines.push('', '💸 <b>Xarajatlar</b> (' + expCats.length + ' ta kategoriya)');
    lines.push(...catLines(expCats, expense));
  }

  if (d.txCount) lines.push('', '<i>Jami ' + d.txCount + ' ta tranzaksiya</i>');

  let text = lines.join('\n');
  if (text.length > 3900) text = text.slice(0, 3880) + '\n…';
  return text;
}

async function sendMessage(token, chatId, text, miniAppUrl) {
  const post = (body) => fetch('https://api.telegram.org/bot' + token + '/sendMessage', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  }).then((r) => r.json());

  const body = { chat_id: chatId, text, parse_mode: 'HTML' };
  if (miniAppUrl) {
    body.reply_markup = { inline_keyboard: [[{ text: '📊 Ilovada ochish', web_app: { url: miniAppUrl } }]] };
  }

  let res = await post(body);
  if (!res.ok && body.reply_markup) {
    delete body.reply_markup;
    res = await post(body);
  }
  return res;
}

const json = (obj, status) => new Response(JSON.stringify(obj), {
  status: status || 200,
  headers: {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
  },
});

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (request.method === 'OPTIONS') return json({ ok: true });
    if (url.pathname === '/') return json({ ok: true, service: 'finance-report-worker' });

    if (!env.TELEGRAM_BOT_TOKEN) return json({ ok: false, error: 'TELEGRAM_BOT_TOKEN sozlanmagan' }, 500);
    if (request.method !== 'POST') return json({ ok: false, error: 'POST kutilgan' }, 405);

    let body;
    try { body = await request.json(); } catch (e) { return json({ ok: false, error: 'JSON xato' }, 400); }

    const user = await verifyInitData(body.initData, env.TELEGRAM_BOT_TOKEN);
    if (!user || !user.id) return json({ ok: false, error: 'initData tasdiqlanmadi' }, 401);

    if (url.pathname !== '/sync' && url.pathname !== '/report') {
      return json({ ok: false, error: 'Notoʻgʻri manzil' }, 404);
    }

    const key = 'u:' + user.id;
    const prev = (await env.REPORTS.get(key, 'json')) || { months: {} };
    const cur = body.cur || prev.cur || 'soʻm';
    const months = Object.assign({}, prev.months || {}, body.months || {});

    await env.REPORTS.put(key, JSON.stringify({
      chatId: user.id,
      name: user.first_name || '',
      cur,
      months,
      updatedAt: new Date().toISOString(),
    }));

    if (url.pathname === '/sync') return json({ ok: true, saved: Object.keys(months).length });

    const mk = body.month || Object.keys(months).sort().pop();
    if (!mk || !months[mk]) return json({ ok: false, error: 'Bu oy uchun maʼlumot yoʻq' }, 400);

    const res = await sendMessage(env.TELEGRAM_BOT_TOKEN, user.id, buildReport(mk, months[mk], cur), env.MINIAPP_URL);
    return json({ ok: !!res.ok, error: res.description || null, month: mk }, res.ok ? 200 : 502);
  },

  /** Cron: har oyning 1-sanasida o'tgan oy hisobotini yuboradi. */
  async scheduled(event, env, ctx) {
    ctx.waitUntil((async () => {
      const now = new Date(event.scheduledTime);
      const prev = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() - 1, 1));
      const mk = prev.getUTCFullYear() + '-' + String(prev.getUTCMonth() + 1).padStart(2, '0');

      let cursor;
      do {
        const list = await env.REPORTS.list({ prefix: 'u:', cursor });
        for (const k of list.keys) {
          const rec = await env.REPORTS.get(k.name, 'json');
          const data = rec && rec.months ? rec.months[mk] : null;
          if (!rec || !rec.chatId || !data) continue;
          await sendMessage(env.TELEGRAM_BOT_TOKEN, rec.chatId, buildReport(mk, data, rec.cur), env.MINIAPP_URL);
        }
        cursor = list.list_complete ? null : list.cursor;
      } while (cursor);
    })());
  },
};
