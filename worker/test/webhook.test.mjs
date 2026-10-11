/**
 * Webhook testlari: buyruq -> botning haqiqiy javob matni.
 * Telegram API va KV mock qilinadi, tashqi so'rov ketmaydi.
 * Ishga tushirish: cd worker && npm test
 */
import worker from '../src/index.js';

let pass = 0, fail = 0;
const ok = (cond, label, extra) => {
  if (cond) { pass++; console.log('  ✅ ' + label); }
  else { fail++; console.log('  ❌ ' + label + (extra ? ' — ' + extra : '')); }
};

const SECRET = 'testsecret';
const UID = 42;

function kv(records) {
  const store = new Map(Object.entries(records));
  return {
    get: async (k, type) => {
      const v = store.get(k);
      if (v === undefined) return null;
      return type === 'json' ? JSON.parse(JSON.stringify(v)) : String(v);
    },
    put: async (k, v) => { store.set(k, typeof v === 'string' && v.startsWith('{') ? JSON.parse(v) : v); },
    list: async ({ prefix }) => ({
      keys: [...store.keys()].filter((k) => k.startsWith(prefix)).map((name) => ({ name })),
      list_complete: true,
    }),
    _store: store,
  };
}

/** Botga xabar yuboradi va Telegram'ga ketgan chaqiruvlarni qaytaradi. */
async function send(text, records, envOver) {
  const sent = [];
  const real = globalThis.fetch;
  globalThis.fetch = async (url, init) => {
    const body = JSON.parse(init.body);
    sent.push({ method: String(url).split('/').pop(), chat: body.chat_id, text: body.text || '', kb: body.reply_markup });
    return new Response(JSON.stringify({ ok: true, result: {} }), { headers: { 'Content-Type': 'application/json' } });
  };
  const store = kv(records);
  const env = {
    TELEGRAM_BOT_TOKEN: 'tok', WEBHOOK_SECRET: SECRET,
    MINIAPP_URL: 'https://example.test/', REPORTS: store, ...envOver,
  };
  const tasks = [];
  try {
    const res = await worker.fetch(new Request('https://w.test/webhook', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'X-Telegram-Bot-Api-Secret-Token': SECRET },
      body: JSON.stringify({ update_id: 1, message: { message_id: 1, chat: { id: UID }, from: { id: UID, first_name: 'Test' }, text } }),
    }), env, { waitUntil: (p) => tasks.push(p) });
    await Promise.all(tasks);
    return { status: res.status, sent, store };
  } finally {
    globalThis.fetch = real;
  }
}

const iso = (y, m, d, h = 12) => new Date(Date.UTC(y, m - 1, d, h) - 5 * 3600000).toISOString();
const today = () => new Date().toISOString();

const rec = (over) => ({
  chatId: UID, cur: 'soʻm', months: {}, pending: [],
  state: {
    accounts: [{ id: 'cash', name: 'Naqd', e: '💵', opening: 2000000 }],
    cats: [{ n: 'Ovqat', e: '🍔', t: 'expense' }, { n: 'Boshqa', e: '📦', t: 'expense' },
      { n: 'Maosh', e: '💰', t: 'income' }],
    budgets: [{ id: 'b1', name: 'Umumiy', limit: 3000000, period: 'monthly', catIds: [] }],
    recurring: [], debts: [],
    tx: [{ id: 't1', type: 'expense', amount: 500000, cat: 'Ovqat', accountId: 'cash', date: today() }],
    deletedIds: [],
  },
  ...over,
});

// ---------- /bugun ----------
console.log('\n— /bugun —');
{
  const r = await send('/bugun', { 'owner': String(UID), 'u:42': rec() });
  ok(r.status === 200, 'webhook 200 qaytardi', String(r.status));
  ok(r.sent.length === 1, 'bitta javob yuborildi', 'keldi ' + r.sent.length);
  const t = r.sent[0] ? r.sent[0].text : '';
  ok(t.includes('☀️'), 'ertalabki xabar matni keldi', JSON.stringify(t.slice(0, 120)));
  ok(t.includes('Qoldiq: <b>1 500 000'), 'qoldiq to‘g‘ri (2 000 000 − 500 000)', t);
  ok(t.includes('Byudjetdan'), 'byudjet qatori bor', t);
  ok(r.sent[0] && r.sent[0].kb, 'Mini App tugmasi qo‘shilgan');
}

// ---------- /bugun, state yo'q ----------
console.log('\n— /bugun, state yo‘q —');
{
  const r = await send('/bugun', { 'owner': String(UID), 'u:42': rec({ state: null }) });
  ok(r.sent.length === 1 && r.sent[0].text.includes('Maʼlumot yoʻq'),
    'sinxronlashtirish haqida ogohlantirdi', r.sent[0] && r.sent[0].text);
}

// ---------- /bugun, KV'da yozuv umuman yo'q ----------
console.log('\n— /bugun, yangi foydalanuvchi —');
{
  const r = await send('/bugun', { 'owner': String(UID) });
  ok(r.sent.length === 1 && r.sent[0].text.includes('Maʼlumot yoʻq'),
    'bo‘sh KV bilan ham yiqilmadi', r.sent[0] && r.sent[0].text);
}

// ---------- /ertalab ----------
console.log('\n— /ertalab —');
{
  const r = await send('/ertalab', { 'owner': String(UID), 'u:42': rec() });
  ok(r.sent.length === 1 && r.sent[0].text.includes('oʻchirildi'),
    'standart holatda yoqilgan -> o‘chiradi', r.sent[0] && r.sent[0].text);
  ok(r.store._store.get('u:42').morning === false, 'KV\'ga morning:false yozildi',
    JSON.stringify(r.store._store.get('u:42').morning));

  const r2 = await send('/ertalab', { 'owner': String(UID), 'u:42': rec({ morning: false }) });
  ok(r2.sent[0].text.includes('yoqildi'), 'o‘chirilgan holatda -> yoqadi', r2.sent[0].text);
  ok(r2.store._store.get('u:42').morning === true, 'KV\'ga morning:true yozildi');
}

// ---------- Qolgan buyruqlar ----------
console.log('\n— Qolgan buyruqlar —');
for (const [cmd, expect] of [
  ['/start', 'FinanceApp boti'],
  ['/help', 'Buyruqlar'],
  ['/balans', 'Hisoblar'],
  ['/oy', 'oylik hisobot'],
  ['/bekor', 'yoʻq'],
]) {
  const r = await send(cmd, { 'owner': String(UID), 'u:42': rec() });
  const t = r.sent[0] ? r.sent[0].text : '(javob yo‘q)';
  ok(r.sent.length === 1 && t.includes(expect), cmd + ' javob berdi', JSON.stringify(t.slice(0, 100)));
}

// ---------- /help ichida yangi buyruqlar bor ----------
console.log('\n— /help to‘liqligi —');
{
  const r = await send('/help', { 'owner': String(UID), 'u:42': rec() });
  const t = r.sent[0].text;
  for (const c of ['/bugun', '/balans', '/oy', '/hisobot', '/bekor', '/ertalab'])
    ok(t.includes(c), 'yordamda ' + c + ' bor');
}

// ---------- Noma'lum buyruq ----------
console.log('\n— Noma’lum buyruq —');
{
  const r = await send('/qwerty', { 'owner': String(UID), 'u:42': rec() });
  ok(r.sent[0].text.includes('Bunday buyruq yoʻq'), 'noma’lum buyruq haqida aytdi', r.sent[0].text);
}

// ---------- Guruhdagi @bot qo'shimchasi ----------
console.log('\n— /bugun@bot_nomi —');
{
  const r = await send('/bugun@ruzmat_finance_bot', { 'owner': String(UID), 'u:42': rec() });
  ok(r.sent.length === 1 && r.sent[0].text.includes('☀️'),
    '@bot qo‘shimchasi bilan ham ishlaydi', r.sent[0] && r.sent[0].text.slice(0, 80));
}

// ---------- Matn orqali kirim ----------
console.log('\n— Matn orqali kirim —');
{
  const r = await send('ovqat 25k', { 'owner': String(UID), 'u:42': rec() });
  ok(r.sent[0].text.includes('Ovqat') && r.sent[0].text.includes('25 000'),
    'tasdiq xabari keldi', r.sent[0].text);
  ok((r.store._store.get('u:42').pending || []).length === 1, 'pending\'ga yozildi');
}

// ---------- Ega bo'lmagan foydalanuvchi ----------
console.log('\n— Begona foydalanuvchi —');
{
  const r = await send('/bugun', { 'owner': '999', 'u:42': rec() });
  ok(r.sent.length === 1 && r.sent[0].text === 'Bu shaxsiy bot.',
    'begonaga buyruq bajarilmadi', r.sent[0] && r.sent[0].text);
}

// ---------- OWNER_ID env ustun turadi ----------
console.log('\n— OWNER_ID env —');
{
  // KV'da boshqa ega yozilgan bo'lsa ham OWNER_ID ustun
  const r = await send('/bugun', { 'owner': '999', 'u:42': rec() }, { OWNER_ID: String(UID) });
  ok(r.sent[0].text.includes('☀️'), 'OWNER_ID KV\'dagi egani bekor qiladi',
    r.sent[0] && r.sent[0].text.slice(0, 80));

  const r2 = await send('/bugun', { 'u:42': rec() }, { OWNER_ID: '999' });
  ok(r2.sent[0].text === 'Bu shaxsiy bot.', 'OWNER_ID mos kelmasa rad etadi', r2.sent[0].text);
}

// ---------- Noto'g'ri secret ----------
console.log('\n— Secret tekshiruvi —');
{
  const real = globalThis.fetch;
  globalThis.fetch = async () => new Response('{}');
  const env = { TELEGRAM_BOT_TOKEN: 'tok', WEBHOOK_SECRET: SECRET, REPORTS: kv({}) };
  const res = await worker.fetch(new Request('https://w.test/webhook', {
    method: 'POST', headers: { 'Content-Type': 'application/json', 'X-Telegram-Bot-Api-Secret-Token': 'yolgon' },
    body: JSON.stringify({ update_id: 1, message: { message_id: 1, chat: { id: UID }, from: { id: UID }, text: '/bugun' } }),
  }), env, { waitUntil: () => {} });
  globalThis.fetch = real;
  ok(res.status === 403, 'noto‘g‘ri secret 403', String(res.status));
}

// ---------- Token yo'q bo'lganda tekshiruv tartibi ----------
// Avval chaqiruvchi tasdiqlanishi kerak, keyingina sozlama holati aytilishi
console.log('\n— Token sozlanmaganda —');
{
  const call = async (path, headers, env) => {
    const real = globalThis.fetch;
    globalThis.fetch = async () => new Response('{}');
    try {
      return await worker.fetch(new Request('https://w.test' + path, {
        method: 'POST', headers: { 'Content-Type': 'application/json', ...headers },
        body: JSON.stringify({ update_id: 1, message: { message_id: 1, chat: { id: UID }, from: { id: UID }, text: '/bugun' } }),
      }), { WEBHOOK_SECRET: SECRET, REPORTS: kv({}), ...env }, { waitUntil: () => {} });
    } finally { globalThis.fetch = real; }
  };

  let res = await call('/webhook', {});
  ok(res.status === 403, 'tokensiz webhook: secret\'siz chaqiruv 403 (500 emas)', String(res.status));

  res = await call('/webhook', { 'X-Telegram-Bot-Api-Secret-Token': 'yolgon' });
  ok(res.status === 403, 'tokensiz webhook: noto‘g‘ri secret 403', String(res.status));

  // To'g'ri secret bilan 200 - aks holda Telegram update'ni soatlab qayta yuboradi
  res = await call('/webhook', { 'X-Telegram-Bot-Api-Secret-Token': SECRET });
  ok(res.status === 200, 'tokensiz webhook: to‘g‘ri secret 200 (Telegram qayta yubormasligi uchun)',
    String(res.status));

  // /setup: avval secret, keyin token holati
  const real = globalThis.fetch;
  globalThis.fetch = async () => new Response('{}');
  const env = { WEBHOOK_SECRET: SECRET, REPORTS: kv({}) };
  let r1 = await worker.fetch(new Request('https://w.test/setup?secret=yolgon'), env, { waitUntil: () => {} });
  let r2 = await worker.fetch(new Request('https://w.test/setup?secret=' + SECRET), env, { waitUntil: () => {} });
  globalThis.fetch = real;
  ok(r1.status === 403, '/setup: noto‘g‘ri secret 403 (token holati oshkor qilinmaydi)', String(r1.status));
  const b2 = await r2.json();
  ok(r2.status === 500 && /TELEGRAM_BOT_TOKEN/.test(b2.error || ''),
    '/setup: to‘g‘ri secret bilan token muammosi aytiladi', JSON.stringify(b2));
}

console.log('\n' + pass + ' o‘tdi, ' + fail + ' xato\n');
process.exit(fail ? 1 : 0);
