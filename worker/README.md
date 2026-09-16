# Telegram oylik hisobot Worker'i

Mini App (`docs/index.html`) oylik jamlanmani shu Worker'ga yuboradi, Worker esa bot orqali
sizning shaxsiy chatingizga xabar tashlaydi.

**Nega Worker kerak?** Bot tokenini `docs/index.html` ichiga yozib bo'lmaydi — u ochiq
GitHub Pages'da turibdi. Token faqat Cloudflare secret sifatida shu yerda saqlanadi.

## Nima yuboriladi

```
📊 Sentabr 2026 — oylik hisobot

💰 Daromad:  5 000 000 so'm
💸 Xarajat:  1 500 000 so'm
📈 Qoldiq:   +3 500 000 so'm

Daromadning 70% i qoldi.

Eng ko'p sarflangan:
1. Ovqat — 900 000 (60%)
2. Transport — 600 000 (40%)

Jami 4 ta tranzaksiya
```

Har oyning **1-sanasi 10:00** (Toshkent) da o'tgan oy hisoboti avtomatik keladi.
Sozlamalardagi tugma orqali istalgan paytda ham yuborish mumkin.

## O'rnatish (~10 daqiqa)

```bash
cd worker
npm install
npx wrangler login
```

**1. KV namespace yarating** (foydalanuvchi jamlanmalari shu yerda saqlanadi):

```bash
npx wrangler kv namespace create REPORTS
```

Chiqqan `id = "..."` ni `wrangler.toml` dagi `KV_NAMESPACE_ID_SHU_YERGA` o'rniga qo'ying.

**2. Bot tokenini secret sifatida qo'ying** (bu faylga yozmang):

```bash
npx wrangler secret put TELEGRAM_BOT_TOKEN
```

**3. Deploy:**

```bash
npx wrangler deploy
```

Natijada `https://finance-report.<akkaunt>.workers.dev` manzili chiqadi.

**4. Mini App'da ulash:** ilovada **Sozlama → 📊 Telegram oylik hisobot** bo'limiga
o'sha manzilni joylashtiring va **"Shu oy hisobotini yuborish"** tugmasini bosib tekshiring.

## Xavfsizlik

Har bir so'rov Telegram `initData` imzosi bilan tekshiriladi
(`HMAC-SHA256`, bot tokeni bilan). Imzosi yaroqsiz yoki 24 soatdan eski so'rovlar
`401` bilan rad etiladi. Chat ID so'rovdan emas, **imzolangan** `initData` ichidagi
`user.id` dan olinadi — ya'ni boshqa birovning nomidan xabar yuborib bo'lmaydi.

## Endpointlar

| Metod | Manzil | Vazifasi |
|---|---|---|
| `GET` | `/` | Holat tekshiruvi |
| `POST` | `/sync` | Oxirgi 3 oy jamlanmasini KV'ga saqlaydi (ilova avtomatik chaqiradi) |
| `POST` | `/report` | Hisobotni darhol yuboradi (`{month: "2026-09"}`) |

Cron (`0 5 1 * *`) — har oyning 1-sanasida KV'dagi har bir foydalanuvchiga
o'tgan oy hisobotini yuboradi.

## Loglarni ko'rish

```bash
npx wrangler tail
```
