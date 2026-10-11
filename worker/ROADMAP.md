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

## ✅ 2-bosqich — Ertalabki xabar (bajarildi)

Har kuni 08:00 (Toshkent) da kunning rejasi: qoldiq, oylik sarf, bugun sarflash mumkin
bo'lgan summa, byudjet ogohlantirishlari, yaqinlashgan to'lovlar va qarz muddatlari.

```
☀️ 11-oktabr, yakshanba

💵 Qoldiq: 8 355 000 so'm
📉 Oyda sarflandi: 2 345 000 so'm (11/31 kun)
📊 Byudjetdan 59% sarflandi
✅ Bugun sarflash mumkin: ~78 000 so'm (21 kunga 1 655 000)

🟡 Ovqat — 89% (95 000 qoldi)

⚠️ Bugun: Internet — −60 000 so'm
📅 Ertaga: Ijara — −2 000 000 so'm

🤝 Jasur — 500 000 so'm · 2 kundan keyin
```

- Ikkinchi cron: `0 3 * * *`; `scheduled()` `event.cron` bo'yicha ajratadi
- `budgetSpent()` va davr boshlanishi hisoblari ilovadan Worker'ga ko'chirildi
- **Bugun sarflash mumkin** = qolgan byudjet ÷ oy oxirigacha qolgan kun, minggacha
  pastga yumaloqlangan. Byudjet bo'lmasa — kunlik o'rtacha va oy oxiri prognozi
- Qoplanadigan byudjetlar muammosi: hammasini qamrab oluvchi byudjet (`catIds` bo'sh)
  bo'lsa faqat shu olinadi, aks holda kategoriya byudjetlari bilan ikki marta
  hisoblanib ketardi
- Byudjet ogohlantirishi 80% (🟡) va 100% (🔴) da
- `/bugun` — istalgan paytda ko'rish · `/ertalab` — yoqish/o'chirish (KV'da `morning`)
- **Vaqt mintaqasi:** ilova sanalarni qurilmaning mahalliy vaqtidan ISO'ga aylantirib
  saqlaydi, shuning uchun Worker'da taqqoslashdan oldin Toshkentga suriladi (`toTash`).
  Aks holda 00:00–05:00 orasidagi yozuvlar oldingi kunga tushib ketardi
- 51 ta test qo'shildi (ertalabki xabar + cron dispatch; KV va Telegram mock bilan)

**Yo'l-yo'lakay tuzatildi:** oylik hisobotda `state` bo'lsa saqlangan jamlanma butunlay
e'tiborsiz qolar edi — ilovada eski tranzaksiyalar yo'qolgan bo'lsa hisobot jim
ketmasdi. Endi jonli hisob bo'sh chiqsa saqlangan jamlanmaga qaytadi.

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
| ~~**Byudjet oshdi**~~ | `state.budgets` | ✅ 2-bosqichda ertalabki xabar ichida bajarildi |
| **Takrorlanuvchi to'lov** | `state.recurring` | Muddat kuni `Ijara 2 000 000 to'landimi?` → ✅ Ha / ⏭ Keyinroq |
| ~~**Qarz muddati**~~ | `state.debts` | ✅ 2-bosqichda ertalabki xabar ichida bajarildi |
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
- `/hafta` — haftalik qisqa jamlanma (`/bugun` 2-bosqichda bajarildi)
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
2. ✅ ~~Ertalabki xabar~~ — bajarildi
3. **Bank SMS forward** — kirishni yana tezlashtiradi
4. **Byudjet + takrorlanuvchi to'lov eslatmalari** → GitHub Actions'ni o'chirish
5. **Zaxira va grafik**
6. **Tezkor so'rovlar** (+ D1 masalasini qayta ko'rish)
