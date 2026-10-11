/**
 * FinanceApp - Telegram bot + hisobot Worker'i (shaxsiy, bitta foydalanuvchi uchun)
 *
 * Ikki vazifa bajaradi:
 *   1. Mini App (docs/index.html) bilan sinxronizatsiya va oylik hisobot yuborish.
 *   2. Bot webhook'i: lichkaga matn yozib tranzaksiya kiritish ("ovqat 25k").
 *
 * Bot state'ni O'ZGARTIRMAYDI - faqat KV'dagi `pending[]` massiviga qo'shadi.
 * Mini App ochilganda `/pull` bilan oladi, mavjud mergeStates() bilan birlashtiradi
 * va `/sync` + `ackPending` orqali tasdiqlaydi. Append-only bo'lgani uchun
 * ilova va bot bir vaqtda yozsa ham hech narsa yo'qolmaydi.
 *
 * Endpointlar:
 *   POST /webhook  Telegram update (X-Telegram-Bot-Api-Secret-Token bilan)
 *   GET  /setup    webhook + buyruqlar + menu tugmasini bir marta ro'yxatdan o'tkazadi
 *   POST /sync     {initData, months, state, ackPending?}  -> KV'ga saqlaydi
 *   POST /pull     {initData}                              -> state + pending qaytaradi
 *   POST /report   {initData, month}                       -> hisobotni darhol yuboradi
 *   GET  /                                                 -> holat
 * Cron: har oyning 1-sanasi 05:00 UTC (10:00 Toshkent) - o'tgan oy hisoboti.
 */

const MONTHS = ['', 'Yanvar', 'Fevral', 'Mart', 'Aprel', 'May', 'Iyun',
  'Iyul', 'Avgust', 'Sentabr', 'Oktabr', 'Noyabr', 'Dekabr'];

/** Toshkent vaqti UTC+5 (yoz/qish vaqti yo'q). */
const TZ_OFFSET_MS = 5 * 3600 * 1000;

/** Oylik hisobot jadvali (wrangler.toml dagi bilan bir xil bo'lishi kerak). */
const MONTHLY_CRON = '0 5 1 * *';

/** Kunning rejasi: har kuni 08:00 Toshkent. */
const MORNING_CRON = '0 3 * * *';

/** Xaridlar rejasi eslatmasi: har kuni 09:00 Toshkent. */
const PLAN_CRON = '0 4 * * *';

/**
 * Shu kod nimani biladi. `GET /` javobida qaytariladi - deploy qilingan versiya
 * eskiligini tekshirish uchun. Yangi imkoniyat qo'shilganda shu yerga ham qo'shiladi.
 */
const FEATURES = ['sync', 'report', 'webhook', 'text-entry', 'morning', 'plan-reminder'];

const enc = new TextEncoder();

async function hmac(keyBytes, msg) {
  const key = await crypto.subtle.importKey('raw', keyBytes, { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  return new Uint8Array(await crypto.subtle.sign('HMAC', key, enc.encode(msg)));
}

const toHex = (buf) => [...buf].map((b) => b.toString(16).padStart(2, '0')).join('');

/** Uzunligi teng ikki satrni vaqt oqishidan qat'i nazar solishtiradi. */
function safeEqual(a, b) {
  if (typeof a !== 'string' || typeof b !== 'string' || a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

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
  if (!safeEqual(sig, hash)) return null;

  const authDate = parseInt(params.get('auth_date') || '0', 10);
  if (!authDate || (Date.now() / 1000 - authDate) > maxAgeSec) return null;

  try { return JSON.parse(params.get('user') || 'null'); } catch { return null; }
}

const fmtNum = (n) => String(Math.round(Math.abs(n || 0))).replace(/\B(?=(\d{3})+(?!\d))/g, ' ');
const esc = (s) => String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

const genId = () => Date.now().toString(36) + Math.random().toString(36).slice(2, 6);

function monthTitle(mk) {
  const [y, m] = mk.split('-');
  return MONTHS[parseInt(m, 10)] + ' ' + y;
}

/**
 * Toshkent vaqtidagi "hozir". Qaytgan Date'ning UTC getter'lari (getUTCDate va h.k.)
 * Toshkent taqvimidagi qiymatni beradi - quyidagi hamma hisob shu usulda ishlaydi.
 */
const nowTashkent = () => new Date(Date.now() + TZ_OFFSET_MS);

const monthKeyOf = (d) => d.getUTCFullYear() + '-' + String(d.getUTCMonth() + 1).padStart(2, '0');

const WEEKDAYS = ['yakshanba', 'dushanba', 'seshanba', 'chorshanba', 'payshanba', 'juma', 'shanba'];

// Toshkent taqvimidagi davr boshlanishi, UTC vaqtida (tx.date UTC'da saqlanadi)
const dayStartTash = (d) => new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()) - TZ_OFFSET_MS);
const monthStartTash = (d) => new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), 1) - TZ_OFFSET_MS);
const yearStartTash = (d) => new Date(Date.UTC(d.getUTCFullYear(), 0, 1) - TZ_OFFSET_MS);
/** Hafta dushanbadan boshlanadi (ilovadagi weekStart bilan bir xil). */
const weekStartTash = (d) => new Date(dayStartTash(d).getTime() - ((d.getUTCDay() + 6) % 7) * 86400000);

const periodStartTash = (period, d) => period === 'weekly' ? weekStartTash(d)
  : period === 'yearly' ? yearStartTash(d) : monthStartTash(d);

/** Oydagi kunlar soni va bugundan oy oxirigacha qolgan kun (bugun ham kiradi). */
function monthDays(d) {
  const total = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth() + 1, 0)).getUTCDate();
  return { total, day: d.getUTCDate(), left: total - d.getUTCDate() + 1 };
}

/**
 * Sanani Toshkent taqvimiga keltiradi (ilova sanalarni qurilmaning mahalliy
 * vaqtidan ISO'ga aylantirib saqlaydi, shuning uchun taqqoslashdan oldin surish kerak).
 */
function toTash(iso) {
  const t = new Date(iso);
  return isNaN(t) ? null : new Date(t.getTime() + TZ_OFFSET_MS);
}

/** Toshkent kunlari bo'yicha farq: 0 = bugun, 1 = ertaga, -1 = kecha. */
function daysFromToday(iso, d) {
  const t = toTash(iso);
  if (!t) return null;
  const target = Date.UTC(t.getUTCFullYear(), t.getUTCMonth(), t.getUTCDate());
  const today = Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate());
  return Math.round((target - today) / 86400000);
}

// ============ KV yozuvi ============

const recKey = (id) => 'u:' + id;

async function loadRec(env, id) {
  const rec = await env.REPORTS.get(recKey(id), 'json');
  if (!rec || typeof rec !== 'object') return { months: {}, pending: [] };
  rec.months = rec.months || {};
  rec.pending = Array.isArray(rec.pending) ? rec.pending : [];
  return rec;
}

async function saveRec(env, id, rec) {
  rec.updatedAt = new Date().toISOString();
  await env.REPORTS.put(recKey(id), JSON.stringify(rec));
}

/**
 * Bot faqat egasiga javob beradi. OWNER_ID env o'zgaruvchisi bo'lsa - shu,
 * bo'lmasa birinchi /start yozgan odam KV'da ega sifatida qayd etiladi.
 */
async function resolveOwner(env, fromId) {
  if (env.OWNER_ID) return String(env.OWNER_ID) === String(fromId);
  const owner = await env.REPORTS.get('owner');
  if (!owner) {
    await env.REPORTS.put('owner', String(fromId));
    return true;
  }
  return owner === String(fromId);
}

// ============ Telegram API ============

function tgApi(token, method, body) {
  return fetch('https://api.telegram.org/bot' + token + '/' + method, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  }).then((r) => r.json()).catch((e) => ({ ok: false, description: String(e && e.message || e) }));
}

/** 429 kelganda retry_after'ni hurmat qilib bir marta qayta uriniladi. */
async function tgSend(token, method, body) {
  let res = await tgApi(token, method, body);
  if (!res.ok && res.error_code === 429) {
    const wait = Math.min((res.parameters && res.parameters.retry_after) || 1, 10);
    await new Promise((r) => setTimeout(r, wait * 1000));
    res = await tgApi(token, method, body);
  }
  return res;
}

async function sendMessage(token, chatId, text, extra) {
  const body = Object.assign({ chat_id: chatId, text, parse_mode: 'HTML' }, extra || {});
  let res = await tgSend(token, 'sendMessage', body);
  // Tugma qabul qilinmasa (masalan web_app guruhda ishlamaydi) - oddiy matn sifatida
  if (!res.ok && body.reply_markup) {
    delete body.reply_markup;
    res = await tgSend(token, 'sendMessage', body);
  }
  return res;
}

const miniAppKb = (url) => url
  ? { inline_keyboard: [[{ text: '📊 Ilovada ochish', web_app: { url } }]] }
  : undefined;

// ============ Hisobot matni ============

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

// ============ Matn tahlili: "ovqat 25k" -> tranzaksiya ============

/** Apostrof variantlarini olib tashlab, solishtirish uchun kalitga aylantiradi. */
const norm = (s) => String(s || '').toLowerCase().replace(/[ʼʻ'’`´]/g, '').trim();

/**
 * Kalit so'z -> [kategoriya, tur]. Bu jadval `docs/index.html` dagi KW bilan
 * bir xil bo'lishi kerak - bot va ilova matnni aynan bir xil tushunadi.
 * Uzunroq kalitlar oldinda turadi ("taksidan" -> daromad, "taksi" -> xarajat).
 */
const KW = {
  taksidan: ['Taksi', 'income'], taxidan: ['Taksi', 'income'], yandexdan: ['Taksi', 'income'],
  yandextaxi: ['Taksi', 'income'], yolhaqi: ['Taksi', 'income'],
  taksi: ['Transport', 'expense'], taxi: ['Transport', 'expense'], yandex: ['Transport', 'expense'],
  transport: ['Transport', 'expense'], avtobus: ['Transport', 'expense'], metro: ['Transport', 'expense'],
  ovqat: ['Ovqat', 'expense'], food: ['Ovqat', 'expense'], restoran: ['Ovqat', 'expense'],
  restaurant: ['Ovqat', 'expense'], kafe: ['Ovqat', 'expense'], lavash: ['Ovqat', 'expense'],
  osh: ['Ovqat', 'expense'], shashlik: ['Ovqat', 'expense'], tushlik: ['Ovqat', 'expense'],
  kechki: ['Ovqat', 'expense'], nonushta: ['Ovqat', 'expense'], bozorlik: ['Ovqat', 'expense'],
  suv: ['Ichimliklar', 'expense'], ichimlik: ['Ichimliklar', 'expense'],
  ichimliklar: ['Ichimliklar', 'expense'], water: ['Ichimliklar', 'expense'],
  kofe: ['Ichimliklar', 'expense'], coffee: ['Ichimliklar', 'expense'], choy: ['Ichimliklar', 'expense'],
  uydagilar: ['Uydagilar', 'expense'], oila: ['Uydagilar', 'expense'], oilaga: ['Uydagilar', 'expense'],
  uyga: ['Uydagilar', 'expense'], uy: ['Uydagilar', 'expense'], ota: ['Uydagilar', 'expense'],
  ona: ['Uydagilar', 'expense'], onam: ['Uydagilar', 'expense'], otam: ['Uydagilar', 'expense'],
  akam: ['Uydagilar', 'expense'], ukam: ['Uydagilar', 'expense'], singlim: ['Uydagilar', 'expense'],
  opam: ['Uydagilar', 'expense'], bolalar: ['Uydagilar', 'expense'], farzand: ['Uydagilar', 'expense'],
  kommunal: ['Uydagilar', 'expense'], svet: ['Uydagilar', 'expense'], gaz: ['Uydagilar', 'expense'],
  qarz: ['Qarz', 'expense'], debt: ['Qarz', 'expense'], kredit: ['Kredit', 'expense'],
  credit: ['Kredit', 'expense'], loan: ['Kredit', 'expense'],
  benzin: ['Yoqilgʼi', 'expense'], zapravka: ['Yoqilgʼi', 'expense'], metan: ['Yoqilgʼi', 'expense'],
  propan: ['Yoqilgʼi', 'expense'], gazoyoq: ['Yoqilgʼi', 'expense'],
  xarid: ['Xarid', 'expense'], bozor: ['Xarid', 'expense'], kiyim: ['Xarid', 'expense'],
  poyabzal: ['Xarid', 'expense'], texnika: ['Xarid', 'expense'], telefon: ['Xarid', 'expense'],
  kompyuter: ['Xarid', 'expense'],
  dori: ['Dorixona', 'expense'], apteka: ['Dorixona', 'expense'], dorixona: ['Dorixona', 'expense'],
  doktor: ['Salomatlik', 'expense'], shifoxona: ['Salomatlik', 'expense'],
  davolanish: ['Salomatlik', 'expense'],
  jarima: ['Jarimalar', 'expense'], jarimalar: ['Jarimalar', 'expense'], fine: ['Jarimalar', 'expense'],
  penalty: ['Jarimalar', 'expense'], gai: ['Jarimalar', 'expense'], radar: ['Jarimalar', 'expense'],
  internet: ['Internet', 'expense'], wifi: ['Internet', 'expense'], aloqa: ['Aloqa', 'expense'],
  paynet: ['Aloqa', 'expense'], simkarta: ['Aloqa', 'expense'], beeline: ['Aloqa', 'expense'],
  ucell: ['Aloqa', 'expense'], mobiuz: ['Aloqa', 'expense'], uzmobile: ['Aloqa', 'expense'],
  kino: ['Koʼngilochar', 'expense'], oyin: ['Koʼngilochar', 'expense'], teatr: ['Koʼngilochar', 'expense'],
  maosh: ['Maosh', 'income'], salary: ['Maosh', 'income'], oylik: ['Maosh', 'income'],
  bonus: ['Bonus', 'income'], mukofot: ['Bonus', 'income'],
  frilans: ['Taksi', 'income'], zakaz: ['Taksi', 'income'], klient: ['Taksi', 'income'],
  mijoz: ['Taksi', 'income'], sovga: ['Sovgʼa', 'income'],
};

/**
 * Standart kategoriyalar - ilova hali bir marta ham sinxronlanmagan bo'lsa ishlatiladi.
 * `docs/index.html` dagi DEF_CATS va ensure() qo'shadigan kategoriyalar bilan bir xil.
 */
const FALLBACK_CATS = [
  { n: 'Maosh', e: '💰', t: 'income' }, { n: 'Bonus', e: '🎁', t: 'income' },
  { n: 'Taksi', e: '🚕', t: 'income' }, { n: 'Investitsiya', e: '📈', t: 'income' },
  { n: 'Sovgʼa', e: '🎀', t: 'income' }, { n: 'Qarz', e: '🤝', t: 'income' },
  { n: 'Boshqa', e: '➕', t: 'income' },
  { n: 'Ovqat', e: '🍔', t: 'expense' }, { n: 'Ichimliklar', e: '🥤', t: 'expense' },
  { n: 'Uydagilar', e: '👨‍👩‍👧‍👦', t: 'expense' }, { n: 'Qarz', e: '🤝', t: 'expense' },
  { n: 'Kredit', e: '💳', t: 'expense' }, { n: 'Transport', e: '🚌', t: 'expense' },
  { n: 'Yoqilgʼi', e: '⛽', t: 'expense' }, { n: 'Xarid', e: '🛍️', t: 'expense' },
  { n: 'Koʼngilochar', e: '🎮', t: 'expense' }, { n: 'Salomatlik', e: '❤️', t: 'expense' },
  { n: 'Dorixona', e: '💊', t: 'expense' }, { n: 'Jarimalar', e: '👮', t: 'expense' },
  { n: 'Internet', e: '🌐', t: 'expense' }, { n: 'Aloqa', e: '📶', t: 'expense' },
  { n: 'Boshqa', e: '📦', t: 'expense' },
];

/** Standart hisoblar - ilova hali sinxronlanmagan bo'lsa (DEF bilan bir xil id'lar). */
const FALLBACK_ACCOUNTS = [
  { id: 'cash', name: 'Naqd', e: '💵', opening: 0 },
  { id: 'card', name: 'Bank karta', e: '💳', opening: 0 },
];

/** "25k", "1.5mln", "+500ming", "25000" -> {value, sign} yoki null */
function parseAmount(tok) {
  const m = /^([+-]?)(\d+(?:[.,]\d+)?)(k|ming|mln|mln\.|m|million)?$/i.exec(tok);
  if (!m) return null;
  let v = parseFloat(m[2].replace(',', '.'));
  if (!isFinite(v) || v <= 0) return null;
  const suf = (m[3] || '').toLowerCase();
  if (suf === 'k' || suf === 'ming') v *= 1000;
  else if (suf === 'm' || suf === 'mln' || suf === 'mln.' || suf === 'million') v *= 1e6;
  return { value: Math.round(v), sign: m[1] };
}

/** O'zbek tilidagi keng tarqalgan kelishik/egalik qo'shimchalari. */
const SUFFIXES = [
  'larimizga', 'laringizga', 'larning', 'lardan', 'larimiz', 'laringiz',
  'larga', 'larda', 'larni', 'lari', 'lar',
  'imizga', 'ingizga', 'imizda', 'ingizda', 'imiz', 'ingiz',
  'sidan', 'siga', 'sida', 'sini', 'ning',
  'imdan', 'imga', 'imni', 'idan', 'iga', 'ida', 'ini',
  'mdan', 'mga', 'mni',
  'dan', 'ga', 'ka', 'qa', 'da', 'ni', 'im', 'si', 'm', 'i',
];

/**
 * So'zning bo'lishi mumkin bo'lgan asoslari: avval o'zi, keyin qo'shimcha
 * ajratilganlari (eng kam kesilgani oldinda). "onamga" -> ["onamga","onam","ona"]
 */
function stems(w) {
  const out = [w];
  for (const s of SUFFIXES) {
    if (w.length - s.length >= 2 && w.endsWith(s)) out.push(w.slice(0, -s.length));
  }
  // O'zini birinchi qoldirib, qolganini uzunligi bo'yicha kamayish tartibida
  return [w].concat(out.slice(1).sort((a, b) => b.length - a.length));
}

/**
 * So'zlar orasidan kategoriyani topadi.
 * Avval KW kalit so'zlari (tur bilan birga), so'ng foydalanuvchining
 * haqiqiy kategoriya nomlari tekshiriladi. Har bir so'z qo'shimchasiz ham sinaladi.
 * @returns {{cat:string, type:string|null, wordIndex:number}|null}
 */
function matchCat(words, cats) {
  for (let i = 0; i < words.length; i++) {
    const w = norm(words[i]);
    if (!w) continue;
    for (const s of stems(w)) {
      if (KW[s]) return { cat: KW[s][0], type: KW[s][1], wordIndex: i };
    }
  }
  // KW'da yo'q bo'lsa - foydalanuvchi o'zi qo'shgan kategoriya nomlari
  for (let i = 0; i < words.length; i++) {
    const w = norm(words[i]);
    if (!w) continue;
    for (const s of stems(w)) {
      let hit = cats.find((c) => c && c.n && norm(c.n) === s);
      if (!hit && s.length >= 4) hit = cats.find((c) => c && c.n && norm(c.n).startsWith(s));
      if (hit) return { cat: hit.n, type: hit.t || 'expense', wordIndex: i };
    }
  }
  return null;
}

/** Matndagi so'zlardan hisobni aniqlaydi (yo'q bo'lsa birinchi hisob). */
function matchAccount(words, accounts) {
  const list = (accounts && accounts.length) ? accounts : FALLBACK_ACCOUNTS;
  for (let i = 0; i < words.length; i++) {
    const w = norm(words[i]);
    if (!w || w.length < 3) continue;
    const hit = list.find((a) => a && a.name && (norm(a.name) === w || norm(a.name).startsWith(w)));
    if (hit) return { acc: hit, wordIndex: i };
    if (w === 'karta' || w === 'card' || w === 'plastik') {
      const card = list.find((a) => norm(a.name).includes('karta') || norm(a.name).includes('card'));
      if (card) return { acc: card, wordIndex: i };
    }
  }
  return { acc: list[0], wordIndex: -1 };
}

/**
 * Erkin matnni tranzaksiyaga aylantiradi.
 * Qabul qiladi: "ovqat 25k", "25k ovqat", "+500ming maosh", "25 ming taksi Chilonzorgacha"
 * @returns {{tx:Object}|{error:string}}
 */
function parseEntry(text, st) {
  // "25 ming" kabi ajralgan ko'rsatkichni bitta tokenga birlashtiramiz
  const clean = String(text || '').replace(/(\d)\s+(ming|mln|million|k|m)\b/gi, '$1$2').trim();
  if (!clean) return { error: 'Matn boʻsh' };

  const words = clean.split(/\s+/);

  let amount = null, sign = '', amtIndex = -1;
  for (let i = 0; i < words.length; i++) {
    const p = parseAmount(words[i]);
    if (p) { amount = p.value; sign = p.sign; amtIndex = i; break; }
  }
  if (amount === null) {
    return { error: 'Summa topilmadi. Masalan: <code>ovqat 25k</code>' };
  }

  const cats = (st && Array.isArray(st.cats) && st.cats.length) ? st.cats : FALLBACK_CATS;
  const rest = words.filter((_, i) => i !== amtIndex);

  const found = matchCat(rest, cats);
  // Tur: `+`/`-` belgisi hamma narsadan ustun, keyin kalit so'z, aks holda xarajat
  let type = 'expense';
  if (sign === '+') type = 'income';
  else if (sign === '-') type = 'expense';
  else if (found && found.type) type = found.type;

  // Kategoriya shu turda mavjudmi - yo'q bo'lsa "Boshqa"ga tushadi
  let catName = found ? found.cat : 'Boshqa';
  if (found && !cats.some((c) => c && norm(c.n) === norm(catName) && (c.t || 'expense') === type)) {
    catName = 'Boshqa';
  }

  const used = new Set();
  if (found) used.add(found.wordIndex);
  const accPick = matchAccount(rest, st && st.accounts);
  if (accPick.wordIndex >= 0) used.add(accPick.wordIndex);

  const note = rest.filter((_, i) => !used.has(i)).join(' ').trim();

  return {
    tx: {
      id: genId(),
      type,
      amount,
      cat: catName,
      accountId: accPick.acc.id,
      toAccountId: null,
      merchant: note || catName,
      note,
      fav: false,
      date: new Date().toISOString(),
      src: 'bot',
    },
    fallback: !found,
  };
}

// ============ Hisob-kitob (KV'dagi state + pending ustida) ============

/** state.tx va hali o'zlashtirilmagan pending'ni birga qaytaradi. */
function allTx(rec) {
  const st = rec.state || {};
  const deleted = new Set(st.deletedIds || []);
  const base = (st.tx || []).filter((t) => t && t.id && !deleted.has(t.id));
  const seen = new Set(base.map((t) => t.id));
  const extra = (rec.pending || []).filter((t) => t && t.id && !seen.has(t.id) && !deleted.has(t.id));
  return base.concat(extra);
}

function accountBalance(rec, accId) {
  const acc = ((rec.state && rec.state.accounts) || []).find((a) => a && a.id === accId);
  let b = (acc && acc.opening) || 0;
  for (const t of allTx(rec)) {
    if (t.accountId === accId) {
      if (t.type === 'income') b += (t.amount || 0);
      else b -= (t.amount || 0);
    }
    if (t.type === 'transfer' && t.toAccountId === accId) b += (t.amount || 0);
  }
  return b;
}

function accountsOf(rec) {
  const list = (rec.state && rec.state.accounts) || [];
  return list.length ? list : FALLBACK_ACCOUNTS;
}

const totalBalance = (rec) => accountsOf(rec).reduce((s, a) => s + accountBalance(rec, a.id), 0);

/** Berilgan oy uchun jamlanma - state va pending ustidan qayta hisoblanadi. */
function monthSummary(rec, mk) {
  let income = 0, expense = 0;
  const byInc = {}, byExp = {};
  let count = 0;
  for (const t of allTx(rec)) {
    const d = toTash(t.date || 0);
    if (!d || monthKeyOf(d) !== mk) continue;
    count++;
    const a = parseFloat(t.amount) || 0;
    const c = t.cat || 'Boshqa';
    if (t.type === 'income') { income += a; byInc[c] = (byInc[c] || 0) + a; }
    else if (t.type === 'expense') { expense += a; byExp[c] = (byExp[c] || 0) + a; }
  }
  const srt = (o) => Object.entries(o).sort((a, b) => b[1] - a[1]);
  return { income, expense, cats: srt(byExp), incCats: srt(byInc), txCount: count };
}

// ============ Ertalabki xabar (kunning rejasi) ============

/** Byudjet davri boshidan beri sarflangan summa (ilovadagi budgetSpent bilan bir xil). */
function budgetSpent(rec, b, d) {
  const st = periodStartTash(b.period, d).getTime();
  const set = new Set(b.catIds || []);
  return allTx(rec)
    .filter((t) => t.type === 'expense' && new Date(t.date).getTime() >= st
      && (set.size === 0 || set.has(t.cat)))
    .reduce((s, t) => s + (t.amount || 0), 0);
}

/** Berilgan vaqt oralig'idagi xarajat yig'indisi. */
const spentSince = (rec, from) => allTx(rec)
  .filter((t) => t.type === 'expense' && new Date(t.date).getTime() >= from)
  .reduce((s, t) => s + (t.amount || 0), 0);

/**
 * Kunning rejasi: qoldiq, oy holati, bugun sarflash mumkin bo'lgan summa,
 * yaqinlashgan takrorlanuvchi to'lovlar va qarz muddatlari.
 * @param d Toshkent vaqtidagi "hozir" (test uchun beriladi)
 * @returns {string|null} xabar matni, yuborishga arzimasa null
 */
function buildMorning(rec, cur, d) {
  d = d || nowTashkent();
  cur = cur || 'soʻm';
  const st = rec.state;
  if (!st) return null;

  const { day, total, left } = monthDays(d);
  const lines = [
    '☀️ <b>' + day + '-' + MONTHS[d.getUTCMonth() + 1].toLowerCase() + '</b>, ' + WEEKDAYS[d.getUTCDay()],
    '',
    '💵 Qoldiq: <b>' + fmtNum(totalBalance(rec)) + ' ' + cur + '</b>',
  ];

  // --- Oy holati ---
  const monthSpent = spentSince(rec, monthStartTash(d).getTime());
  lines.push('📉 Oyda sarflandi: <b>' + fmtNum(monthSpent) + ' ' + cur + '</b>'
    + ' <i>(' + day + '/' + total + ' kun)</i>');

  // --- Bugun sarflash mumkin bo'lgan summa ---
  // Oylik byudjetlar bo'lsa shundan, aks holda o'rtacha sarfdan prognoz.
  // Hamma kategoriyani qamrab oluvchi byudjet (catIds bo'sh) bo'lsa faqat shuni
  // olamiz - aks holda u kategoriya byudjetlari bilan ikki marta hisoblanadi.
  const monthly = (st.budgets || []).filter((b) => b && b.period === 'monthly' && b.limit > 0);
  const overall = monthly.filter((b) => !(b.catIds || []).length)
    .sort((a, b) => b.limit - a.limit)[0];
  const pool = overall ? [overall] : monthly;
  if (pool.length) {
    const limit = pool.reduce((s, b) => s + b.limit, 0);
    const spent = pool.reduce((s, b) => s + budgetSpent(rec, b, d), 0);
    const rem = limit - spent;
    const pct = Math.round((spent / limit) * 100);
    lines.push('📊 Byudjetdan <b>' + pct + '%</b> sarflandi');
    if (rem > 0) {
      // Minggacha pastga yumaloqlaymiz - "~83 333" o'rniga "~83 000"
      const perDay = Math.floor(rem / left / 1000) * 1000;
      lines.push('✅ Bugun sarflash mumkin: <b>~' + fmtNum(perDay) + ' ' + cur + '</b>'
        + ' <i>(' + left + ' kunga ' + fmtNum(rem) + ')</i>');
    } else {
      lines.push('🔴 Byudjet tugadi — <b>' + fmtNum(-rem) + ' ' + cur + '</b> oshib ketdi');
    }
  } else if (day > 1) {
    const perDay = monthSpent / (day - 1 || 1);
    lines.push('📈 Kunlik oʻrtacha: <b>' + fmtNum(perDay) + ' ' + cur + '</b>'
      + ' · oy oxiriga prognoz <b>' + fmtNum(perDay * total) + ' ' + cur + '</b>');
  }

  // --- Alohida byudjetlar: faqat 80% dan oshganlari ---
  const hot = (st.budgets || [])
    .filter((b) => b && b.limit > 0)
    .map((b) => ({ b, sp: budgetSpent(rec, b, d) }))
    .filter(({ b, sp }) => sp / b.limit >= 0.8)
    .sort((x, y) => (y.sp / y.b.limit) - (x.sp / x.b.limit));
  if (hot.length) {
    lines.push('');
    for (const { b, sp } of hot) {
      const pct = Math.round((sp / b.limit) * 100);
      lines.push((sp > b.limit ? '🔴' : '🟡') + ' ' + esc(b.name) + ' — <b>' + pct + '%</b>'
        + (sp > b.limit
          ? ' (' + fmtNum(sp - b.limit) + ' oshdi)'
          : ' (' + fmtNum(b.limit - sp) + ' qoldi)'));
    }
  }

  // --- Takrorlanuvchi to'lovlar: bugun va ertaga ---
  const due = (st.recurring || [])
    .filter((r) => r && r.active !== false && r.nextDue)
    .map((r) => ({ r, days: daysFromToday(r.nextDue, d) }))
    .filter(({ days }) => days !== null && days <= 1)
    .sort((x, y) => x.days - y.days);
  if (due.length) {
    lines.push('');
    for (const { r, days } of due) {
      const when = days < 0 ? '⏰ Kechikdi' : days === 0 ? '⚠️ Bugun' : '📅 Ertaga';
      const sign = r.type === 'income' ? '+' : '−';
      lines.push(when + ': ' + esc(r.title || r.cat || 'Toʻlov')
        + ' — <b>' + sign + fmtNum(r.amount) + ' ' + cur + '</b>');
    }
  }

  // --- Qarz muddatlari: kechikkan yoki 3 kun ichida ---
  const debts = (st.debts || [])
    .filter((x) => x && (x.status || 'active') !== 'settled' && x.dueDate)
    .map((x) => ({ x, days: daysFromToday(x.dueDate, d) }))
    .filter(({ days }) => days !== null && days <= 3)
    .sort((a, b) => a.days - b.days);
  if (debts.length) {
    lines.push('');
    for (const { x, days } of debts) {
      const rem = (x.amount || 0) - (x.paid || 0);
      const who = x.type === 'borrow' ? 'Qarzim' : 'Qarzga berdim';
      const when = days < 0 ? (-days) + ' kun kechikdi' : days === 0 ? 'bugun' : days + ' kundan keyin';
      lines.push('🤝 ' + esc(x.person || who) + ' — <b>' + fmtNum(rem) + ' ' + cur + '</b> · ' + when);
    }
  }

  return lines.join('\n');
}

/**
 * Xaridlar rejasidagi buyumlar uchun eslatma: belgilangan sanaga bir kun qolganda.
 * `days` berilsa shu kunlik farqdagi buyumlar olinadi (standart: 1 = ertaga).
 * Hech narsa topilmasa null qaytaradi - xabar yuborilmaydi.
 */
function buildPlanReminder(rec, cur, d, days = 1) {
  d = d || nowTashkent();
  cur = cur || 'soʻm';
  const st = rec.state;
  if (!st) return null;

  const items = (st.wishlist || [])
    .filter((w) => w && w.status !== 'bought' && w.dueDate)
    .filter((w) => daysFromToday(w.dueDate, d) === days)
    .sort((a, b) => (Number(b.price) || 0) - (Number(a.price) || 0));
  if (!items.length) return null;

  const when = days === 0 ? 'Bugun' : days === 1 ? 'Ertaga' : days + ' kundan keyin';
  const lines = ['🛍️ <b>' + when + ' rejadagi xarid</b>', ''];
  let total = 0;
  for (const w of items) {
    const price = Number(w.price) || 0;
    total += price;
    lines.push('• <b>' + esc(w.title || 'Buyum') + '</b> — ' + fmtNum(price) + ' ' + cur
      + (w.cat ? ' <i>(' + esc(w.cat) + ')</i>' : ''));
    if (w.note) lines.push('   📝 ' + esc(w.note));
  }
  if (items.length > 1) lines.push('', '🧾 Jami: <b>' + fmtNum(total) + ' ' + cur + '</b>');

  const balance = totalBalance(rec);
  lines.push('', '💵 Qoldiq: <b>' + fmtNum(balance) + ' ' + cur + '</b>');
  if (total > balance) {
    lines.push('⚠️ Qoldiq yetmaydi — <b>' + fmtNum(total - balance) + ' ' + cur + '</b> kam.');
  }
  return lines.join('\n');
}

// ============ Bot buyruqlari ============

const HELP = [
  '👋 <b>FinanceApp boti</b>',
  '',
  'Xarajatni shunchaki yozib yuboring:',
  '• <code>ovqat 25k</code>',
  '• <code>25 ming taksi</code>',
  '• <code>benzin 120k karta</code>',
  '• <code>+5mln maosh</code> — daromad',
  '',
  '<b>Summa:</b> <code>25000</code> · <code>25k</code> · <code>25 ming</code> · <code>1.5mln</code>',
  '<b>Daromad</b> uchun oldiga <code>+</code> qo‘ying.',
  'Kategoriya yozilmasa — <i>Boshqa</i> bo‘ladi, keyin tugma bilan o‘zgartirasiz.',
  '',
  '<b>Buyruqlar</b>',
  '/bugun — kunning rejasi',
  '/balans — hisoblar bo‘yicha qoldiq',
  '/oy — shu oy jamlanmasi',
  '/hisobot — oylik hisobotni yuborish',
  '/bekor — oxirgi kiritilganni o‘chirish',
  '/ertalab — ertalabki xabarni yoqish/o‘chirish',
  '/eslatma — reja sanasi eslatmasini yoqish/o‘chirish',
  '/help — shu yordam',
].join('\n');

const NO_STATE = 'Maʼlumot yoʻq — Mini App’ni bir marta ochib sinxronlashtiring.';

/** Saqlangandan keyingi tasdiq xabari. */
function entryText(tx, rec, cur) {
  const acc = accountsOf(rec).find((a) => a.id === tx.accountId);
  const sign = tx.type === 'income' ? '+' : '−';
  const icon = tx.type === 'income' ? '💰' : '💸';
  const lines = [
    icon + ' <b>' + esc(tx.cat) + '</b>  ' + sign + fmtNum(tx.amount) + ' ' + cur,
  ];
  if (tx.note) lines.push('📝 ' + esc(tx.note));
  lines.push('🏦 ' + esc((acc && ((acc.e ? acc.e + ' ' : '') + acc.name)) || tx.accountId));
  lines.push('', '💵 Qoldiq: <b>' + fmtNum(totalBalance(rec)) + ' ' + cur + '</b>');
  return lines.join('\n');
}

const entryKb = (txId) => ({
  inline_keyboard: [[
    { text: '✏️ Kategoriya', callback_data: 'k:' + txId },
    { text: '❌ Bekor', callback_data: 'd:' + txId },
  ]],
});

/** Kategoriya tanlash klaviaturasi (3 ta ustun). */
function catKb(rec, tx) {
  const cats = ((rec.state && rec.state.cats) || FALLBACK_CATS)
    .filter((c) => c && c.n && (c.t || 'expense') === tx.type);
  const rows = [];
  for (let i = 0; i < cats.length; i += 3) {
    rows.push(cats.slice(i, i + 3).map((c, j) => ({
      text: (c.e ? c.e + ' ' : '') + c.n,
      callback_data: 'c:' + tx.id + ':' + (i + j),
    })));
  }
  rows.push([{ text: '‹ Orqaga', callback_data: 'b:' + tx.id }]);
  return { inline_keyboard: rows };
}

/** pending ichidan tranzaksiyani topadi. */
const findPending = (rec, id) => (rec.pending || []).find((t) => t && t.id === id);

async function handleMessage(env, msg) {
  const token = env.TELEGRAM_BOT_TOKEN;
  const chatId = msg.chat.id;
  const text = String(msg.text || '').trim();
  const rec = await loadRec(env, chatId);
  const cur = rec.cur || 'soʻm';

  // Chat ID'ni cron va hisobot uchun yozib qo'yamiz
  if (rec.chatId !== chatId) {
    rec.chatId = chatId;
    rec.name = (msg.from && msg.from.first_name) || '';
    await saveRec(env, chatId, rec);
  }

  const cmd = /^\/([a-z_]+)/i.exec(text);
  if (cmd) {
    const name = cmd[1].toLowerCase();

    if (name === 'start' || name === 'help') {
      return sendMessage(token, chatId, HELP, { reply_markup: miniAppKb(env.MINIAPP_URL) });
    }

    if (name === 'bugun') {
      const text = buildMorning(rec, cur);
      return sendMessage(token, chatId, text || NO_STATE,
        { reply_markup: miniAppKb(env.MINIAPP_URL) });
    }

    if (name === 'ertalab') {
      rec.morning = rec.morning === false;
      await saveRec(env, chatId, rec);
      return sendMessage(token, chatId, rec.morning
        ? '☀️ Ertalabki xabar <b>yoqildi</b> — har kuni 08:00 da keladi.\n<i>Hozir koʻrish: /bugun</i>'
        : '🌙 Ertalabki xabar <b>oʻchirildi</b>.\n<i>Qayta yoqish: /ertalab</i>');
    }

    if (name === 'eslatma') {
      rec.plans = rec.plans === false;
      await saveRec(env, chatId, rec);
      return sendMessage(token, chatId, rec.plans
        ? '🛍️ Reja eslatmasi <b>yoqildi</b> — xarid sanasidan 1 kun oldin 09:00 da keladi.'
        : '🔕 Reja eslatmasi <b>oʻchirildi</b>.\n<i>Qayta yoqish: /eslatma</i>');
    }

    if (name === 'balans') {
      if (!rec.state) {
        return sendMessage(token, chatId, NO_STATE,
          { reply_markup: miniAppKb(env.MINIAPP_URL) });
      }
      const lines = ['💵 <b>Hisoblar</b>', ''];
      for (const a of accountsOf(rec)) {
        lines.push((a.e ? a.e + ' ' : '') + esc(a.name) + ': <b>' + fmtNum(accountBalance(rec, a.id)) + ' ' + cur + '</b>');
      }
      lines.push('', '<b>Jami: ' + fmtNum(totalBalance(rec)) + ' ' + cur + '</b>');
      return sendMessage(token, chatId, lines.join('\n'), { reply_markup: miniAppKb(env.MINIAPP_URL) });
    }

    if (name === 'oy' || name === 'hisobot') {
      const mk = monthKeyOf(nowTashkent());
      const sum = monthSummary(rec, mk);
      if (!sum.txCount) {
        return sendMessage(token, chatId, monthTitle(mk) + ' oyida tranzaksiya yoʻq.');
      }
      return sendMessage(token, chatId, buildReport(mk, sum, cur),
        { reply_markup: miniAppKb(env.MINIAPP_URL) });
    }

    if (name === 'bekor') {
      const last = (rec.pending || []).pop();
      if (!last) {
        return sendMessage(token, chatId,
          'Bekor qilinadigan yangi yozuv yoʻq.\n<i>Ilovaga oʻtgan yozuvlar faqat ilovada oʻchiriladi.</i>');
      }
      await saveRec(env, chatId, rec);
      return sendMessage(token, chatId,
        '🗑 Oʻchirildi: ' + esc(last.cat) + ' — ' + fmtNum(last.amount) + ' ' + cur);
    }

    return sendMessage(token, chatId, 'Bunday buyruq yoʻq. /help');
  }

  // Oddiy matn -> tranzaksiya
  const parsed = parseEntry(text, rec.state);
  if (parsed.error) {
    return sendMessage(token, chatId, '⚠️ ' + parsed.error + '\n\n/help — namunalar');
  }

  rec.pending.push(parsed.tx);
  // pending cheksiz o'smasligi uchun (ilova uzoq ochilmasa) oxirgi 200 ta yetarli
  if (rec.pending.length > 200) rec.pending = rec.pending.slice(-200);
  await saveRec(env, chatId, rec);

  // Kategoriya aniqlanmagan bo'lsa - darhol tanlash klaviaturasini ko'rsatamiz
  const kb = parsed.fallback ? catKb(rec, parsed.tx) : entryKb(parsed.tx.id);
  return sendMessage(token, chatId, entryText(parsed.tx, rec, cur), { reply_markup: kb });
}

async function handleCallback(env, cq) {
  const token = env.TELEGRAM_BOT_TOKEN;
  // Juda eski tugma bosilsa Telegram xabarni bermasligi mumkin
  if (!cq.message || !cq.message.chat) {
    return tgSend(token, 'answerCallbackQuery',
      { callback_query_id: cq.id, text: 'Xabar juda eski' });
  }
  const chatId = cq.message.chat.id;
  const msgId = cq.message.message_id;
  const data = String(cq.data || '');
  const rec = await loadRec(env, chatId);
  const cur = rec.cur || 'soʻm';

  const ack = (text) => tgSend(token, 'answerCallbackQuery',
    Object.assign({ callback_query_id: cq.id }, text ? { text } : {}));

  const [op, txId, arg] = data.split(':');
  const tx = findPending(rec, txId);

  if (!tx) {
    await ack('Yozuv ilovaga oʻtib ketgan');
    await tgSend(token, 'editMessageReplyMarkup', { chat_id: chatId, message_id: msgId });
    return;
  }

  if (op === 'd') {
    rec.pending = rec.pending.filter((t) => t.id !== txId);
    await saveRec(env, chatId, rec);
    await ack('Bekor qilindi');
    return tgSend(token, 'editMessageText', {
      chat_id: chatId, message_id: msgId, parse_mode: 'HTML',
      text: '🗑 <s>' + esc(tx.cat) + ' — ' + fmtNum(tx.amount) + ' ' + cur + '</s>\n<i>Bekor qilindi</i>',
    });
  }

  if (op === 'k') {
    await ack();
    return tgSend(token, 'editMessageReplyMarkup', {
      chat_id: chatId, message_id: msgId, reply_markup: catKb(rec, tx),
    });
  }

  if (op === 'b') {
    await ack();
    return tgSend(token, 'editMessageReplyMarkup', {
      chat_id: chatId, message_id: msgId, reply_markup: entryKb(txId),
    });
  }

  if (op === 'c') {
    const cats = ((rec.state && rec.state.cats) || FALLBACK_CATS)
      .filter((c) => c && c.n && (c.t || 'expense') === tx.type);
    const pick = cats[parseInt(arg, 10)];
    if (!pick) { await ack('Kategoriya topilmadi'); return; }
    tx.cat = pick.n;
    if (!tx.note) tx.merchant = pick.n;
    await saveRec(env, chatId, rec);
    await ack(pick.n);
    return tgSend(token, 'editMessageText', {
      chat_id: chatId, message_id: msgId, parse_mode: 'HTML',
      text: entryText(tx, rec, cur), reply_markup: entryKb(txId),
    });
  }

  await ack();
}

// ============ HTTP ============

const json = (obj, status) => new Response(JSON.stringify(obj), {
  status: status || 200,
  headers: {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
  },
});

/** Telegram menyusida ko'rinadigan buyruqlar. */
const BOT_COMMANDS = [
  { command: 'bugun', description: 'Kunning rejasi' },
  { command: 'balans', description: 'Hisoblar boʻyicha qoldiq' },
  { command: 'oy', description: 'Shu oy jamlanmasi' },
  { command: 'hisobot', description: 'Oylik hisobotni yuborish' },
  { command: 'bekor', description: 'Oxirgi kiritilganni oʻchirish' },
  { command: 'ertalab', description: 'Ertalabki xabarni yoqish/oʻchirish' },
  { command: 'eslatma', description: 'Reja sanasi eslatmasini yoqish/oʻchirish' },
  { command: 'help', description: 'Yordam va namunalar' },
];

/** Webhook, buyruqlar ro'yxati va menu tugmasini ro'yxatdan o'tkazadi. */
async function setup(env, origin) {
  const token = env.TELEGRAM_BOT_TOKEN;
  const hook = await tgApi(token, 'setWebhook', {
    url: origin + '/webhook',
    secret_token: env.WEBHOOK_SECRET,
    allowed_updates: ['message', 'callback_query'],
    drop_pending_updates: true,
  });
  const cmds = await tgApi(token, 'setMyCommands', { commands: BOT_COMMANDS });
  const menu = env.MINIAPP_URL
    ? await tgApi(token, 'setChatMenuButton', {
      menu_button: { type: 'web_app', text: 'Ilova', web_app: { url: env.MINIAPP_URL } },
    })
    : { ok: true, skipped: 'MINIAPP_URL yoʻq' };

  return { webhook: hook, commands: cmds, menu };
}

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    if (request.method === 'OPTIONS') return json({ ok: true });
    if (url.pathname === '/' && request.method === 'GET') {
      // `features` deploy qilingan kod nimani biladi - shuni ko'rsatadi.
      // `curl <worker>/` eski versiya deploy'da turganini darhol bildiradi.
      return json({
        ok: true,
        service: 'finance-report-worker',
        features: FEATURES,
        // Faqat shakl tekshiriladi - token qiymati hech qachon qaytarilmaydi
        token: env.TELEGRAM_BOT_TOKEN === undefined ? 'yoʻq (secret ulanmagan)'
          : !String(env.TELEGRAM_BOT_TOKEN).trim() ? 'boʻsh (secret bor, qiymati yoʻq)'
          : /^\d+:[\w-]{30,}$/.test(String(env.TELEGRAM_BOT_TOKEN).trim()) ? 'ok'
          : 'notoʻgʻri shakl (' + String(env.TELEGRAM_BOT_TOKEN).trim().length + ' belgi)',
        bot: !!env.WEBHOOK_SECRET,
        owner: env.OWNER_ID ? 'env' : 'kv',
        commands: BOT_COMMANDS.map((c) => c.command),
      });
    }

    // ---- Bir martalik sozlash: /setup?secret=<WEBHOOK_SECRET> ----
    // Diqqat: avval chaqiruvchi tasdiqlanadi, keyingina sozlama holati aytiladi -
    // aks holda begona odam ham qanday sozlanmaganini bilib oladi.
    if (url.pathname === '/setup') {
      if (!env.WEBHOOK_SECRET) return json({ ok: false, error: 'WEBHOOK_SECRET sozlanmagan' }, 500);
      if (!safeEqual(url.searchParams.get('secret') || '', env.WEBHOOK_SECRET)) {
        return json({ ok: false, error: 'secret notoʻgʻri' }, 403);
      }
      if (!env.TELEGRAM_BOT_TOKEN) {
        return json({ ok: false, error: 'TELEGRAM_BOT_TOKEN sozlanmagan yoki boʻsh' }, 500);
      }
      return json({ ok: true, result: await setup(env, url.origin) });
    }

    // ---- Telegram webhook ----
    if (url.pathname === '/webhook') {
      if (request.method !== 'POST') return json({ ok: false, error: 'POST kutilgan' }, 405);
      if (!env.WEBHOOK_SECRET) return new Response('forbidden', { status: 403 });
      if (!safeEqual(request.headers.get('X-Telegram-Bot-Api-Secret-Token') || '', env.WEBHOOK_SECRET)) {
        return new Response('forbidden', { status: 403 });
      }
      // Token yo'q bo'lsa javob yozib bo'lmaydi. 200 qaytaramiz - aks holda Telegram
      // bu update'ni soatlab qayta-qayta yuborib turadi.
      if (!env.TELEGRAM_BOT_TOKEN) {
        console.error('webhook: TELEGRAM_BOT_TOKEN sozlanmagan yoki boʻsh');
        return json({ ok: true });
      }

      let update;
      try { update = await request.json(); } catch { return json({ ok: true }); }

      const from = (update.message && update.message.from)
        || (update.callback_query && update.callback_query.from);
      if (!from || !from.id) return json({ ok: true });

      if (!(await resolveOwner(env, from.id))) {
        if (update.message) {
          ctx.waitUntil(sendMessage(env.TELEGRAM_BOT_TOKEN, update.message.chat.id,
            'Bu shaxsiy bot.'));
        }
        return json({ ok: true });
      }

      // Telegram'ga darhol 200 qaytaramiz, ish fonda bajariladi (qayta yuborishni oldini oladi)
      ctx.waitUntil((async () => {
        try {
          if (update.message && update.message.text) await handleMessage(env, update.message);
          else if (update.callback_query) await handleCallback(env, update.callback_query);
        } catch (e) {
          console.error('webhook error:', e && e.stack || e);
        }
      })());
      return json({ ok: true });
    }

    // ---- Mini App endpointlari (initData imzosi bilan) ----
    if (request.method !== 'POST') return json({ ok: false, error: 'POST kutilgan' }, 405);
    // initData imzosi bot tokeni bilan tekshiriladi - token bo'lmasa hech narsa qilib bo'lmaydi
    if (!env.TELEGRAM_BOT_TOKEN) return json({ ok: false, error: 'TELEGRAM_BOT_TOKEN sozlanmagan' }, 500);

    let body;
    try { body = await request.json(); } catch (e) { return json({ ok: false, error: 'JSON xato' }, 400); }

    const user = await verifyInitData(body.initData, env.TELEGRAM_BOT_TOKEN);
    if (!user || !user.id) return json({ ok: false, error: 'initData tasdiqlanmadi' }, 401);

    if (url.pathname !== '/sync' && url.pathname !== '/report' && url.pathname !== '/pull') {
      return json({ ok: false, error: 'Notoʻgʻri manzil' }, 404);
    }

    const rec = await loadRec(env, user.id);

    if (url.pathname === '/pull') {
      return json({
        ok: true,
        state: rec.state || null,
        months: rec.months || null,
        pending: rec.pending || [],
      });
    }

    // Ilova o'zlashtirgan pending yozuvlarni ro'yxatdan chiqaramiz
    if (Array.isArray(body.ackPending) && body.ackPending.length) {
      const done = new Set(body.ackPending.map(String));
      rec.pending = (rec.pending || []).filter((t) => !done.has(String(t.id)));
    }

    rec.chatId = user.id;
    rec.name = user.first_name || rec.name || '';
    rec.cur = body.cur || rec.cur || 'soʻm';
    rec.months = Object.assign({}, rec.months || {}, body.months || {});
    if (body.state) rec.state = body.state;
    await saveRec(env, user.id, rec);

    if (url.pathname === '/sync') {
      return json({
        ok: true,
        saved: Object.keys(rec.months).length,
        hasState: !!rec.state,
        pending: rec.pending.length,
      });
    }

    const mk = body.month || Object.keys(rec.months).sort().pop();
    if (!mk || !rec.months[mk]) return json({ ok: false, error: 'Bu oy uchun maʼlumot yoʻq' }, 400);

    const res = await sendMessage(env.TELEGRAM_BOT_TOKEN, user.id,
      buildReport(mk, rec.months[mk], rec.cur), { reply_markup: miniAppKb(env.MINIAPP_URL) });
    return json({ ok: !!res.ok, error: res.description || null, month: mk }, res.ok ? 200 : 502);
  },

  /**
   * Cron. Uch jadval bor (wrangler.toml):
   *   0 5 1 * *  -> har oyning 1-sanasi 10:00 Toshkent: o'tgan oy hisoboti
   *   0 3 * * *  -> har kuni 08:00 Toshkent: kunning rejasi
   *   0 4 * * *  -> har kuni 09:00 Toshkent: ertaga rejalashtirilgan xaridlar
   */
  async scheduled(event, env, ctx) {
    // event.cron bo'lmasa (mahalliy `wrangler dev` chaqiruvi) soatiga qarab ajratamiz.
    const hour = new Date(event.scheduledTime).getUTCHours();
    const job = event.cron === MONTHLY_CRON
      || (!event.cron && new Date(event.scheduledTime).getUTCDate() === 1 && hour === 5)
      ? runMonthlyReport
      : (event.cron === PLAN_CRON || (!event.cron && hour === 4))
        ? runPlanReminders
        : runMorningBrief;
    ctx.waitUntil(job(env, event));
  },
};

/** KV'dagi har bir foydalanuvchi yozuvi ustidan yuradi, xatolarni izolyatsiya qiladi. */
async function eachRecord(env, fn) {
  let cursor;
  do {
    const list = await env.REPORTS.list({ prefix: 'u:', cursor });
    for (const k of list.keys) {
      try {
        const rec = await env.REPORTS.get(k.name, 'json');
        if (rec && rec.chatId) await fn(rec);
      } catch (e) {
        console.error('cron', k.name, e && e.stack || e);
      }
    }
    cursor = list.list_complete ? null : list.cursor;
  } while (cursor);
}

/** O'tgan oy hisoboti. */
async function runMonthlyReport(env, event) {
  const now = new Date(event.scheduledTime);
  const prev = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() - 1, 1));
  const mk = monthKeyOf(prev);

  await eachRecord(env, async (rec) => {
    // State bo'lsa jamlanmani qayta hisoblaymiz - bot kiritgan, ilovaga hali
    // o'tmagan yozuvlar ham hisobotga tushadi. Jonli hisob bo'sh chiqsa (masalan
    // ilovada eski tranzaksiyalar yo'q) ilova yuborgan saqlangan jamlanmaga qaytamiz.
    const live = rec.state
      ? monthSummary({ state: rec.state, pending: rec.pending }, mk)
      : null;
    const data = (live && live.txCount) ? live : (rec.months && rec.months[mk]);
    if (!data || !data.txCount) return;
    await sendMessage(env.TELEGRAM_BOT_TOKEN, rec.chatId,
      buildReport(mk, data, rec.cur), { reply_markup: miniAppKb(env.MINIAPP_URL) });
  });
}

/** Kunning rejasi. `morning === false` bo'lgan yozuvlar o'tkazib yuboriladi. */
async function runMorningBrief(env, event) {
  const d = new Date(new Date(event.scheduledTime).getTime() + TZ_OFFSET_MS);

  await eachRecord(env, async (rec) => {
    if (rec.morning === false) return;
    const text = buildMorning(rec, rec.cur, d);
    if (!text) return;
    await sendMessage(env.TELEGRAM_BOT_TOKEN, rec.chatId, text,
      { reply_markup: miniAppKb(env.MINIAPP_URL) });
  });
}

/**
 * Xaridlar rejasidagi sanadan bir kun oldingi eslatma (09:00 Toshkent).
 * `plans === false` bo'lgan yozuvlar o'tkazib yuboriladi.
 */
async function runPlanReminders(env, event) {
  const d = new Date(new Date(event.scheduledTime).getTime() + TZ_OFFSET_MS);

  await eachRecord(env, async (rec) => {
    if (rec.plans === false) return;
    const text = buildPlanReminder(rec, rec.cur, d);
    if (!text) return;
    await sendMessage(env.TELEGRAM_BOT_TOKEN, rec.chatId, text,
      { reply_markup: miniAppKb(env.MINIAPP_URL) });
  });
}

// Testlar uchun ochiladi (Worker runtime'i qo'shimcha eksportlarni e'tiborsiz qoldiradi)
export {
  parseEntry, parseAmount, matchCat, buildReport, monthSummary, allTx, accountBalance, norm,
  buildMorning, buildPlanReminder, budgetSpent, daysFromToday, monthDays, weekStartTash,
  monthStartTash,
};
