# MoneyBun 🐰

แอปจดรายจ่ายส่วนตัวสำหรับคนไทย ที่อ่าน **สลิปธนาคารไทย/ทรูมันนี่** อัตโนมัติจากอัลบั้มรูปในมือถือ
ผู้ใช้แค่กดเลือกหมวดหมู่ ดีไซน์เป็น **พิกเซลอาร์ต โทนส้ม/ขาว/เทา** มีมาสคอต **"น้องบัน" (Bun)** ·
**สำหรับ Android** (สแกนอัลบั้ม + OCR ในเครื่องทำงานเฉพาะบนมือถือ)

A pixel-art Thai expense tracker for **Android**. Auto-reads Thai bank / TrueMoney slips from a
phone gallery album (QR + on-device OCR), local-first with optional cloud sync.

## ฟีเจอร์ (Features)

- 🧾 **สแกนอัลบั้มอัตโนมัติ** — เลือกอัลบั้มที่เก็บสลิป น้องบันอ่านทุกรูปที่ยังไม่เคยอ่าน (กันซ้ำ),
  สแกน QR (EMVCo TLV) + OCR ในเครื่อง (ML Kit) ดึงจำนวนเงิน/วันที่/อ้างอิง และเก็บรูปสลิปไว้ในแอป
- 🏠 **หน้าหลัก** — รายการสลิปจัดกลุ่มตามวัน เลื่อนดูทั้งเดือน + ยอดรวมเดือน · แตะ chip เพื่อ **เลือกหมวดหมู่ต่อสลิป**
- 🗂️ **หมวดหมู่ลิสต์เดียว** — อาหาร/ช้อปปิ้ง/การศึกษา/บ้าน/เดินทาง/สุขภาพ/บันเทิง + **ให้ยืม** + **ย้ายเงิน** + อื่นๆ
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
  features/    home, add_transaction, stats, settings, slip
  bootstrap/   providers (Riverpod), firebase_options (placeholder)
functions/     Cloud Functions: verifySlip proxy (TypeScript)
```

## เริ่มพัฒนา (Run locally)

```bash
flutter pub get
flutter gen-l10n                 # generate localizations
dart run build_runner build      # generate Drift code (database.g.dart)
flutter run                      # Android device/emulator
flutter test                     # unit tests (TLV/CRC, OCR extract, repositories, ...)
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

## ทดสอบบนมือถือ (APK)

แอปนี้ต้องรันบน **Android** จริง (สแกนอัลบั้ม + OCR ทำงานเฉพาะบนเครื่อง) วิธีง่ายสุดคือดาวน์โหลด APK:

1. เปิด workflow **Release APK** (`.github/workflows/release-apk.yml`) — push เข้า `main` แล้วจะ build
   `flutter build apk --release` และแนบไฟล์ขึ้น **GitHub Release tag `latest`** อัตโนมัติ
2. บนมือถือเปิดหน้า [**Releases**](../../releases) → ดาวน์โหลด `app-release.apk`
3. เปิดไฟล์ → อนุญาต "ติดตั้งจากแหล่งที่ไม่รู้จัก" → ติดตั้ง
4. เปิดแอป → กดสแกน → เลือกอัลบั้มที่เก็บสลิป → อ่านอัตโนมัติ → เลือกหมวดหมู่ในหน้าหลัก

> APK นี้เซ็นด้วย debug key สำหรับทดสอบเท่านั้น · ถ้ามี Flutter + สาย USB ใช้ `flutter run` (เปิด USB debugging) แทนได้
