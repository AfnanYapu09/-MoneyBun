# MoneyBun 🐰

แอปจดรายรับ-รายจ่ายส่วนตัวสำหรับคนไทย ที่อ่าน **สลิปธนาคารไทย/ทรูมันนี่** อัตโนมัติจากรูปในมือถือ
ผู้ใช้แค่กดเลือกหมวดหมู่ ดีไซน์เป็น **พิกเซลอาร์ต โทนส้ม/ขาว/เทา** มีมาสคอต **"น้องบัน" (Bun)**

A pixel-art Thai personal finance app. Reads Thai bank / TrueMoney slips automatically
(hybrid QR + on-device OCR, with an optional online verify API), local-first with cloud sync.

## ฟีเจอร์ (Features)

- 🏠 **หน้าหลัก** — รายการรายวัน เลื่อนดูทั้งเดือน + สรุปรายรับ/รายจ่าย/ยอดคงเหลือ
- ➕ **เพิ่มรายการ** — รายรับ / รายจ่าย / ย้ายเงินระหว่างบัญชี + เลือกหมวดหมู่
- 🧾 **อ่านสลิป (Hybrid)** — สแกน QR (EMVCo TLV) + OCR ในเครื่อง (ML Kit) ดึงจำนวนเงิน/วันที่/อ้างอิง
  แบบออฟไลน์ และมีตัวเลือกตรวจสอบออนไลน์ (EasySlip/SlipOK) ผ่าน Cloud Function
- 💳 **บัญชี** — กระเป๋าเงินสด/ธนาคาร/ทรูมันนี่ พร้อมยอดคงเหลือคำนวณอัตโนมัติ
- 📊 **สถิติ** — สรุปเดือน + สัดส่วนตามหมวดหมู่
- ☁️ **Local-first + Sync** — ใช้งานออฟไลน์ได้เต็มที่ (Drift) และซิงค์ขึ้น Firebase เมื่อล็อกอิน Google
- 🌏 ไทย/อังกฤษ, รองรับ พ.ศ.

## สถาปัตยกรรม (Tech)

Flutter • Riverpod • Drift (SQLite, source of truth) • go_router • Firebase (Auth/Firestore/Functions) •
ML Kit Text Recognition (Latin) • mobile_scanner • Cloud Functions (TypeScript)

```
lib/
  core/        theme (pixel design system), widgets, router, utils, constants
  data/        local/ (Drift db + tables), remote/ (auth, sync, mappers), repositories/
  domain/      entities, enums
  features/    home, add_transaction, accounts, stats, settings, slip
  bootstrap/   providers (Riverpod), firebase_options (placeholder)
functions/     Cloud Functions: verifySlip proxy (TypeScript)
```

## เริ่มพัฒนา (Run locally)

```bash
flutter pub get
flutter gen-l10n                 # generate localizations
dart run build_runner build      # generate Drift code (database.g.dart)
flutter run                      # Android device/emulator
flutter test                     # 27 unit tests (TLV/CRC, OCR extract, balances, ...)
```

> หมายเหตุ: ไฟล์ที่ถูกสร้างอัตโนมัติ (`*.g.dart`, `lib/l10n/generated/`) ไม่ได้ commit ไว้ —
> ต้องรัน `build_runner` + `gen-l10n` ก่อน (CI ทำให้อัตโนมัติ)

## ตั้งค่า Firebase (จำเป็นสำหรับ Sync + ตรวจสลิปออนไลน์)

แอป **ทำงานออฟไลน์ได้โดยไม่ต้องมี Firebase** ส่วนนี้เปิดการซิงค์/ล็อกอิน/ตรวจสลิปออนไลน์:

1. สร้างโปรเจกต์ใน [Firebase Console](https://console.firebase.google.com) เปิด **Authentication (Google)**
   และ **Cloud Firestore**
2. ตั้งค่าแอป Flutter:
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure          # เขียนทับ lib/bootstrap/firebase_options.dart
   ```
   เมื่อค่าไม่ใช่ placeholder แล้ว แอปจะ init Firebase และเปิดเมนูล็อกอินให้เอง
3. Deploy Cloud Function ตรวจสลิป:
   ```bash
   cd functions && npm install
   firebase functions:secrets:set EASYSLIP_TOKEN   # ใส่ API key ของ EasySlip/SlipOK
   firebase deploy --only functions
   ```
   เปิดสวิตช์ "ใช้ API ตรวจสลิปออนไลน์" ในหน้าตั้งค่าของแอป

> Bundle id: `com.moneybun.moneybun` (เปลี่ยนใน `android/app/build.gradle.kts` ก่อนตั้ง Firebase ถ้าต้องการ)

## CI

GitHub Actions (`.github/workflows/ci.yml`): `pub get` → `gen-l10n` → `build_runner` →
`dart format` check → `flutter analyze` → `flutter test` → `flutter build apk --debug` (artifact) ·
และ typecheck Cloud Functions (`tsc`).

## ข้อจำกัดที่ทราบ

- ML Kit OCR **ไม่อ่านอักษรไทย** → ดึงจำนวนเงิน/วันที่/อ้างอิงได้ออฟไลน์ แต่ชื่อผู้ส่ง/ผู้รับต้องใช้ API ตรวจสลิป
- การ map ผลลัพธ์จาก EasySlip ใน `functions/src/index.ts` เขียนแบบ defensive — อาจต้องปรับ field ตาม plan ของผู้ให้บริการ
- Sync conflict ใช้ last-write-wins (เหมาะกับผู้ใช้คนเดียวหลายเครื่อง)
- งบประมาณ/เปรียบเทียบเดือน: โครงข้อมูลรองรับแล้ว (ตาราง budgets) แต่ยังไม่ต่อ UI

## เดโมเว็บ (GitHub Pages)

แอปรันบนเว็บได้ (Flutter web + drift wasm + ฟอนต์ bundle) workflow `.github/workflows/deploy-web.yml`
จะ build + deploy ขึ้น GitHub Pages อัตโนมัติเมื่อ push เข้า `main`

เปิดใช้งานครั้งเดียว:
1. Merge เข้า `main`
2. เปลี่ยน repo เป็น **public** (Settings → General → Change visibility) — ⚠️ GitHub Pages ใช้กับ repo private ไม่ได้ถ้าเป็นแพ็กเกจฟรี (ต้อง public หรือ GitHub Pro/Team)
3. เปิด Pages: **Settings → Pages → Build and deployment → Source: GitHub Actions**
4. รอ workflow **Deploy Web** เสร็จ (~2 นาที) → เปิด `https://afnanyapu09.github.io/-MoneyBun/`

> ทางเลือกฟรีถ้าอยากเก็บ repo เป็น private: ใช้ **Firebase Hosting** (`firebase deploy --only hosting`) แทน
