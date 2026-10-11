/**
 * Matn tahlili va balans hisobi testlari.
 * Ishga tushirish: cd worker && npm test
 */
import { parseEntry, allTx, accountBalance, monthSummary } from '../src/index.js';

const CATS = [
  { n: 'Maosh', t: 'income' }, { n: 'Bonus', t: 'income' }, { n: 'Taksi', t: 'income' },
  { n: 'Qarz', t: 'income' }, { n: 'Sovgʼa', t: 'income' }, { n: 'Boshqa', t: 'income' },
  { n: 'Ovqat', t: 'expense' }, { n: 'Ichimliklar', t: 'expense' }, { n: 'Uydagilar', t: 'expense' },
  { n: 'Transport', t: 'expense' }, { n: 'Yoqilgʼi', t: 'expense' }, { n: 'Xarid', t: 'expense' },
  { n: 'Koʼngilochar', t: 'expense' }, { n: 'Dorixona', t: 'expense' }, { n: 'Salomatlik', t: 'expense' },
  { n: 'Internet', t: 'expense' }, { n: 'Aloqa', t: 'expense' }, { n: 'Jarimalar', t: 'expense' },
  { n: 'Qarz', t: 'expense' }, { n: 'Kredit', t: 'expense' }, { n: 'Boshqa', t: 'expense' },
];
const ST = {
  cats: CATS,
  accounts: [
    { id: 'cash', name: 'Naqd', opening: 1000000 },
    { id: 'card', name: 'Bank karta', opening: 5000000 },
  ],
};

let pass = 0, fail = 0;
const ok = (cond, label, extra) => {
  if (cond) { pass++; console.log('  ✅ ' + label); }
  else { fail++; console.log('  ❌ ' + label + (extra ? ' — ' + extra : '')); }
};

/** Matn kutilgan maydonlarga tahlil qilinishini tekshiradi. */
function expectParse(text, exp) {
  const r = parseEntry(text, ST);
  if (r.error) return ok(false, JSON.stringify(text), r.error);
  const bad = Object.entries(exp).filter(([k, v]) => r.tx[k] !== v);
  ok(!bad.length, text,
    bad.map(([k, v]) => `${k}: kutilgan ${JSON.stringify(v)}, keldi ${JSON.stringify(r.tx[k])}`).join(' | '));
}

console.log('\n— Summa formatlari —');
expectParse('ovqat 25000', { amount: 25000 });
expectParse('ovqat 25k', { amount: 25000 });
expectParse('ovqat 25 ming', { amount: 25000 });
expectParse('ovqat 1.5mln', { amount: 1500000 });
expectParse('ovqat 1,5mln', { amount: 1500000 });
expectParse('ovqat 2m', { amount: 2000000 });

console.log('\n— So‘z tartibi —');
expectParse('ovqat 25k', { cat: 'Ovqat', type: 'expense' });
expectParse('25k ovqat', { cat: 'Ovqat', type: 'expense' });

console.log('\n— Tur aniqlash —');
expectParse('+5mln maosh', { type: 'income', cat: 'Maosh' });
expectParse('maosh 5mln', { type: 'income', cat: 'Maosh' });
expectParse('-30k kofe', { type: 'expense', cat: 'Ichimliklar' });
expectParse('taksi 20k', { type: 'expense', cat: 'Transport' });
expectParse('taksidan 80k', { type: 'income', cat: 'Taksi' });
expectParse('150000', { type: 'expense', cat: 'Boshqa' });

console.log('\n— Qo‘shimchali so‘zlar —');
expectParse('onamga 200k', { cat: 'Uydagilar' });
expectParse('ovqatga 30k', { cat: 'Ovqat' });
expectParse('taksiga 15k', { cat: 'Transport' });
expectParse('benzinga 200k', { cat: 'Yoqilgʼi' });
expectParse('dorixonadan 45k', { cat: 'Dorixona' });
expectParse('bolalarga 150k', { cat: 'Uydagilar' });
expectParse('internetni 60k', { cat: 'Internet' });
expectParse('kiyimga 300k', { cat: 'Xarid' });
expectParse('maoshim 5mln', { cat: 'Maosh', type: 'income' });

console.log('\n— Hisob va izoh —');
expectParse('benzin 120k karta', { accountId: 'card', cat: 'Yoqilgʼi' });
expectParse('ovqat 25k', { accountId: 'cash' });
expectParse('ovqat 25k naqd', { accountId: 'cash' });
expectParse('qarz 500k Jasur', { cat: 'Qarz', note: 'Jasur' });

console.log('\n— Rad etilishi kerak —');
for (const bad of ['salom', 'ovqat', '', '   ', 'abc def', '0 ovqat', '-0 ovqat']) {
  ok(!!parseEntry(bad, ST).error, 'rad etildi: ' + JSON.stringify(bad));
}

console.log('\n— Balans (state + pending) —');
const rec = {
  state: {
    ...ST,
    tx: [{ id: 'a', type: 'income', amount: 2000000, cat: 'Maosh', accountId: 'card', date: '2026-10-01T00:00:00Z' }],
    deletedIds: ['zzz'],
  },
  pending: [
    { id: 'b', type: 'expense', amount: 25000, cat: 'Ovqat', accountId: 'cash', date: '2026-10-11T00:00:00Z' },
    { id: 'a', type: 'income', amount: 2000000, cat: 'Maosh', accountId: 'card', date: '2026-10-01T00:00:00Z' },
    { id: 'zzz', type: 'expense', amount: 999999, cat: 'Ovqat', accountId: 'cash', date: '2026-10-11T00:00:00Z' },
  ],
};
ok(allTx(rec).length === 2, 'takror va o‘chirilgan yozuv hisoblanmaydi', 'keldi ' + allTx(rec).length);
ok(accountBalance(rec, 'cash') === 975000, 'Naqd = 975 000', String(accountBalance(rec, 'cash')));
ok(accountBalance(rec, 'card') === 7000000, 'Karta = 7 000 000', String(accountBalance(rec, 'card')));
const sum = monthSummary(rec, '2026-10');
ok(sum.income === 2000000 && sum.expense === 25000 && sum.txCount === 2,
  'oy jamlanmasi', JSON.stringify(sum));

console.log('\n' + pass + ' o‘tdi, ' + fail + ' xato\n');
process.exit(fail ? 1 : 0);
