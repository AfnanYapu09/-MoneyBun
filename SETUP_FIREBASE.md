# ตั้งค่า Firebase (Sync + ล็อกอิน) — MoneyBun

> ขั้นตอนเหล่านี้ **ต้องทำบนเครื่องคุณเอง** เพราะผูกกับบัญชี Google / Firebase / billing ของคุณ
> แอปใช้งานออฟไลน์ได้เต็มที่โดยไม่ต้องทำส่วนนี้ — **การอ่านสลิป (รวมชื่อ/ธนาคาร) ทำบนเครื่องล้วน
> ไม่ต้องต่อเน็ต** ทำส่วนนี้เฉพาะเมื่ออยากเปิด **sync ข้ามเครื่อง + ล็อกอิน**

ทุกอย่างฝั่งโค้ดเตรียมไว้ให้แล้ว: `firebase.json`, `firestore.rules` (กันข้อมูลข้ามผู้ใช้),
`firestore.indexes.json`, `.firebaserc` (รอใส่ project id)

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
2. **Build → Authentication → Get started → Sign-in method → เปิด Google**
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
- พอค่าไม่ใช่ placeholder แล้ว แอปจะ init Firebase เองและโชว์เมนู "เข้าสู่ระบบด้วย Google"

> หมายเหตุ: `firebase_options.dart` และ `google-services.json` มีค่า config จริง (ไม่ใช่ความลับร้ายแรง
> แต่) — จะ commit หรือไม่ก็ได้ ตอนนี้ `.gitignore` กัน `google-services.json` ตัวจริงไว้

## 3. Google Sign-In บน Android (สำคัญ)

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

1. เข้าแอป → **ตั้งค่า → เข้าสู่ระบบด้วย Google** → จะเริ่ม sync ขึ้น `users/{uid}/...`
2. สแกนสลิปจากอัลบั้มได้เลย — **จำนวนเงิน** ถูกอ่านบนเครื่องอัตโนมัติ (เฉพาะสลิปใหม่ภายใน 7 วันล่าสุด)

## ตรวจสอบ

- ล็อกอินแล้วเพิ่มรายการ → เปิด Firestore console จะเห็น doc ใต้ `users/{uid}/transactions`
- ลองอีกเครื่อง/ลงแอปใหม่แล้วล็อกอินบัญชีเดิม → ข้อมูลถูก pull กลับมา (last-write-wins)

## ปัญหาที่พบบ่อย

| อาการ | สาเหตุ / วิธีแก้ |
|---|---|
| ล็อกอินแล้วเด้งออก / token ไม่ผ่าน | ยังไม่ส่ง `--dart-define=GOOGLE_SERVER_CLIENT_ID=...` หรือยังไม่เพิ่ม SHA-1 |
| จำนวนเงินบนสลิปอ่านพลาด | รูปเบลอ/ฟอนต์ตกแต่ง — ลองรูปคมชัดขึ้น (แอปอ่านเฉพาะจำนวนเงินด้วย ML Kit + QR) |
