# Bot rivojlanish rejasi

Shaxsiy foydalanish uchun (bitta foydalanuvchi). Ko'p foydalanuvchiga mo'ljallangan
g'oyalar ataylab tashlab yuborilgan — oxirgi bo'limga qarang.

**Hozirgi holat:** `worker/src/index.js` — Telegram bot + Mini App sinxronizatsiyasi
+ oylik hisobot. O'rnatish: [`README.md`](README.md).

---

## ✅ 1-bosqich — Matn orqali kirim (bajarildi)

Ilovani ochmasdan botga yozib xarajat kiritish. Kundalik foydalanishdagi eng katta
o'zgarish: do'konda turib ilovani ochishga erinish sabab ko'p narsa yozilmay qolardi.

- `POST /webhook` — `X-Telegram-Bot-Api-Secret-Token` bilan himoyalangan
- `GET /setup?secret=` — webhook + buyruqlar + menu tugmasini bir marta ro'yxatdan o'tkazadi
- Erkin matn tahlili: `ovqat 25k`, `25 ming taksi`, `+5mln maosh`, `onamga 200k`
- Kalit so'zlar jadvali (`KW`) `docs/index.html` dagisi bilan bir xil
- O'zbek tilidagi kelishik/egalik qo'shimchalari ajratiladi (`ovqatga`, `maoshim`)
- Tugmalar: ✏️ Kategoriya · ❌ Bekor
- Buyruqlar: `/balans` · `/oy` · `/hisobot` · `/bekor` · `/help`
- **Arxitektura:** bot `state`ni o'zgartirmaydi, faqat KV'dagi append-only `pending[]`
  ga qo'shadi. Ilova `/pull` bilan oladi, `mergeStates()` bilan birlashtiradi,
  `ackPending` bilan tasdiqlaydi. Shu sababli ilova va bot bir vaqtda yozsa ham
  hech narsa yo'qolmaydi.
- 38 ta test (`npm test`) + uchidan-uchiga tekshirildi

---

## 2-bosqich — Ertalabki bitta xabar

Har kuni soat 8:00 da kunning rejasi. `state` ichida hamma ma'lumot (`budgets`,
`recurring`, `debts`, `goals`) bor, lekin hozir ishlatilmaydi.

```
☀️ 11-oktabr

💵 Qoldiq: 3 450 000
📊 Oyning 11-kuni — byudjetdan 62% sarflandi
✅ Bugun sarflash mumkin: ~85 000

⚠️ Ertaga: Ijara 2 000 000
🤝 Jasurga qarz muddati 3 kundan keyin
```

**Nega:** "bugun qancha sarflasam bo'ladi" — oddiy hisob (qolgan byudjet ÷ qolgan kun),
lekin kundalik qaror qabul qilishga eng ko'p yordam beradigan raqam.

**Qanday:** `wrangler.toml` ga ikkinchi cron (`0 3 * * *` = 08:00 Toshkent).
`budgetSpent()` logikasini ilovadan Worker'ga ko'chirish kerak.

---

## 3-bosqich — Bank SMS/bildirishnomasini forward qilish

Click/Payme/Uzcard bildirishnomasini botga forward qilasiz → bot summani va savdo
nuqtasini ajratib oladi → kategoriya tugmalarini beradi.

**Nega:** formatlar bir xil bo'lgani uchun parsing ishonchli; qo'lda summa yozishdan
ham tez. Bir marta "Korzinka → Xarid" deb belgilasangiz, bot eslab qoladi va keyingi
safar o'zi to'g'ri kategoriyani taklif qiladi.

**Qanday:** `update.message.forward_origin` bor xabarlarni alohida ishlash.
Savdo nuqtasi → kategoriya moslashuvi KV'da `merchants: {korzinka: 'Xarid'}` sifatida
saqlanadi va har tasdiqdan keyin o'rganib boradi.

---

## 4-bosqich — Proaktiv eslatmalar

Har biri uchun yoqib-o'chirish kerak: `state.notify = {budget:true, daily:false, ...}`.

| Eslatma | Manba | Izoh |
|---|---|---|
| **Byudjet oshdi** | `state.budgets` | 80% va 100% da. Oyning 20-kunida bilish, oy oxirida bilishdan ancha foydali |
| **Takrorlanuvchi to'lov** | `state.recurring` | Muddat kuni `Ijara 2 000 000 to'landimi?` → ✅ Ha / ⏭ Keyinroq |
| **Qarz muddati** | `state.debts` | Muddatdan 3 kun oldin |
| **Kechqurun eslatma** | `state.tx` | Faqat bugun hech narsa kiritilmagan bo'lsa |
| **Haftalik jamlanma** | `state.tx` | Yakshanba kechasi |
| **Maqsad bosqichi** | `state.goals` | 25/50/75/100% ga yetganda |
| **Oy oxiri baholash** | `state.wishlist` | `.github/workflows/rate-reminder.yml` dan Worker'ga ko'chirish |

**Takrorlanuvchi to'lov haqida alohida:** hozir ilova `state.recurring` dan avtomatik
tranzaksiya yaratadi ([`docs/index.html`](../docs/index.html) — `runRecurring()`),
to'lanmagan bo'lsa ham. Tugma bilan tasdiqlash ma'lumotni haqiqatga mos qiladi.

**GitHub Actions'ni o'chirish:** `rate-reminder.yml` da `TELEGRAM_CHAT_ID` secret'ga
qotib qolgan — KV'da foydalanuvchi bo'lsa ham unga bormaydi. Ikki xil infratuzilma bir
ishni qiladi; Worker cron'ga ko'chirilgandan keyin workflow butunlay o'chiriladi.

---

## 5-bosqich — Zaxira va hisobotni boyitish

### Telegram'ni bepul zaxira joyi qilish

Har oy 1-sanada hisobot bilan birga to'liq JSON zaxirani `sendDocument` orqali
o'zingizga yuborish. Saqlangan xabarlarda cheksiz, bepul, abadiy tarix. KV yoki
brauzer ma'lumoti yo'qolsa — oxirgi 12 oylik zaxira Telegram'da turadi.

### Grafik rasm

QuickChart.io'ga URL yasab `sendPhoto` — kategoriya diagrammasi. Matn ro'yxatidan
ko'ra bir ko'rishda tushunarli.

### Oylar taqqoslashi

"Ovqatga o'tgan oydan 23% ko'p sarfladingiz" — `rec.months` da 3 oy saqlanadi,
taqqoslash uchun tayyor.

### Anomaliya aniqlash

O'rtachadan keskin chiqqan 2-3 xarajatni ajratib ko'rsatish.

### Xabarni bo'lish

Hozir hisobot 3900 belgida kesiladi (`buildReport`) — bir nechta xabarga bo'lish kerak.

---

## 6-bosqich — Tezkor so'rovlar

- `/qidir taksi` — oxirgi 10 ta taksi xarajati, jami summa bilan
- `/qarz` — aktiv qarzlar ro'yxati
- `/bugun`, `/hafta` — qisqa jamlanma
- `inline_query` — boshqa chatda `@bot balans` yozib ulashish

**Texnik eslatma:** tranzaksiya darajasida tez-tez so'rov kerak bo'lsa (`/qidir`,
anomaliya) KV'dan **D1**'ga o'tish ma'noli bo'ladi. Hozir butun `state` bitta JSON
blob — filtrlash uchun hammasini o'qish kerak. Bitta foydalanuvchi uchun bu hali
muammo emas, lekin shu bosqichda qayta ko'rib chiqish kerak.

---

## Uzoqroq g'oyalar (tashqi xizmat kerak, pullik)

- **Ovozli xabar** → matn → tranzaksiya (STT API)
- **Chek rasmi** → OCR → summa va savdo nuqtasi

---

## Ataylab qilinmaydigan narsalar

Bitta odam ishlatgani uchun quyidagilar keraksiz — keyinroq "nega qilinmagan" degan
savol tug'ilmasligi uchun yozib qo'yilgan:

| Nima | Nega keraksiz |
|---|---|
| Oilaviy/guruh byudjet, umumiy xarajatni bo'lish | Bitta foydalanuvchi |
| Har foydalanuvchi uchun alohida sozlamalar | Bitta yozuv |
| "O'lik chat" tozalash (403 → yozuvni o'chirish) | Bot egasi hech qachon o'zini bloklamaydi |
| CORS'ni origin bo'yicha cheklash | `initData` imzosi yetarli himoya |
| Rate limiting | Hujum yuzasi yo'q — webhook secret va ega tekshiruvi bor |
| Cron'ni `Promise.allSettled` bilan parallellashtirish | Bitta yozuv; `try/catch` izolyatsiyasi yetarli |
| KV → D1 ko'chirish (hozir) | Bitta JSON blob o'qish tez; 6-bosqichda qayta ko'riladi |

---

## Tavsiya etilgan tartib

1. ✅ ~~Webhook + matn orqali kirim~~ — bajarildi
2. **Ertalabki xabar** — eng ko'p kundalik foyda
3. **Bank SMS forward** — kirishni yana tezlashtiradi
4. **Byudjet + takrorlanuvchi to'lov eslatmalari** → GitHub Actions'ni o'chirish
5. **Zaxira va grafik**
6. **Tezkor so'rovlar** (+ D1 masalasini qayta ko'rish)
