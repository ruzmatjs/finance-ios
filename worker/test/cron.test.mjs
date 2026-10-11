/**
 * Cron dispatch testlari: qaysi jadval qaysi xabarni yuboradi.
 * Telegram API va KV mock qilinadi - tashqi so'rov ketmaydi.
 * Ishga tushirish: cd worker && npm test
 */
import worker from '../src/index.js';

let pass = 0, fail = 0;
const ok = (cond, label, extra) => {
  if (cond) { pass++; console.log('  ✅ ' + label); }
  else { fail++; console.log('  ❌ ' + label + (extra ? ' — ' + extra : '')); }
};

/** KV namespace mock'i. */
function kv(records) {
  const store = new Map(Object.entries(records));
  return {
    get: async (k, type) => {
      const v = store.get(k);
      if (v === undefined) return null;
      return type === 'json' ? JSON.parse(JSON.stringify(v)) : String(v);
    },
    put: async (k, v) => { store.set(k, JSON.parse(v)); },
    list: async ({ prefix }) => ({
      keys: [...store.keys()].filter((k) => k.startsWith(prefix)).map((name) => ({ name })),
      list_complete: true,
    }),
  };
}

/** Telegram'ga ketgan sendMessage chaqiruvlarini to'playdi. */
function captureTelegram() {
  const sent = [];
  const real = globalThis.fetch;
  globalThis.fetch = async (url, init) => {
    const body = JSON.parse(init.body);
    sent.push({ method: String(url).split('/').pop(), chat: body.chat_id, text: body.text || '' });
    return new Response(JSON.stringify({ ok: true, result: {} }),
      { headers: { 'Content-Type': 'application/json' } });
  };
  return { sent, restore: () => { globalThis.fetch = real; } };
}

/** scheduled()'ni chaqirib, yuborilgan xabarlarni qaytaradi. */
async function runCron(cron, scheduledTime, records) {
  const cap = captureTelegram();
  const tasks = [];
  const env = { TELEGRAM_BOT_TOKEN: 'x', MINIAPP_URL: 'https://example.test/', REPORTS: kv(records) };
  try {
    await worker.scheduled({ cron, scheduledTime: scheduledTime.getTime() }, env,
      { waitUntil: (p) => tasks.push(p) });
    await Promise.all(tasks);
  } finally {
    cap.restore();
  }
  return cap.sent;
}

const iso = (y, m, d, h = 12) => new Date(Date.UTC(y, m - 1, d, h) - 5 * 3600000).toISOString();

const fullRec = (over) => ({
  chatId: 42,
  cur: 'soʻm',
  months: { '2026-09': { income: 5000000, expense: 1500000, cats: [['Ovqat', 1500000]], incCats: [['Maosh', 5000000]], txCount: 4 } },
  pending: [],
  state: {
    accounts: [{ id: 'cash', name: 'Naqd', opening: 1000000 }],
    budgets: [], recurring: [], debts: [], cats: [],
    tx: [{ id: 't1', type: 'expense', amount: 200000, cat: 'Ovqat', accountId: 'cash', date: iso(2026, 10, 3) }],
    deletedIds: [],
  },
  ...over,
});

// ---------- Kunlik cron ----------
console.log('\n— Kunlik cron (0 3 * * *) —');
{
  // 11-oktabr 03:00 UTC = 08:00 Toshkent
  const sent = await runCron('0 3 * * *', new Date(Date.UTC(2026, 9, 11, 3)), { 'u:42': fullRec() });
  ok(sent.length === 1, 'bitta xabar yuborildi', 'keldi ' + sent.length);
  ok(sent[0] && sent[0].text.includes('☀️') && sent[0].text.includes('11-oktabr'),
    'ertalabki xabar yuborildi', sent[0] && sent[0].text.split('\n')[0]);
  ok(sent[0] && !sent[0].text.includes('oylik hisobot'), 'oylik hisobot yuborilmadi');
}

// ---------- /ertalab bilan o'chirilgan ----------
console.log('\n— morning: false —');
{
  const sent = await runCron('0 3 * * *', new Date(Date.UTC(2026, 9, 11, 3)),
    { 'u:42': fullRec({ morning: false }) });
  ok(sent.length === 0, 'o‘chirilgan yozuvga xabar ketmadi', 'keldi ' + sent.length);
}

// ---------- morning: true aniq yoqilgan ----------
console.log('\n— morning: true —');
{
  const sent = await runCron('0 3 * * *', new Date(Date.UTC(2026, 9, 11, 3)),
    { 'u:42': fullRec({ morning: true }) });
  ok(sent.length === 1, 'yoqilgan yozuvga xabar ketdi', 'keldi ' + sent.length);
}

// ---------- State yo'q ----------
console.log('\n— state yo‘q —');
{
  const sent = await runCron('0 3 * * *', new Date(Date.UTC(2026, 9, 11, 3)),
    { 'u:42': fullRec({ state: null }) });
  ok(sent.length === 0, 'sinxronlanmagan yozuvga xabar ketmadi', 'keldi ' + sent.length);
}

// ---------- Oylik cron ----------
console.log('\n— Oylik cron (0 5 1 * *) —');
{
  // 1-oktabr 05:00 UTC -> o'tgan oy = sentabr
  const sent = await runCron('0 5 1 * *', new Date(Date.UTC(2026, 9, 1, 5)), { 'u:42': fullRec() });
  ok(sent.length === 1, 'bitta xabar yuborildi', 'keldi ' + sent.length);
  ok(sent[0] && sent[0].text.includes('Sentabr 2026 — oylik hisobot'),
    'o‘tgan oy hisoboti yuborildi', sent[0] && sent[0].text.split('\n')[0]);
  ok(sent[0] && !sent[0].text.includes('☀️'), 'ertalabki xabar yuborilmadi');
}

// ---------- Oylik cron: morning:false ta'sir qilmaydi ----------
console.log('\n— Oylik cron, morning: false —');
{
  const sent = await runCron('0 5 1 * *', new Date(Date.UTC(2026, 9, 1, 5)),
    { 'u:42': fullRec({ morning: false }) });
  ok(sent.length === 1, 'ertalabki xabar o‘chirilgani oylik hisobotga ta’sir qilmaydi',
    'keldi ' + sent.length);
}

// ---------- Oylik cron: o'tgan oyda tranzaksiya yo'q ----------
console.log('\n— Oylik cron, ma’lumot yo‘q —');
{
  const sent = await runCron('0 5 1 * *', new Date(Date.UTC(2026, 9, 1, 5)),
    { 'u:42': fullRec({ months: {}, state: { ...fullRec().state, tx: [] } }) });
  ok(sent.length === 0, 'bo‘sh oyga hisobot yuborilmaydi', 'keldi ' + sent.length);
}

// ---------- Bitta yozuvdagi xato qolganini to'xtatmasligi ----------
console.log('\n— Xato izolyatsiyasi —');
{
  const sent = await runCron('0 3 * * *', new Date(Date.UTC(2026, 9, 11, 3)), {
    'u:1': 'buzilgan-json-emas-obyekt',
    'u:42': fullRec(),
  });
  ok(sent.length === 1, 'buzilgan yozuv qolganini to‘xtatmadi', 'keldi ' + sent.length);
}

// ---------- chatId yo'q yozuv ----------
console.log('\n— chatId yo‘q —');
{
  const sent = await runCron('0 3 * * *', new Date(Date.UTC(2026, 9, 11, 3)),
    { 'u:42': fullRec({ chatId: null }) });
  ok(sent.length === 0, 'chatId yo‘q yozuv o‘tkazib yuborildi', 'keldi ' + sent.length);
}

console.log('\n' + pass + ' o‘tdi, ' + fail + ' xato\n');
process.exit(fail ? 1 : 0);
