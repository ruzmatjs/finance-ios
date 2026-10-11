/**
 * Xaridlar rejasi eslatmasi (sanadan 1 kun oldin, 09:00 Toshkent) testlari.
 * Ishga tushirish: cd worker && npm test
 */
import { buildPlanReminder, daysFromToday } from '../src/index.js';

let pass = 0, fail = 0;
const ok = (cond, label, extra) => {
  if (cond) { pass++; console.log('  ✅ ' + label); }
  else { fail++; console.log('  ❌ ' + label + (extra ? ' — ' + extra : '')); }
};

/** Cron 09:00 Toshkent'da ishlaydi: 04:00 UTC + 5 soat. */
const tash = (y, m, day, h = 9) => new Date(Date.UTC(y, m - 1, day, h));

const ACCOUNTS = [{ id: 'cash', name: 'Naqd', e: '💵', opening: 2000000 }];
const rec = (wishlist, over) => ({
  state: { accounts: ACCOUNTS, cats: [], budgets: [], recurring: [], debts: [], tx: [], wishlist },
  pending: [],
  ...over,
});
const item = (over) => ({
  id: 'w1', title: 'iPhone 16', price: 1200000, cat: 'Texnika',
  priority: 'high', status: 'planned', note: '', ...over,
});

// ---------- Sana hisobi ----------
console.log('\n— Sana hisobi (YYYY-MM-DD) —');
{
  const d = tash(2026, 10, 11);
  ok(daysFromToday('2026-10-12', d) === 1, 'ertangi sana = 1 kun', String(daysFromToday('2026-10-12', d)));
  ok(daysFromToday('2026-10-11', d) === 0, 'bugungi sana = 0 kun');
  ok(daysFromToday('2026-10-10', d) === -1, 'kechagi sana = -1 kun');
}

// ---------- Ertaga rejalashtirilgan xarid ----------
console.log('\n— Ertaga rejada bor —');
{
  const t = buildPlanReminder(rec([item({ dueDate: '2026-10-12', note: 'Doʻkon: Mediapark' })]),
    'soʻm', tash(2026, 10, 11));
  ok(!!t, 'xabar tuzildi');
  ok(t.includes('Ertaga rejadagi xarid'), 'sarlavha “Ertaga”', t && t.split('\n')[0]);
  ok(t.includes('iPhone 16'), 'buyum nomi bor');
  ok(t.includes('1 200 000'), 'narx formatlandi');
  ok(t.includes('Mediapark'), 'izoh qoʻshildi');
  ok(t.includes('Qoldiq: <b>2 000 000'), 'qoldiq koʻrsatildi');
  ok(!t.includes('Jami'), 'bitta buyumda “Jami” yoʻq');
}

// ---------- Boshqa kunlar: xabar yo'q ----------
console.log('\n— Sana mos emas —');
{
  const d = tash(2026, 10, 11);
  ok(buildPlanReminder(rec([item({ dueDate: '2026-10-11' })]), 'soʻm', d) === null,
    'bugungi sanaga xabar ketmaydi');
  ok(buildPlanReminder(rec([item({ dueDate: '2026-10-15' })]), 'soʻm', d) === null,
    '4 kun qolganida xabar ketmaydi');
  ok(buildPlanReminder(rec([item({ dueDate: '2026-10-10' })]), 'soʻm', d) === null,
    'oʻtib ketgan sanaga xabar ketmaydi');
  ok(buildPlanReminder(rec([item({})]), 'soʻm', d) === null, 'sanasi yoʻq rejaga xabar ketmaydi');
  ok(buildPlanReminder(rec([]), 'soʻm', d) === null, 'boʻsh rejaga xabar ketmaydi');
  ok(buildPlanReminder({ state: null }, 'soʻm', d) === null, 'state yoʻq boʻlsa null');
}

// ---------- Sotib olingan buyum ----------
console.log('\n— Sotib olingan —');
{
  const t = buildPlanReminder(rec([item({ dueDate: '2026-10-12', status: 'bought' })]),
    'soʻm', tash(2026, 10, 11));
  ok(t === null, 'olingan buyumga eslatma ketmaydi', t);
}

// ---------- Bir nechta buyum ----------
console.log('\n— Bir nechta buyum —');
{
  const t = buildPlanReminder(rec([
    item({ id: 'w1', title: 'Krossovka', price: 500000, dueDate: '2026-10-12' }),
    item({ id: 'w2', title: 'Mebel', price: 3000000, dueDate: '2026-10-12' }),
    item({ id: 'w3', title: 'Keyinga', price: 100000, dueDate: '2026-10-20' }),
  ]), 'soʻm', tash(2026, 10, 11));
  const lines = t.split('\n');
  ok(lines.findIndex((l) => l.includes('Mebel')) < lines.findIndex((l) => l.includes('Krossovka')),
    'qimmatrogʻi yuqorida');
  ok(!t.includes('Keyinga'), 'boshqa sanadagi buyum qoʻshilmadi');
  ok(t.includes('Jami: <b>3 500 000'), 'jami summa toʻgʻri', t);
  ok(t.includes('⚠️') && t.includes('1 500 000'), 'qoldiq yetmasligi ogohlantirildi', t);
}

// ---------- Qoldiq yetarli ----------
console.log('\n— Qoldiq yetarli —');
{
  const t = buildPlanReminder(rec([item({ price: 300000, dueDate: '2026-10-12' })]),
    'soʻm', tash(2026, 10, 11));
  ok(!t.includes('⚠️'), 'yetarli boʻlsa ogohlantirish yoʻq', t);
}

console.log('\n' + pass + ' o‘tdi, ' + fail + ' xato\n');
process.exit(fail ? 1 : 0);
