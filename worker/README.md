# Telegram bot + oylik hisobot Worker'i

Ikki vazifa bajaradi:

1. **Bot** — lichkaga matn yozib tranzaksiya kiritasiz (`ovqat 25k`), ilovani ochish shart emas.
2. **Hisobot va sinxronizatsiya** — Mini App (`docs/index.html`) bilan maʼlumot almashadi,
   har oyning 1-sanasi oʻtgan oy hisobotini yuboradi.

**Nega Worker kerak?** Bot tokenini `docs/index.html` ichiga yozib boʻlmaydi — u ochiq
GitHub Pages'da turibdi. Token faqat Cloudflare secret sifatida shu yerda saqlanadi.

---

## 1. Matn orqali kirim (bot)

Botga shunchaki yozib yuborasiz:

| Yozasiz | Natija |
|---|---|
| `ovqat 25k` | Ovqat · −25 000 · Naqd |
| `25 ming taksi` | Transport · −25 000 |
| `benzin 120k karta` | Yoqilgʼi · −120 000 · Bank karta |
| `+5mln maosh` | Maosh · +5 000 000 |
| `onamga 200k` | Uydagilar · −200 000 |
| `qarz 500k Jasur` | Qarz · −500 000 · izoh: Jasur |
| `150000` | Boshqa · −150 000 (keyin tugma bilan kategoriya tanlanadi) |

**Summa:** `25000` · `25k` · `25 ming` · `1.5mln` · `2m`
**Daromad:** oldiga `+` qoʻyiladi, yoki kategoriya oʻzi daromad boʻlsa (`maosh`) avtomatik.
**Hisob:** matnda `karta` / `naqd` yoki hisob nomi boʻlsa shunisi, aks holda birinchi hisob.
**Soʻz tartibi** muhim emas, **qoʻshimchalar** tushuniladi (`ovqatga`, `taksiga`, `maoshim`).

Kalit soʻzlar jadvali (`KW`) `docs/index.html` dagisi bilan bir xil — bot va ilova
matnni aynan bir xil tushunadi.

Har bir yozuvdan keyin ikki tugma chiqadi: **✏️ Kategoriya** (oʻzgartirish) va
**❌ Bekor** (oʻchirish). Kategoriya aniqlanmasa — tanlash klaviaturasi darhol chiqadi.

### Buyruqlar

| Buyruq | Vazifasi |
|---|---|
| `/balans` | Hisoblar boʻyicha qoldiq va jami |
| `/oy` | Shu oy jamlanmasi (1-sanani kutmasdan) |
| `/hisobot` | Shu oy hisobotini yuborish |
| `/bugun` | Kunning rejasi (ertalabki xabarning oʻzi) |
| `/bekor` | Oxirgi kiritilganni oʻchirish |
| `/ertalab` | Ertalabki xabarni yoqish/oʻchirish |
| `/eslatma` | Reja sanasi eslatmasini yoqish/oʻchirish |
| `/help` | Yordam va namunalar |

---

## 2. Maʼlumot qanday oqadi

Bot **state'ni oʻzgartirmaydi** — faqat KV'dagi `pending[]` massiviga qoʻshadi:

```
Bot yozuvi  ──►  KV: pending[]
                     │
Mini App ochiladi ───┤ /pull  → pending'ni oladi
                     │        → mergeStates() bilan tx'ga qoʻshadi
                     └ /sync  → {ackPending:[id...]} bilan tasdiqlaydi,
                                Worker pending'dan oʻchiradi
```

Nega shunday: ilova ochiq turganda oʻzining state'ini `/sync` bilan yuboradi. Agar bot
ham shu state'ni yozsa, ikkisi bir-birini bosib ketardi. `pending[]` esa **append-only** —
hech narsa yoʻqolmaydi. Tasdiq (`ackPending`) yoʻqolsa ham xato boʻlmaydi: yozuvlar `id`
boʻyicha birlashtiriladi, ikkinchi marta qoʻshilmaydi.

Ilova ochiq boʻlsa bot yozuvi **~25 soniyada** oʻzi koʻrinadi (avtomatik sinxronizatsiya).
Ilovada oʻchirilgan yozuv `deletedIds` ga tushadi va qayta tiklanmaydi.

---

## 3. Oʻrnatish

```bash
cd worker
npm install
npx wrangler login
```

**1. KV namespace** (bir marta — allaqachon qilingan boʻlsa oʻtkazib yuboring):

```bash
npx wrangler kv namespace create REPORTS
```

Chiqqan `id = "..."` ni `wrangler.toml` ichiga qoʻyasiz.

**2. Secret'lar:**

```bash
npx wrangler secret put TELEGRAM_BOT_TOKEN
```

```bash
npx wrangler secret put WEBHOOK_SECRET
```

`WEBHOOK_SECRET` — oʻzingiz oʻylab topadigan tasodifiy satr (faqat `A-Z a-z 0-9 _ -`,
1–256 belgi). Telegram har bir webhook soʻrovida uni qaytarib yuboradi, Worker esa
tekshiradi — yaʼni webhook manzilini bilgan begona odam yolgʻon update yubora olmaydi.

Tasodifiy satr yasash:

```bash
node -e "console.log(require('crypto').randomBytes(24).toString('base64url'))"
```

**3. Deploy:**

```bash
npx wrangler deploy
```

**4. Webhook'ni roʻyxatdan oʻtkazish** — brauzerda bir marta ochasiz:

```
https://finance-report.<akkaunt>.workers.dev/setup?secret=<WEBHOOK_SECRET>
```

Bu bitta soʻrov uchtasini bajaradi: `setWebhook`, buyruqlar roʻyxati (`setMyCommands`)
va Mini App'ni ochadigan menu tugmasi (`setChatMenuButton`). Javobda uchalasi
`"ok": true` boʻlishi kerak.

**5. Botga `/start` yozing.** Birinchi yozgan odam KV'da **ega** sifatida qayd etiladi,
undan keyin bot boshqa hech kimga javob bermaydi.

Egani qoʻlda belgilash (ixtiyoriy, ishonchliroq) — `wrangler.toml` dagi `[vars]` ga:

```toml
OWNER_ID = "123456789"
```

Chat ID ni `/start` dan keyin `npx wrangler tail` da yoki
`https://api.telegram.org/bot<TOKEN>/getUpdates` dan koʻrasiz.

**6. Mini App'da ulash:** ilovada **Sozlama → 📊 Telegram oylik hisobot** boʻlimiga
Worker manzilini joylashtirasiz (birinchi ochilishda avtomatik qoʻyiladi).

---

## 4. Ertalabki xabar

Har kuni **08:00** (Toshkent) da kunning rejasi keladi:

```
☀️ 11-oktabr, yakshanba

💵 Qoldiq: 8 355 000 soʻm
📉 Oyda sarflandi: 2 345 000 soʻm (11/31 kun)
📊 Byudjetdan 59% sarflandi
✅ Bugun sarflash mumkin: ~78 000 soʻm (21 kunga 1 655 000)

🟡 Ovqat — 89% (95 000 qoldi)

⚠️ Bugun: Internet — −60 000 soʻm
📅 Ertaga: Ijara — −2 000 000 soʻm

🤝 Jasur — 500 000 soʻm · 2 kundan keyin
```

Nima koʻrsatiladi:

| Qator | Qachon chiqadi |
|---|---|
| Qoldiq va oylik sarf | Doim |
| **Bugun sarflash mumkin** | Oylik byudjet boʻlsa: qolgan summa ÷ qolgan kun |
| Kunlik oʻrtacha va prognoz | Byudjet yoʻq boʻlsa |
| Byudjet ogohlantirishi | Byudjetning 80% i sarflanganda (🟡), oshib ketganda (🔴) |
| Takrorlanuvchi toʻlov | Bugun, ertaga yoki kechikkan boʻlsa |
| Qarz muddati | 3 kun ichida yoki kechikkan boʻlsa |

**Bugun sarflash mumkin** — bu oddiy hisob (qolgan byudjet ÷ oy oxirigacha qolgan kun),
lekin kundalik qaror qabul qilishga eng koʻp yordam beradigan raqam. Minggacha pastga
yumaloqlanadi.

Bir nechta byudjet boʻlsa, hammasini qamrab oluvchisi (kategoriyasi tanlanmagan) olinadi —
aks holda kategoriya byudjetlari bilan ikki marta hisoblanib ketardi. Faqat kategoriya
byudjetlari boʻlsa ular qoʻshiladi.

**Oʻchirish:** `/ertalab`. Qayta yoqish ham shu buyruq. Holat KV'da (`morning`) saqlanadi,
standart holatda yoqilgan. Istalgan paytda koʻrish: `/bugun`.

### Xaridlar rejasi eslatmasi

Mini App'dagi **Rejalar** boʻlimida har bir xaridga ixtiyoriy **rejalashtirilgan sana**
qoʻyish mumkin. Shu sanaga **bir kun qolganda ertalab 09:00** (Toshkent) da lichkaga
eslatma keladi:

```
🛍️ Ertaga rejadagi xarid

• iPhone 16 — 1 200 000 soʻm (Texnika)
   📝 Doʻkon: Mediapark

💵 Qoldiq: 2 000 000 soʻm
```

Bir kunda bir nechta reja boʻlsa hammasi bitta xabarda (qimmatrogʻi yuqorida) keladi va
jami summa koʻrsatiladi. Jami qoldiqdan oshsa ogohlantirish qoʻshiladi. "Sotib oldim" deb
belgilangan buyumlarga eslatma ketmaydi.

**Oʻchirish:** `/eslatma` (holat KV'da `plans`, standart holatda yoqilgan). Ertalabki
xabardan mustaqil — biri oʻchirilsa ikkinchisi ishlashda davom etadi.

## 5. Oylik hisobot

Har oyning **1-sanasi 10:00** (Toshkent) da oʻtgan oy hisoboti avtomatik keladi:

```
📊 Sentabr 2026 — oylik hisobot

💰 Daromad:  5 000 000 soʻm
💸 Xarajat:  1 500 000 soʻm
📈 Qoldiq:   +3 500 000 soʻm

Daromadning 70% i qoldi.

💸 Xarajatlar (2 ta kategoriya)
1. Ovqat — 900 000 (60%)
2. Transport — 600 000 (40%)

Jami 4 ta tranzaksiya
```

`/hisobot` buyrugʻi yoki ilovadagi tugma orqali istalgan paytda ham yuborish mumkin.

---

## 6. Xavfsizlik

| Nima | Qanday himoyalangan |
|---|---|
| Mini App soʻrovlari (`/sync`, `/pull`, `/report`) | Telegram `initData` imzosi (`HMAC-SHA256`, bot tokeni bilan). Chat ID soʻrovdan emas, **imzolangan** `initData` ichidagi `user.id` dan olinadi. 24 soatdan eski imzolar rad etiladi. |
| Webhook (`/webhook`) | `X-Telegram-Bot-Api-Secret-Token` sarlavhasi `WEBHOOK_SECRET` bilan solishtiriladi |
| Bot buyruqlari | Faqat ega (`OWNER_ID` yoki birinchi `/start` yozgan chat) javob oladi |
| Sozlash (`/setup`) | `?secret=` `WEBHOOK_SECRET` ga teng boʻlishi kerak |
| Bot tokeni | Faqat Cloudflare secret sifatida; mijoz kodida hech qachon boʻlmaydi |

Imzo va secret solishtiruvlari `safeEqual()` bilan — uzunligi teng satrlar vaqt
oqishidan qatʼi nazar solishtiriladi.

---

## 7. Endpointlar

| Metod | Manzil | Vazifasi |
|---|---|---|
| `GET` | `/` | Holat: deploy qilingan `features`, `bot`, `commands` (9-boʻlimga qarang) |
| `GET` | `/setup?secret=` | Webhook + buyruqlar + menu tugmasini roʻyxatdan oʻtkazadi |
| `POST` | `/webhook` | Telegram update (faqat Telegram chaqiradi) |
| `POST` | `/sync` | State va oylik jamlanmani KV'ga saqlaydi, `ackPending` ni qayta ishlaydi |
| `POST` | `/pull` | State + bot kiritgan `pending` yozuvlarni qaytaradi |
| `POST` | `/report` | Hisobotni darhol yuboradi (`{month: "2026-09"}`) |

Cron jadvallari:

| Jadval | Toshkent vaqti | Nima qiladi |
|---|---|---|
| `0 5 1 * *` | Har oyning 1-sanasi 10:00 | Oʻtgan oy hisoboti |
| `0 3 * * *` | Har kuni 08:00 | Kunning rejasi (`/ertalab` bilan oʻchiriladi) |
| `0 4 * * *` | Har kuni 09:00 | Ertaga rejalashtirilgan xaridlar (`/eslatma` bilan oʻchiriladi) |

---

## 8. Keyingi bosqichlar

Rejalashtirilgan funksiyalar va ataylab qilinmayotgan narsalar:
[`ROADMAP.md`](ROADMAP.md).

## 9. Nosozlikni topish

**Bot hech qanday buyruqqa javob bermaydi?** Birinchi navbatda qaysi kod deploy
qilinganini tekshiring:

```bash
curl https://finance-report.ruzmatjs.workers.dev/
```

Kutilgan javob:

```json
{
  "ok": true,
  "service": "finance-report-worker",
  "features": ["sync", "report", "webhook", "text-entry", "morning", "plan-reminder"],
  "bot": true,
  "owner": "kv",
  "commands": ["bugun", "balans", "oy", "hisobot", "bekor", "ertalab", "eslatma", "help"]
}
```

| Nima koʻrsangiz | Maʼnosi | Nima qilish kerak |
|---|---|---|
| `features` maydoni **yoʻq** | Eski kod deployda turibdi — `/webhook` endpoint'i mavjud emas, Telegram chaqiradigan manzil yoʻq | `npx wrangler deploy` |
| `features` ichida `morning` yoʻq | Deploy eski, ertalabki xabar hali yoʻq | `npx wrangler deploy` |
| `features` ichida `plan-reminder` yoʻq | Deploy eski, reja sanasi eslatmasi hali yoʻq | `npx wrangler deploy` |
| `"bot": false` | `WEBHOOK_SECRET` secret qoʻyilmagan — webhook 500 bilan rad etiladi | `npx wrangler secret put WEBHOOK_SECRET`, soʻng deploy |
| `commands` ichida buyruq yoʻq | Kod eski | `npx wrangler deploy` |
| Hammasi toʻgʻri, lekin bot jim | Webhook roʻyxatdan oʻtmagan | `/setup?secret=<WEBHOOK_SECRET>` ni brauzerda ochish |
| Bot `"Bu shaxsiy bot."` deb javob beradi | KV'dagi `owner` boshqa odamga yozilgan | `wrangler.toml` ga `OWNER_ID` qoʻyish (env KV'dan ustun turadi) |

**Yangi buyruq menyuda koʻrinmaydi?** Kod deploy boʻlgan boʻlsa buyruq qoʻlda yozilsa
ishlaydi, lekin menyu roʻyxati `setMyCommands` orqali alohida yangilanadi — `/setup` ni
qayta ochish kerak.

Webhook holatini Telegram'dan soʻrash (token kerak):

```bash
curl "https://api.telegram.org/bot<TOKEN>/getWebhookInfo"
```

Javobda `url` sizning Worker manzilingiz + `/webhook` boʻlishi va
`last_error_message` boʻsh boʻlishi kerak.

## 10. Testlar va loglar

```bash
npm test
```

Beshta toʻplam:

| Fayl | Nimani tekshiradi |
|---|---|
| `test/parse.test.mjs` | Summa formatlari, soʻz tartibi, qoʻshimchalar, hisob tanlash, balans |
| `test/morning.test.mjs` | Ertalabki xabar: vaqt mintaqasi, byudjet hisobi, toʻlov va qarz muddatlari |
| `test/plan.test.mjs` | Reja eslatmasi: sana hisobi, saralash, qoldiq ogohlantirishi |
| `test/cron.test.mjs` | Cron dispatch — qaysi jadval qaysi xabarni yuboradi |
| `test/webhook.test.mjs` | Har bir buyruqning haqiqiy javob matni, ega tekshiruvi, secret |

`cron.test.mjs` va `webhook.test.mjs` da KV hamda Telegram API mock qilinadi —
test paytida tashqi soʻrov ketmaydi.

```bash
npx wrangler tail
```

Jonli loglar. Webhook ichidagi xatolar `console.error` ga yoziladi.
