# FinanceApp — Premium Personal Finance (iOS)

SwiftUI + SwiftData + MVVM asosidagi, Apple HIG uslubidagi, oflayn-birinchi shaxsiy moliya ilovasi.

## Talablar
- Xcode 15+ (iOS 17 SDK)
- iOS 17.0+ (SwiftData, `@Observable`, Swift Charts)
- macOS (build/run uchun — Windows'da faqat kod tahrirlanadi)

## Ishga tushirish
Kod Windows'da yozilgan, shuning uchun `.xcodeproj` mavjud emas. **Build/run faqat macOS'da.**

### A) Bepul Apple ID bilan telefonda (eng oson, tavsiya)
App Group / CloudKit / Push / Widget'siz "lite" build — bular pullik hisob talab qiladi.
Face ID, bildirishnomalar, kamera/foto, eksport, Siri, barcha ekranlar ishlaydi.

```bash
brew install xcodegen
cd ios
xcodegen generate --spec project-free.yml
open FinanceApp.xcodeproj
```

So'ng Xcode'da:
1. Chapdagi ro'yxatdan **FinanceApp** target → **Signing & Capabilities**.
2. **Team** → o'z **Apple ID**ingizni qo'shing (Xcode → Settings → Accounts → "+").
3. **Bundle Identifier**ni o'zgartiring (band bo'lsa), masalan `com.ismingiz.finance`.
4. iPhone'ni USB bilan ulang → telefonda **"Ishonish"** (Trust).
5. Yuqoridan qurilma sifatida **iPhone'ingizni** tanlang → **▶︎ Run** (`Cmd+R`).
6. Telefon: **Sozlamalar → Umumiy → VPN va Qurilma boshqaruvi** → sertifikatga **ishonch** bildiring → ilovani oching.

> ⚠️ Bepul hisobda sertifikat **7 kunda** tugaydi — shunda Xcode'dan qayta Run bosing.
> Kamera faqat real qurilmada; Face ID'ni telefon Sozlamalarida yoqib qo'ying.

### B) To'liq versiya (pullik Developer hisobi $99/yil)
Widget, iCloud sync, Push bilan:

```bash
xcodegen generate   # asosiy project.yml
open FinanceApp.xcodeproj
```

Ikkala target (App + Widget)da App Groups + iCloud (CloudKit) yoqilishi kerak (entitlements
project.yml'da tayyor). Apple Developer'da `iCloud.com.ruzmat.finance` konteynerini yarating.

### C) Faqat ko'rish uchun — Simulator (telefon/imzo shart emas)
Xcode'da qurilma o'rniga "iPhone 15 Simulator" tanlab Run bosing (`project-free.yml` bilan).

## Arxitektura (nega shunday?)
- **SwiftData `@Model`** — CloudKit-ready. Barcha propertylar default qiymatli, relationshiplar `inverse` bilan. Kelajakda `ModelConfiguration(..., cloudKitDatabase: .automatic)` qoʻshilsa sync yoqiladi (`PersistenceController.swift`).
- **MVVM + `@Observable`** — View "yupqa", biznes-logika ViewModel'da (masalan `DashboardViewModel`).
- **Repository Pattern** (`FinanceRepositoryProtocol`) — SwiftData bilan yagona muloqot nuqtasi, testda mock qilinadi (Dependency Inversion).
- **DI** — `AppContainer` `Environment` orqali servislarni tarqatadi.
- **Theme tokenlari** (`Theme.swift`) — rang/spacing/typografiya markazlashtirilgan (DRY, izchil premium UI).

## Papka tuzilishi
```
FinanceApp/
├── App/            FinanceApp entry, AppContainer (DI), AppSettings (UserDefaults)
├── Models/         SwiftData modellar + Enums
├── Persistence/    ModelContainer, default kategoriyalar seeding, SampleData
├── Repositories/   Repository protocol + SwiftData implementatsiya
├── Theme/          Dizayn tokenlari
├── Extensions/     Color(hex), Date, Calendar
├── Utilities/      CurrencyFormatter, NLParser, RecurringEngine, CSVExporter, Haptics
├── Components/     Qayta ishlatiluvchi UI (kartochka, ProgressRing, TransactionRow...)
├── Navigation/     RootTabView
└── Features/       Dashboard, Transactions, Categories, Accounts, Budgets,
                    Goals, Recurring, Reports, Calendar, Statistics, Settings, Onboarding
FinanceAppTests/    Sof biznes-logika testlari (parser, filter)
```

## Amalga oshirilgan asosiy imkoniyatlar
Dashboard (balans, statistika, trend chart, byudjet, yaqin toʻlovlar) · Tranzaksiyalar
(qoʻshish/tahrirlash/oʻchirish/nusxa, qidiruv, filtr, saralash, swipe, undo, sevimli) ·
AI tabiiy til parser · Kategoriyalar (ikonka/rang) · Hisoblar · Byudjetlar (prognoz+ogohlantirish) ·
Maqsadlar (animatsion progress) · Takrorlanuvchi toʻlovlar (avtomatik yaratish) · Hisobotlar
(pie/line/bar) · Kalendar · Statistika (heatmap, taqqoslash) · Sozlamalar (tema/valyuta/xavfsizlik) ·
CSV eksport · Onboarding · Empty states · Haptika.

## Widgets & Siri Shortcuts (qoʻshildi)
**App Group** `group.com.ruzmat.finance` orqali ilova, Widget va Intents bitta SwiftData
bazasini ulashadi (`AppGroup.swift`, `PersistenceController.shared`). Widget/Intent DI'ga
bogʻlanmaydi — yengil `FinanceStore` qatlami orqali ishlaydi (jarayonlar ajratilgan).

**Widgetlar** (`FinanceWidget/`):
- **Bugungi sarf** — bugungi jami xarajat (small/medium)
- **Qolgan byudjet** — asosiy byudjet progress halqasi bilan (small/medium)
- **Tez qoʻshish** — bosilsa `financeapp://add` deep-link orqali ilovada Quick Add oynasi ochiladi
- **Tez xarajat (interaktiv)** — iOS 17 `Button(intent:)` bilan preset tugmalar (Kofe/Taksi/Ovqat/Transport);
  bosilsa **ilovani ochmasdan** fon rejimida xarajat yoziladi (`QuickExpenseIntent`, `Shared/`da).
  Yuqorida bugungi sarf koʻrsatiladi va yozgandan soʻng avtomatik yangilanadi.

**Siri Shortcuts / App Intents** (`FinanceApp/Intents/`):
- `AddExpenseIntent` — "50000 food xarajat qoʻsh"
- `QuickLogIntent` — erkin matn ("Taxi 35000") NL parser orqali
- `ShowMonthSpendingIntent` — "bu oygi xarajatim"
- `FinanceShortcuts` iboralarni avtomatik eksport qiladi ("Hey Siri, ...")

> Eslatma: App Group va URL sxemasi `project.yml`dagi entitlements/info orqali generatsiya
> qilinadi. Real qurilmada test uchun Apple Developer hisobida App Group ID roʻyxatga olinishi kerak.

## Xavfsizlik & Bildirishnomalar (qoʻshildi)
**Face ID / App Lock** (`FinanceApp/Security/`):
- `AuthenticationManager` — `LocalAuthentication` (Face ID / Touch ID / qurilma paroli).
- Ilova **fon**ga oʻtganda qulflanadi (`scenePhase`), app-switcher'da kontent blur bilan yashiriladi.
- `LockScreenView` avtomatik biometriya soʻraydi; sozlamalardan yoqiladi.

**Lokal bildirishnomalar** (`FinanceApp/Notifications/`, `UNUserNotificationCenter`):
- Kunlik xarajat eslatmasi (vaqti sozlanadi) · Oylik hisobot eslatmasi ·
  Takrorlanuvchi toʻlov eslatmalari (`nextDueDate`ga bogʻliq) · **Byudjet ogohlantirishi**.
- `NotificationManager.syncSchedules` — **idempotent** (dublikatsiz qayta ekadi).
- `BudgetAlertService` — xarajat qoʻshilganda ostona (masalan 80%) buzilsa ogohlantiradi;
  har davr uchun bir marta (holat App Group UserDefaults'da).

## Eksport: CSV / Excel / PDF (qoʻshildi)
`FinanceApp/Utilities/Export/` — bogʻliqliksiz (SPM/backend'siz):
- **CSV** — `CSVExporter`
- **Excel (.xlsx)** — `XLSXExporter` haqiqiy OOXML yasaydi; `ZipArchive` minimal STORE ZIP writer
  + `CRC32` (Foundation'da zip API yoʻq). Excel/Numbers ochadi.
- **PDF** — `PDFExporter` `UIGraphicsPDFRenderer` bilan **sahifalanadigan** jadval (sarlavha,
  jamlanma qutisi, ustunlar, avtomatik page-break).
- `ExportManager` (Facade): `[Transaction] -> ExportData -> format -> URL`; `ShareSheet`
  (`UIActivityViewController`) orqali ulashiladi. Hisobotlar **va** Tranzaksiyalar ekranida.
- Testlar: `ExportTests` (CSV kontenti, `.xlsx` ZIP imzosi "PK", PDF "%PDF", CRC-32 known-value).

## iCloud (CloudKit) sinxronizatsiya (qoʻshildi)
`ModelConfiguration(..., cloudKitDatabase: .private("iCloud.com.ruzmat.finance"))` orqali
SwiftData store CloudKit'ga ulanadi (App Group konteynerida saqlanadi).

**Modellar CloudKit-mos qilindi:** CloudKit **barcha relationshiplar inverse'ga ega** boʻlishini
talab qiladi. Yetishmayotgan inverse'lar qoʻshildi:
`Account.incomingTransfers` / `recurringRules`, `Category.recurringRules` / `budgets`,
`RecurringTransaction.generatedTransactions`. (Bonus: `incomingTransfers` transfer balansini ham toʻgʻriladi.)

**Boshqaruv:** Sozlamalar → "iCloud sinxronizatsiya" toggle (App Group defaults'da saqlanadi,
oʻzgarish qayta ishga tushirishda kuchga kiradi). `CloudSyncMonitor`
(`NSPersistentCloudKitContainer.eventChangedNotification`) sync holatini koʻrsatadi.

**Xcode/Developer sozlash (macOS'da, real sync uchun):**
1. Apple Developer'da `iCloud.com.ruzmat.finance` CloudKit konteynerini yarating.
2. Ikkala target (App + Widget) "Signing & Capabilities"da: **iCloud → CloudKit** +
   **App Groups** yoqilgan boʻlsin (project.yml entitlements buni generatsiya qiladi).
3. App target'da **Background Modes → Remote notifications** (Info.plist'da bor) va **Push Notifications**.
4. Simulyator/qurilma iCloud hisobiga kirgan boʻlishi kerak.

> Eslatma (optimizatsiya): hozir widget ham CloudKit konteyneridan oʻqiydi. Widgetning qatʼiy
> resurs limiti sababli, ishlab chiqarishda widgetni **local-only** (`cloudKitDatabase: .none`,
> ayni App Group fayli) qilib oʻqitish mumkin — maʼlumot baribir lokal faylda mavjud.

## Chek rasmi (PhotosPicker + kamera) (qoʻshildi)
- `ReceiptPicker` — kutubxona (`PhotosPicker`) yoki kamera (`CameraPicker` = `UIImagePickerController`).
- `ImageProcessor` — saqlashdan oldin **downscale (≤1600px) + JPEG siqish (0.7)** — baza/CloudKit hajmini kamaytiradi.
- `Transaction.receiptImage` (`@Attribute(.externalStorage)`) + yengil `hasReceipt: Bool` bayrogʻi —
  roʻyxatda blob'ni yuklamasdan chek borligini bilish (performance). Qatorlarda 📎 belgisi.
- `ReceiptViewer` — toʻliq ekranli zoom/surish; AddTransactionView'da "Chek rasmi" boʻlimi.
- Chek komponentlari PhotosUI/kamera ishlatgani uchun widget target'idan `excludes` bilan chiqarilgan.

## Telegram Bot integratsiyasi & Haftalik avtomatlashtirish (qoʻshildi)
Ilova hech qanday oraliq backend'siz toʻgʻridan-toʻgʻri **Telegram Bot API** bilan ishlaydi:
- `TelegramService` — `sendMessage` (HTML formatlangan sarf-xarajatlar statistikasi) va `sendDocument` (PDF yoki Excel hisobot biriktirmasi).
- `TelegramSettingsView` — Bot Token, Chat ID kiritish, ulanishni sinash ("Ulanishni tekshirish") va hozir hisobot yuborish.
- `SendWeeklyReportIntent` — iOS Shortcuts / Siri orqali fonda ishga tushadigan `AppIntent`.

**Har hafta avtomatik yuborishni sozlash (iPhone'da 1 daqiqada):**
1. Telegram'da `@BotFather` orqali bot ochib, **Token**ni va `@userinfobot`dan **Chat ID**ni oling.
2. Ilova ichida **Sozlamalar ➔ Telegram Bot hisoboti**ga kirib maʼlumotlarni kiriting va **"Ulanishni tekshirish"** tugmasini bosing.
3. iPhone **"Buyruqlar" (Shortcuts)** ilovasini oching ➔ **"Avtomatlashtirish" (Automation)** ➔ **"+"** bosing.
4. **"Kun vaqti" (Time of Day)**: masalan, *Har dushanba 09:00* ➔ Harakat: *"FinanceApp haftalik hisoboti"* ➔ *"Darhol ishga tushirish"* (Run immediately).
5. Natijada har dushanba ertalab telefoningiz avtomatik tarzda Telegram chatingizga PDF/Excel hisobot va xulosani tashlab beradi!

## Oy oxiri baholash eslatmasi (Mini App + bot)

`docs/index.html` (Telegram Mini App) ichida **⭐ Baholash** tabi bor: rejadan olingan
xaridlarga 1–5 yulduz qoʻyiladi. Oyning oxirgi kunidan **bir kun oldin** va oxirgi kuni
ilovada banner chiqadi.

Ilova faqat ochilganda ishlaydi, shuning uchun **botdan lichkaga eslatma** alohida
GitHub Actions cron orqali yuboriladi: `.github/workflows/rate-reminder.yml`
(har kuni 20:00 Toshkent vaqti tekshiradi, ertaga oy oxiri boʻlsa xabar yuboradi).

**Sozlash (GitHub → Settings → Secrets and variables → Actions):**

| Turi | Nomi | Qiymati |
|---|---|---|
| Secret | `TELEGRAM_BOT_TOKEN` | @BotFather bergan token |
| Secret | `TELEGRAM_CHAT_ID` | Shaxsiy chat ID |
| Secret yoki Variable | `MINIAPP_URL` | (ixtiyoriy) Mini App manzili: `https://ruzmatjs.github.io/finance-ios/` |

Chat ID ni olish: botga bir marta yozing, soʻng brauzerda oching —
`https://api.telegram.org/bot<TOKEN>/getUpdates` → `message.chat.id`.

Tekshirish: **Actions → "Oy oxiri baholash eslatmasi" → Run workflow** → `force` ✓
(sanadan qatʼiy nazar darhol yuboradi).

> ⚠️ Cron GitHub'da 5–20 daqiqa kechikishi mumkin. Repoda 60 kun hech qanday
> faollik boʻlmasa, GitHub rejalashtirilgan workflow'larni avtomatik oʻchiradi.
> Xabar matni umumiy — nechta xarid baholanmaganini bot bilmaydi, chunki maʼlumot
> Telegram CloudStorage'da (faqat Mini App ichida) saqlanadi.

## Mini App versiyasi va Telegram keshi

Telegram mobil mijozi Mini App'ni keshlaydi — GitHub Pages'ga yangi kod chiqsa ham telefonda
bir necha kun **eski versiya** ochilib yurishi mumkin (desktop Telegram esa yangisini oladi).
Shu sababli ilova ochilgach serverdagi faylning birinchi kilobaytini olib (HTTP `Range`,
butun fayl emas) oʻzining versiyasini tekshiradi va eskiligi bilinsa pastda
**“Yangi versiya tayyor → Yangilash”** tugmasini chiqaradi. Tugma `?v=<versiya>` bilan
qayta yuklaydi — bu keshni chetlab oʻtadi.

> ⚠️ **`docs/index.html` ni oʻzgartirgach `<meta name="app-version">` sanasini yangilang** —
> ilova eski kesh ochilganini aynan shundan biladi.

Qoʻlda yangilash har doim mumkin: **Sozlamalar → 🔄 Ilovani yangilash (Keshni tozalash)**.
Ochilgan versiya sana koʻrinishida Sozlamalar sahifasining eng pastida yoziladi.

## Oylarni taqqoslash (Mini App)

**Hisobot → Oylarni taqqoslash** sahifasi tanlangan oyni undan oldingi oy bilan yonma-yon
koʻrsatadi:

- **Xarajat / Daromad / Sof natija** — har biri ikkita gorizontal ustun (oʻtgan oy kulrang,
  bu oy rangli) va foiz oʻzgarishi chipi bilan.
- **Kun boʻyicha jamlangan chiziq grafik** — ikki oyning kumulyativ sarfi bitta oʻqda.
  Chiziq tikroq boʻlsa — shu oy tezroq sarflanayotgani darhol koʻrinadi.
- **Kategoriyalar farqi** — markazdan ikki yonga ketadigan ustunlar: nima oshdi, nima kamaydi.
- **Qisqa xulosa** — oddiy tilda, shu tezlikda oy oxirida qancha boʻlishi prognozi bilan.

Joriy oy hali tugamagani uchun standart holatda **teng kunlar** rejimi yoqiladi: ikki oy ham
faqat bugungi kun raqamiga qadar olinadi (masalan 1–11), aks holda tugamagan oy har doim
“kamroq sarflandi” koʻrinib qolardi. **Butun oy** tugmasi bilan toʻliq oyga oʻtiladi.
Qarz tranzaksiyalari hisobga olinmaydi.

## Telegram bot (Mini App + Cloudflare Worker)

Bot tokenini ochiq `docs/index.html` ichiga yozib boʻlmaydi, maʼlumot esa Telegram
CloudStorage'da (faqat Mini App ichida) turadi — shuning uchun oradagi boʻgʻin kichik
**Cloudflare Worker** (`worker/`). Bot tokeni faqat Cloudflare secret sifatida saqlanadi.

### Matn orqali kirim

Ilovani ochmasdan, botga shunchaki yozasiz:

```
ovqat 25k           →  Ovqat · −25 000 · Naqd
benzin 120k karta   →  Yoqilgʼi · −120 000 · Bank karta
+5mln maosh         →  Maosh · +5 000 000
onamga 200k         →  Uydagilar · −200 000
```

Summa `25000` / `25k` / `25 ming` / `1.5mln` koʻrinishida; soʻz tartibi muhim emas;
`ovqatga`, `taksiga`, `maoshim` kabi **qoʻshimchali** shakllar ham tushuniladi.
Kalit soʻzlar jadvali Mini App'dagi `KW` bilan bir xil. Har yozuvdan keyin
**✏️ Kategoriya** va **❌ Bekor** tugmalari chiqadi.

Buyruqlar: `/bugun` · `/balans` · `/oy` · `/hisobot` · `/bekor` · `/ertalab` · `/eslatma` · `/help`

Bot state'ni oʻzgartirmaydi — yozuvlarni KV'dagi **append-only** `pending[]` ga qoʻshadi.
Mini App `/pull` bilan oladi, mavjud `mergeStates()` orqali birlashtiradi va
`ackPending` bilan tasdiqlaydi. Ilova ochiq boʻlsa yozuv ~25 soniyada oʻzi koʻrinadi.

### Ertalabki xabar

Har kuni 08:00 (Toshkent) da kunning rejasi keladi:

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

**Bugun sarflash mumkin** — qolgan byudjet ÷ oy oxirigacha qolgan kun. Byudjet
boʻlmasa kunlik oʻrtacha va oy oxiri prognozi koʻrsatiladi. Byudjetning 80% i
sarflanganda (🟡) va oshib ketganda (🔴) ogohlantiradi; yaqinlashgan
takrorlanuvchi toʻlovlar va qarz muddatlari ham shu xabarda.

`/bugun` — istalgan paytda koʻrish. `/ertalab` — yoqish/oʻchirish.

### Reja sanasi eslatmasi

**Rejalar** boʻlimida har bir xaridga ixtiyoriy sana qoʻyish mumkin. Shu sanaga bir kun
qolganda ertalab 09:00 (Toshkent) da lichkaga eslatma keladi:

```
🛍️ Ertaga rejadagi xarid

• iPhone 16 — 1 200 000 soʻm (Texnika)
   📝 Doʻkon: Mediapark

💵 Qoldiq: 2 000 000 soʻm
```

Jami summa qoldiqdan oshsa ogohlantiradi. `/eslatma` — yoqish/oʻchirish.

### Oylik hisobot

Har oyning 1-sanasi 10:00 (Toshkent) da bot lichkaga **oʻtgan oy hisobotini** yuboradi:
daromad, xarajat, qoldiq va toʻliq kategoriya taqsimoti. Mini App har saqlashda oxirgi
3 oy jamlanmasini Worker'ga yuboradi (`POST /sync`), Worker uni KV'da saqlaydi va
cron (`0 5 1 * *`) boʻyicha xabar tashlaydi.

### Xavfsizlik

- Mini App soʻrovlari Telegram `initData` imzosi bilan tekshiriladi; chat ID imzolangan
  maʼlumotdan olinadi — birovning nomidan yuborib boʻlmaydi
- Webhook `X-Telegram-Bot-Api-Secret-Token` sarlavhasi bilan himoyalangan
- Bot faqat egasiga javob beradi (`OWNER_ID` yoki birinchi `/start` yozgan chat)

Oʻrnatish qoʻllanmasi va testlar: [`worker/README.md`](worker/README.md).
Ulash: ilovada **Sozlama → 📊 Telegram oylik hisobot** → Worker manzilini kiriting.

## Keyingi bosqich (TODO)
- Custom passcode (qurilma paroli oʻrniga ilova ichidagi PIN).
- CloudKit share (oila/hamkor bilan umumiy byudjet).
- OCR — chek rasmidan summa/sana avtomatik oʻqish (VisionKit).
- Widget presetlarini foydalanuvchi sozlashi (`AppIntentConfiguration` — configurable widget).

```
