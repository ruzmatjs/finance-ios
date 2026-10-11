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
| `/bekor` | Oxirgi kiritilganni oʻchirish |
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

## 4. Oylik hisobot

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

## 5. Xavfsizlik

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

## 6. Endpointlar

| Metod | Manzil | Vazifasi |
|---|---|---|
| `GET` | `/` | Holat tekshiruvi |
| `GET` | `/setup?secret=` | Webhook + buyruqlar + menu tugmasini roʻyxatdan oʻtkazadi |
| `POST` | `/webhook` | Telegram update (faqat Telegram chaqiradi) |
| `POST` | `/sync` | State va oylik jamlanmani KV'ga saqlaydi, `ackPending` ni qayta ishlaydi |
| `POST` | `/pull` | State + bot kiritgan `pending` yozuvlarni qaytaradi |
| `POST` | `/report` | Hisobotni darhol yuboradi (`{month: "2026-09"}`) |

Cron (`0 5 1 * *`) — har oyning 1-sanasida oʻtgan oy hisobotini yuboradi.

---

## 7. Keyingi bosqichlar

Rejalashtirilgan funksiyalar va ataylab qilinmayotgan narsalar:
[`ROADMAP.md`](ROADMAP.md).

## 8. Testlar va loglar

```bash
npm test
```

Matn tahlili (summa formatlari, soʻz tartibi, qoʻshimchalar, hisob tanlash) va
balans hisobini tekshiradi — 38 ta holat.

```bash
npx wrangler tail
```

Jonli loglar. Webhook ichidagi xatolar `console.error` ga yoziladi.
