/**
 * Ertalabki xabar (kunning rejasi) testlari.
 * Ishga tushirish: cd worker && npm test
 */
import { buildMorning, budgetSpent, daysFromToday, monthDays, monthStartTash, weekStartTash }
  from '../src/index.js';

let pass = 0, fail = 0;
const ok = (cond, label, extra) => {
  if (cond) { pass++; console.log('  ✅ ' + label); }
  else { fail++; console.log('  ❌ ' + label + (extra ? ' — ' + extra : '')); }
};

/** Toshkent taqvimidagi sana -> buildMorning kutgan "hozir". */
const tash = (y, m, day, h = 8) => new Date(Date.UTC(y, m - 1, day, h));
/** Toshkent mahalliy vaqtidan ISO (ilova aynan shunday saqlaydi). */
const iso = (y, m, day, h = 12) => new Date(Date.UTC(y, m - 1, day, h) - 5 * 3600000).toISOString();

const ACCOUNTS = [{ id: 'cash', name: 'Naqd', e: '💵', opening: 1000000 }];
const tx = (id, amount, cat, day, type = 'expense') =>
  ({ id, type, amount, cat, accountId: 'cash', date: iso(2026, 10, day) });

const baseState = (over) => ({
  accounts: ACCOUNTS, cats: [], budgets: [], recurring: [], debts: [], tx: [], ...over,
});

// ---------- Vaqt mintaqasi ----------
console.log('\n— Toshkent vaqt mintaqasi —');
{
  const d = tash(2026, 10, 11);
  const md = monthDays(d);
  ok(md.day === 11 && md.total === 31 && md.left === 21, 'oydagi kunlar 11/31, 21 kun qoldi',
    JSON.stringify(md));

  // Oy boshi: 1-oktabr 00:00 Toshkent = 30-sentabr 19:00 UTC
  ok(monthStartTash(d).toISOString() === '2026-09-30T19:00:00.000Z', 'oy boshi UTC\'da to‘g‘ri',
    monthStartTash(d).toISOString());

  // 11-oktabr 2026 - yakshanba, shuning uchun hafta boshi 5-oktabr (dushanba)
  ok(weekStartTash(d).toISOString() === '2026-10-04T19:00:00.000Z', 'hafta dushanbadan boshlanadi',
    weekStartTash(d).toISOString());

  // Mahalliy 12-oktabr ertalab 01:00 -> UTC'da 11-oktabr 20:00, lekin "ertaga" bo'lishi kerak
  ok(daysFromToday(iso(2026, 10, 12, 1), d) === 1, 'yarim kechadan keyingi sana "ertaga" deb o‘qiladi',
    String(daysFromToday(iso(2026, 10, 12, 1), d)));
  ok(daysFromToday(iso(2026, 10, 11, 23), d) === 0, 'kechqurungi sana "bugun"');
  ok(daysFromToday(iso(2026, 10, 9), d) === -2, 'o‘tgan sana manfiy');
}

// ---------- State yo'q ----------
console.log('\n— State yo‘q —');
ok(buildMorning({ pending: [] }, 'soʻm', tash(2026, 10, 11)) === null,
  'sinxronlanmagan yozuvga xabar yuborilmaydi');

// ---------- Byudjetsiz: prognoz ----------
console.log('\n— Byudjetsiz —');
{
  const rec = {
    state: baseState({ tx: [tx('a', 100000, 'Ovqat', 1), tx('b', 200000, 'Xarid', 5)] }),
    pending: [],
  };
  const t = buildMorning(rec, 'soʻm', tash(2026, 10, 11));
  ok(t.includes('11-oktabr') && t.includes('yakshanba'), 'sana va hafta kuni', t.split('\n')[0]);
  ok(t.includes('Oyda sarflandi: <b>300 000'), 'oylik sarf qo‘shildi');
  ok(t.includes('Kunlik oʻrtacha') && t.includes('prognoz'), 'byudjet yo‘qligida prognoz ko‘rsatiladi');
  ok(t.includes('Qoldiq: <b>700 000'), 'qoldiq = 1 000 000 − 300 000');
}

// ---------- Oylik byudjet: kunlik imkoniyat ----------
console.log('\n— Oylik byudjet —');
{
  const rec = {
    state: baseState({
      budgets: [{ id: 'b1', name: 'Umumiy', limit: 3100000, period: 'monthly', catIds: [] }],
      tx: [tx('a', 1000000, 'Ovqat', 3)],
    }),
    pending: [],
  };
  const t = buildMorning(rec, 'soʻm', tash(2026, 10, 11));
  // 3 100 000 limit, 1 000 000 sarflandi -> 32%, qolgani 2 100 000 / 21 kun = 100 000
  ok(t.includes('Byudjetdan <b>32%</b>'), 'byudjet foizi', t);
  ok(t.includes('Bugun sarflash mumkin: <b>~100 000'), 'kunlik imkoniyat = qolgan / qolgan kun', t);
  ok(!t.includes('🟡') && !t.includes('🔴'), '80% dan past byudjet alohida ko‘rsatilmaydi');
}

// ---------- Qoplanadigan byudjetlar ikki marta hisoblanmasligi ----------
console.log('\n— Qoplanadigan byudjetlar —');
{
  // "Umumiy" (catIds bo'sh) hamma xarajatni qamraydi, "Ovqat" esa uning ichida.
  // Ikkisini qo'shib yuborsak limit ham, sarf ham ikki marta sanaladi.
  const rec = {
    state: baseState({
      budgets: [
        { id: 'b1', name: 'Umumiy', limit: 2000000, period: 'monthly', catIds: [] },
        { id: 'b2', name: 'Ovqat', limit: 900000, period: 'monthly', catIds: ['Ovqat'] },
      ],
      tx: [tx('a', 1000000, 'Ovqat', 3)],
    }),
    pending: [],
  };
  const t = buildMorning(rec, 'soʻm', tash(2026, 10, 11));
  // Faqat "Umumiy": 1 000 000 / 2 000 000 = 50%, qolgani 1 000 000 / 21 kun ≈ 47 000
  ok(t.includes('Byudjetdan <b>50%</b>'), 'faqat umumiy byudjet olinadi (50%, 69% emas)', t);
  ok(t.includes('~47 000'), 'kunlik imkoniyat umumiy byudjetdan hisoblanadi', t);
  // Kategoriya byudjeti alohida qatorda ogohlantiradi (111%)
  ok(t.includes('🔴 Ovqat — <b>111%</b>'), 'kategoriya byudjeti alohida ko‘rsatiladi', t);
}

// ---------- Faqat kategoriya byudjetlari bo'lsa qo'shiladi ----------
console.log('\n— Faqat kategoriya byudjetlari —');
{
  const rec = {
    state: baseState({
      budgets: [
        { id: 'b1', name: 'Ovqat', limit: 600000, period: 'monthly', catIds: ['Ovqat'] },
        { id: 'b2', name: 'Transport', limit: 400000, period: 'monthly', catIds: ['Transport'] },
      ],
      tx: [tx('a', 300000, 'Ovqat', 3), tx('b', 200000, 'Transport', 4)],
    }),
    pending: [],
  };
  const t = buildMorning(rec, 'soʻm', tash(2026, 10, 11));
  // Umumiy byudjet yo'q -> 1 000 000 limit, 500 000 sarf = 50%
  ok(t.includes('Byudjetdan <b>50%</b>'), 'kesishmaydigan byudjetlar qo‘shiladi', t);
}

// ---------- Byudjet oshib ketdi ----------
console.log('\n— Byudjet oshdi —');
{
  const rec = {
    state: baseState({
      budgets: [{ id: 'b1', name: 'Ovqat', limit: 500000, period: 'monthly', catIds: ['Ovqat'] }],
      tx: [tx('a', 650000, 'Ovqat', 4)],
    }),
    pending: [],
  };
  const t = buildMorning(rec, 'soʻm', tash(2026, 10, 11));
  ok(t.includes('Byudjet tugadi') && t.includes('150 000'), 'oshgan summa ko‘rsatildi', t);
  ok(t.includes('🔴 Ovqat — <b>130%</b>'), 'alohida byudjet qizil bilan', t);
}

// ---------- Byudjet 80% chegarasi ----------
console.log('\n— 80% chegarasi —');
{
  const mk = (spent) => ({
    state: baseState({
      budgets: [{ id: 'b1', name: 'Ovqat', limit: 100000, period: 'monthly', catIds: ['Ovqat'] }],
      tx: [tx('a', spent, 'Ovqat', 4)],
    }),
    pending: [],
  });
  ok(!buildMorning(mk(79000), 'soʻm', tash(2026, 10, 11)).includes('🟡'), '79% — ogohlantirish yo‘q');
  ok(buildMorning(mk(80000), 'soʻm', tash(2026, 10, 11)).includes('🟡 Ovqat — <b>80%</b>'),
    '80% — sariq ogohlantirish');
}

// ---------- Byudjet kategoriya filtri ----------
console.log('\n— Byudjet kategoriya filtri —');
{
  const rec = {
    state: baseState({ tx: [tx('a', 100000, 'Ovqat', 3), tx('b', 900000, 'Xarid', 4)] }),
    pending: [],
  };
  const d = tash(2026, 10, 11);
  const only = { id: 'b', name: 'Ovqat', limit: 500000, period: 'monthly', catIds: ['Ovqat'] };
  const all = { id: 'b', name: 'Hammasi', limit: 500000, period: 'monthly', catIds: [] };
  ok(budgetSpent(rec, only, d) === 100000, 'faqat belgilangan kategoriya hisoblanadi',
    String(budgetSpent(rec, only, d)));
  ok(budgetSpent(rec, all, d) === 1000000, 'bo‘sh catIds = hamma xarajat',
    String(budgetSpent(rec, all, d)));
}

// ---------- Takrorlanuvchi to'lovlar ----------
console.log('\n— Takrorlanuvchi to‘lovlar —');
{
  const rec = {
    state: baseState({
      recurring: [
        { id: 'r1', title: 'Ijara', type: 'expense', amount: 2000000, nextDue: iso(2026, 10, 11), active: true },
        { id: 'r2', title: 'Internet', type: 'expense', amount: 60000, nextDue: iso(2026, 10, 12), active: true },
        { id: 'r3', title: 'Maosh', type: 'income', amount: 5000000, nextDue: iso(2026, 10, 9), active: true },
        { id: 'r4', title: 'Keyinroq', type: 'expense', amount: 1, nextDue: iso(2026, 10, 20), active: true },
        { id: 'r5', title: 'O‘chirilgan', type: 'expense', amount: 1, nextDue: iso(2026, 10, 11), active: false },
      ],
    }),
    pending: [],
  };
  const t = buildMorning(rec, 'soʻm', tash(2026, 10, 11));
  ok(t.includes('⚠️ Bugun: Ijara — <b>−2 000 000'), 'bugungi to‘lov', t);
  ok(t.includes('📅 Ertaga: Internet'), 'ertangi to‘lov');
  ok(t.includes('⏰ Kechikdi: Maosh — <b>+5 000 000'), 'kechikkan to‘lov, daromad belgisi bilan');
  ok(!t.includes('Keyinroq'), 'uzoq muddat ko‘rsatilmaydi');
  ok(!t.includes('O‘chirilgan'), 'active:false o‘tkazib yuboriladi');
}

// ---------- Qarz muddatlari ----------
console.log('\n— Qarz muddatlari —');
{
  const rec = {
    state: baseState({
      debts: [
        { id: 'd1', person: 'Jasur', type: 'lend', amount: 500000, paid: 100000, dueDate: iso(2026, 10, 14), status: 'active' },
        { id: 'd2', person: 'Aziz', type: 'borrow', amount: 300000, paid: 0, dueDate: iso(2026, 10, 8), status: 'active' },
        { id: 'd3', person: 'Uzoq', type: 'lend', amount: 100000, paid: 0, dueDate: iso(2026, 10, 25), status: 'active' },
        { id: 'd4', person: 'Yopilgan', type: 'lend', amount: 100000, paid: 100000, dueDate: iso(2026, 10, 11), status: 'settled' },
        { id: 'd5', person: 'Muddatsiz', type: 'lend', amount: 100000, paid: 0, dueDate: '', status: 'active' },
      ],
    }),
    pending: [],
  };
  const t = buildMorning(rec, 'soʻm', tash(2026, 10, 11));
  ok(t.includes('Jasur — <b>400 000 soʻm</b> · 3 kundan keyin'), 'qolgan summa va muddat', t);
  ok(t.includes('Aziz — <b>300 000 soʻm</b> · 3 kun kechikdi'), 'kechikkan qarz');
  ok(!t.includes('Uzoq'), '3 kundan uzoq muddat ko‘rsatilmaydi');
  ok(!t.includes('Yopilgan'), 'settled qarz o‘tkazib yuboriladi');
  ok(!t.includes('Muddatsiz'), 'muddati yo‘q qarz ko‘rsatilmaydi');
}

// ---------- Bot kiritgan, ilovaga hali o'tmagan yozuvlar ----------
console.log('\n— pending hisobga olinadi —');
{
  const rec = {
    state: baseState({ tx: [tx('a', 100000, 'Ovqat', 3)] }),
    pending: [tx('p1', 50000, 'Ovqat', 11)],
  };
  const t = buildMorning(rec, 'soʻm', tash(2026, 10, 11));
  ok(t.includes('Oyda sarflandi: <b>150 000'), 'pending xarajat oylik sarfga qo‘shildi', t);
  ok(t.includes('Qoldiq: <b>850 000'), 'pending qoldiqqa ta’sir qildi');
}

// ---------- Oyning birinchi kuni ----------
console.log('\n— Oyning 1-kuni —');
{
  const rec = { state: baseState({ tx: [] }), pending: [] };
  const t = buildMorning(rec, 'soʻm', tash(2026, 10, 1));
  ok(t.includes('Oyda sarflandi: <b>0'), '1-kunda sarf nol');
  ok(!t.includes('prognoz'), '1-kunda prognoz ko‘rsatilmaydi (nolga bo‘linish yo‘q)');
}

console.log('\n' + pass + ' o‘tdi, ' + fail + ' xato\n');
process.exit(fail ? 1 : 0);
