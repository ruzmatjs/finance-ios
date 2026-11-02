# Finance — Telegram bot + Mini App

Shaxsiy moliya hisobi, toʻliq Telegram ichida ishlaydi. Alohida ilova oʻrnatish shart emas.

| Qism | Joyi | Vazifasi |
|---|---|---|
| **Bot** | [`worker/`](worker/) | Cloudflare Worker: botga `ovqat 25k` deb yozib kiritish, `/bugun`, `/balans`, `/oy`, `/hisobot` buyruqlari, ertalabki xabar, reja eslatmasi, oylik hisobot |
| **Mini App** | [`docs/index.html`](docs/index.html) | Bot menyusidagi tugma orqali ochiladigan ilova (GitHub Pages): balans, tarix, hisobot, rejalar, qarzlar, byudjet |
| **Oy oxiri eslatmasi** | [`.github/workflows/rate-reminder.yml`](.github/workflows/rate-reminder.yml) | Oy tugashiga 1 kun qolganda xaridlarni baholashni eslatadi |

## Qanday ishlaydi

```
Siz ──► Bot (matn: "taksi 18k") ──► Worker KV: pending[]
                                         │
Mini App ochiladi ──── /pull ────────────┘  bot yozuvlari ilovaga qoʻshiladi
Mini App ──── /sync ──► Worker               ertalabki xabar va hisobot shu maʼlumotdan
Mini App ◄──► Telegram CloudStorage          barcha qurilmalaringizda bir xil
```

Maʼlumot qurilmada (localStorage + IndexedDB), Telegram CloudStorage'da va Worker KV'da
saqlanadi. Bot tokeni faqat Cloudflare secret sifatida turadi.

## Oʻrnatish

1. **Worker va bot** — [`worker/README.md`](worker/README.md) dagi qadamlar (KV, secret'lar, deploy, `/setup`).
2. **Mini App** — repo Settings → Pages → `main` branch, `/docs` papka.
   Manzil `worker/wrangler.toml` dagi `MINIAPP_URL` bilan bir xil boʻlishi kerak.
3. Botga `/start` yozing va pastdagi menyu tugmasidan ilovani oching.

## Mini App dizayni

- Telegram ichida "Telegram" mavzusi tanlangan boʻlsa ranglar foydalanuvchining Telegram
  mavzusidan olinadi (`--tg-theme-*`); qoʻlda yorugʻ/qorongʻu ham tanlash mumkin.
- Bitta fayl, kutubxonasiz. Dizayn tokenlari `docs/index.html` boshidagi `:root` da.
- Har oʻzgarishda `<meta name="app-version">` ni yangilang — eski kesh ochilganda ilova
  yangilashni taklif qiladi.
