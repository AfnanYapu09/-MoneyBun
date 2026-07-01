# ตั้งค่า Firebase (Sync + ล็อกอิน) — MoneyBun

> ขั้นตอนเหล่านี้ **ต้องทำบนเครื่องคุณเอง** เพราะผูกกับบัญชี Google / Firebase / billing ของคุณ
> แอปใช้งานออฟไลน์ได้เต็มที่โดยไม่ต้องทำส่วนนี้ — **การอ่านสลิป (จำนวนเงิน) ทำบนเครื่องล้วน
> ไม่ต้องต่อเน็ต** ทำส่วนนี้เฉพาะเมื่ออยากเปิด **sync ข้ามเครื่อง + ล็อกอิน**

ทุกอย่างฝั่งโค้ดเตรียมไว้ให้แล้ว: `firebase.json`, `firestore.rules` (กันข้อมูลข้ามผู้ใช้),
`firestore.indexes.json`, `.firebaserc` (รอใส่ project id) และโค้ดล็อกอินครบทั้ง
**อีเมล/รหัสผ่าน + Google + Apple** พร้อม sync — เหลือแค่เชื่อมโปรเจกต์ Firebase จริง

---

## เลือกวิธีล็อกอิน — เริ่มจากแบบง่ายสุดก่อน

| วิธี | ต้องทำข้อไหน | ความยาก |
|---|---|---|
| **อีเมล/รหัสผ่าน** ✅ แนะนำให้เริ่มอันนี้ | ข้อ 1 + 2 + เปิด provider "Email/Password" + ข้อ 4 | ง่ายสุด — ไม่ต้องทำ SHA-1 / OAuth client / dart-define |
| **Google** | ทุกข้อ รวม **ข้อ 3** (Web client ID + SHA-1) | ยุ่งกว่า |
| **Apple** | ต้องมี Apple Developer account + ตั้งค่าใน Xcode (เฉพาะ iOS) | ยุ่งสุด |

> อยากให้ "ล็อกอิน + ซิงค์ใช้ได้" เร็วที่สุด → ใช้ **อีเมล/รหัสผ่าน** แล้ว **ข้ามข้อ 3** ไปได้เลย
> (ตอนเปิด Authentication ในข้อ 1 ให้เปิด provider **Email/Password** แทน Google)
> ปุ่ม Google/Apple จะยังอยู่ในแอป แต่ยังไม่ต้องตั้งค่าก็ได้ ค่อยมาเปิดทีหลัง

---

## 0. สิ่งที่ต้องมี

```bash
flutter --version            # มี Flutter อยู่แล้ว
npm install -g firebase-tools
dart pub global activate flutterfire_cli
firebase login               # login ด้วย Google account ของคุณ (เปิดเบราว์เซอร์)
```

## 1. สร้างโปรเจกต์ Firebase

1. ไปที่ https://console.firebase.google.com → **Add project** (จดชื่อ *project id*)
2. **Build → Authentication → Get started → Sign-in method → เปิด provider ที่จะใช้**
   - **Email/Password** ← เปิดอันนี้สำหรับวิธีง่ายสุด
   - **Google** ← เปิดเพิ่มถ้าจะใช้ปุ่ม Google (ต้องทำข้อ 3 ด้วย)
3. **Build → Firestore Database → Create database** (โหมด production ได้ เพราะเรามี rules ให้แล้ว)
4. แก้ `.firebaserc` ในรีโป ใส่ project id:
   ```json
   { "projects": { "default": "your-project-id" } }
   ```

## 2. เชื่อมแอป Flutter กับ Firebase

```bash
flutterfire configure --project=your-project-id
```
- เลือกแพลตฟอร์ม **android** (และ ios ถ้าจะทำ)
- คำสั่งนี้จะ **เขียนทับ** `lib/bootstrap/firebase_options.dart` ด้วยค่าจริง และวาง
  `android/app/google-services.json` + แก้ Gradle ให้อัตโนมัติ
- พอค่าไม่ใช่ placeholder แล้ว แอปจะ init Firebase เองและโชว์เมนู "เข้าสู่ระบบเพื่อซิงค์" ในหน้าตั้งค่า

> หมายเหตุ: `firebase_options.dart` และ `google-services.json` มีค่า config จริง (ไม่ใช่ความลับร้ายแรง
> แต่) — จะ commit หรือไม่ก็ได้ ตอนนี้ `.gitignore` กัน `google-services.json` ตัวจริงไว้

## 3. Google Sign-In บน Android (⚠️ เฉพาะถ้าจะใช้ปุ่ม Google — ใช้อีเมล/รหัสผ่านข้ามข้อนี้ได้)

Firebase ต้องการ **Web client ID** เพื่อรับ ID token จากแอป:

1. เปิด https://console.cloud.google.com/apis/credentials (เลือกโปรเจกต์เดียวกัน)
2. คัดลอก **OAuth 2.0 Client ID** ชนิด **Web client** (มักชื่อ "Web client (auto created by Google Service)")
   รูปแบบ `xxxxx.apps.googleusercontent.com`
3. รัน/บิลด์แอปโดยส่งค่าเข้าไป:
   ```bash
   flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=xxxxx.apps.googleusercontent.com
   ```
4. เพิ่ม **SHA-1 / SHA-256** ของ keystore ลงใน Firebase (Project settings → Your apps → Android → Add fingerprint)
   ```bash
   cd android && ./gradlew signingReport   # ดูค่า SHA1/SHA256 ของ debug
   ```

## 4. Deploy กฎ Firestore

```bash
firebase deploy --only firestore:rules          # อัปกฎความปลอดภัย
```

> ไม่มี Cloud Functions แล้ว — การอ่านสลิป (จำนวนเงิน/วันที่/อ้างอิง) ทำในเครื่อง
> ผ่าน QR + ML Kit (Latin) จึงไม่ต้องเปิด Blaze plan

## 5. เปิดใช้งานในแอป

1. เข้าแอป → **ตั้งค่า → เข้าสู่ระบบเพื่อซิงค์** → จะไปหน้าล็อกอิน
   - **อีเมล/รหัสผ่าน:** กด "สมัครสมาชิก" สร้างบัญชีใหม่ หรือกรอกอีเมล+รหัสผ่านเพื่อเข้าสู่ระบบ
   - **Google/Apple:** กดปุ่มที่เกี่ยวข้อง (ต้องตั้งค่าข้อ 3 ก่อนสำหรับ Google)
2. ล็อกอินสำเร็จ → เริ่ม sync ขึ้น `users/{uid}/...` อัตโนมัติ (กด "ซิงค์ตอนนี้" ในตั้งค่าได้)

## ตรวจสอบ

- ล็อกอินแล้วเพิ่มรายการ → เปิด Firestore console จะเห็น doc ใต้ `users/{uid}/transactions`
- ลองอีกเครื่อง/ลงแอปใหม่แล้วล็อกอินบัญชีเดิม → ข้อมูลถูก pull กลับมา (last-write-wins)

## ปัญหาที่พบบ่อย

| อาการ | สาเหตุ / วิธีแก้ |
|---|---|
| เมนูล็อกอินไม่ขึ้น (โชว์ "ยังไม่ตั้งค่า Firebase") | ยังเป็น placeholder — ยังไม่ได้รัน `flutterfire configure` (ข้อ 2) หรือยังไม่ได้ `flutter pub get` + รันใหม่ |
| สมัคร/ล็อกอินด้วยอีเมลไม่ได้ (`operation-not-allowed`) | ยังไม่ได้เปิด provider **Email/Password** ใน Authentication (ข้อ 1.2) |
| รหัสผ่านสั้นไป (`weak-password`) | Firebase ต้องการรหัสผ่าน ≥ 6 ตัวอักษร |
| ล็อกอิน Google แล้วเด้งออก / token ไม่ผ่าน | ยังไม่ส่ง `--dart-define=GOOGLE_SERVER_CLIENT_ID=...` หรือยังไม่เพิ่ม SHA-1 (ข้อ 3) |
| จำนวนเงินบนสลิปอ่านพลาด | รูปเบลอ/ฟอนต์ตกแต่ง — ลองรูปคมชัดขึ้น (แอปอ่านเฉพาะจำนวนเงินด้วย ML Kit + QR) |
