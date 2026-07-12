# รายงานตรวจสอบการซิงค์ข้อมูลคลาวด์ MoneyBun (ทุกมิติ)

**วันที่ตรวจ:** 5 กรกฎาคม 2026 · **ฐานโค้ด:** `main` @ `17f84b8`
**โจทย์จากผู้ใช้:** (1) แก้โปรไฟล์แล้วล็อกอินใหม่ ข้อมูลไม่ถูกบันทึก (2) สลิปที่เคยจดไว้ ล็อกอินใหม่แล้วหาย ไม่แสดง

## วิธีตรวจ

ไล่อ่านเส้นทางข้อมูลทั้งหมดที่เกี่ยวกับคลาวด์: `SyncEngine` (push/pull/LWW/watermark),
`SyncController` (trigger อัตโนมัติ), `FirestoreMappers` (ทุก field ที่ขึ้น/ลงคลาวด์),
`AppDatabase` (ตาราง, `clearAllData`, `hasPendingRows`, tombstone GC),
`SettingsRepository` (`resetUserData`), เส้นทาง sign-in/sign-up/sign-out ทั้ง 3 provider,
slip importer + scanner gate, จุดแสดงผลสลิป (`SlipImage`, slip viewer), firestore.rules,
firebase_options และเอกสารติดตั้ง

---

## สรุปผล: ตารางมิติข้อมูลทั้งแอป — อะไรซิงค์ / อะไรไม่ซิงค์

| ข้อมูล | ก่อนตรวจ | หลังแก้รอบนี้ |
|---|---|---|
| รายการรับ‑จ่าย (transactions + tag links) | ✅ ซิงค์ | ✅ |
| บัญชี/กระเป๋า (accounts) | ✅ ซิงค์ | ✅ |
| หมวดหมู่ (categories) | ✅ ซิงค์ | ✅ |
| สลิป — ข้อมูล (slips: ยอด, ธนาคาร, transRef, assetId, photoTakenAt) | ✅ ซิงค์ | ✅ |
| สลิป — **รูปภาพ** (`imagePath`) | ❌ path ในเครื่อง ถูกล้างตอนออกจากระบบ → สลิปที่ restore กลับมา**แสดงเป็น placeholder ทั้งหมด** | ✅ แก้แล้ว: เปิดรูปจากแกลเลอรีผ่าน `assetId` ที่ซิงค์ไว้ (เครื่องเดิม) |
| งบประมาณ (budgets) | ✅ ซิงค์ | ✅ |
| แท็ก (tags) | ✅ ซิงค์ | ✅ |
| รายการประจำ (recurring rules) | ✅ ซิงค์ | ✅ |
| **โปรไฟล์: ชื่อ, @username, เบอร์โทร** | ❌ **ไม่ซิงค์เลย + ถูกลบตอนออกจากระบบ** | ✅ ซิงค์แล้ว (per‑key, LWW) |
| **เป้าหมายการออม (savingsGoalCents)** | ❌ ไม่ซิงค์ + ถูกลบตอนออกจากระบบ | ✅ ซิงค์แล้ว |
| **ธนาคารที่ปิดสแกน (disabledScanIds)** | ❌ ไม่ซิงค์ + ถูกลบตอนออกจากระบบ | ✅ ซิงค์แล้ว |
| รูปโปรไฟล์ (`avatarPath`) | ❌ ไฟล์ในเครื่อง | ⚠️ ยังไม่ซิงค์ (ต้องใช้ Firebase Storage — ดู "ข้อจำกัดที่เหลือ") |
| ธีม / ภาษา / สกุลเงิน / onboarding | ➖ ตั้งใจให้เป็นค่าประจำเครื่อง (ไม่ถูกล้างตอนออกจากระบบ) | ➖ คงเดิม |
| ประวัติค้นหา, เวลาสแกนล่าสุด, scan cursor, pull watermark | ➖ bookkeeping ประจำเครื่อง | ➖ คงเดิม (ถูกล้างตอนออกจากระบบถูกต้องแล้ว) |

---

## ปัญหาข้อ 1 — แก้โปรไฟล์แล้วล็อกอินใหม่ไม่ถูกบันทึก (ยืนยันเป็นบั๊กจริง)

**สาเหตุราก:** ฟิลด์โปรไฟล์ทั้งหมด (ชื่อ, username, เบอร์โทร, รูป, เป้าหมายออม) เก็บอยู่ใน
ตาราง key/value `Settings` ซึ่ง**เป็น local‑only** — `SyncEngine` ไม่เคย push/pull ตารางนี้
และตอนออกจากระบบ `SettingsRepository.resetUserData()` ลบค่าเหล่านี้ทิ้ง
(ถูกต้องตามแนวคิด "บัญชีถัดไปต้องเริ่มสะอาด") แต่เมื่อไม่มีสำเนาบนคลาวด์
การล็อกอินกลับมาจึง**ไม่มีอะไรให้ restore** → ข้อมูลโปรไฟล์หายทุกครั้งที่ออกจากระบบ
แม้แต่ชื่อที่กรอกตอนสมัครสมาชิก (`setDisplayName` ใน signup) ก็หายเช่นกัน

**การแก้ (รอบนี้):** เพิ่มการซิงค์ settings แบบ per‑key เข้าโครงเดิมของ engine

- Firestore: `users/{uid}/settings/{key}` = `{value, updatedAt}` — LWW ต่อ key ผ่าน
  `_pushDoc` ตัวเดิม (transaction เทียบ `updatedAt` ฝั่ง push) จึงแก้ชื่อบนเครื่อง A
  และเป้าหมายออมบนเครื่อง B พร้อมกันได้โดยไม่ทับกัน
- Whitelist keys: `displayName`, `username`, `phone`, `savingsGoalCents`,
  `disabledScanIds` (`AppDatabase.syncedSettingsKeys`) — key ที่ pull ลงมาถูกกรองด้วย
  whitelist เดียวกัน กัน doc แปลกปลอมปลูก row ในเครื่อง
- สถานะ pending ไม่ต้องแก้ schema: marker `settingsPushed:<key>` เก็บ `updatedAt`
  ที่อัปโหลดสำเร็จล่าสุด → pending คือ `row.updatedAt > marker` (semantics เดียวกับ
  markXSynced แบบ compare‑and‑set: แก้ค่าระหว่าง upload บิน ค่ายังคง pending)
- Pull ดึงทั้ง collection (≤ 5 docs, ไม่ต้องมี watermark) แล้วเขียนด้วย
  `upsertPulledSetting` ที่**คง `updatedAt` ของ remote** (ไม่ stamp `now` — ไม่งั้นค่า
  ที่เพิ่ง pull จะดูเหมือนแก้ใหม่แล้ววน push กลับ)
- ผูกเข้าทุกจุดของวงจรเดิม: `_pushAll`/`_pullAll`, `flushPending` ก่อน logout,
  `hasPendingRows` (คำเตือน "มีข้อมูลยังไม่ซิงค์" ก่อน logout ครอบคลุมโปรไฟล์แล้ว),
  `clearAllData` ล้าง marker, `nudgePush` ฟัง `appSettingsProvider`

## ปัญหาข้อ 2 — สลิปที่เคยจดหายหลังล็อกอินใหม่ (พบสาเหตุร่วม 3 ชั้น)

ข้อมูลสลิป (ตาราง `slips`) และรายการที่สร้างจากสลิป (ตาราง `transactions`) **ซิงค์อยู่แล้ว
และเส้นทาง pull หลังล็อกอินถูกต้อง** (watermark ถูกล้างตอน logout → login ใหม่ pull
ทั้งหมด) สิ่งที่ทำให้ผู้ใช้เห็นว่า "สลิปหาย" มาจาก 3 ชั้นนี้:

### 2ก. รูปสลิปแสดงไม่ได้หลัง restore (แก้แล้วในรอบนี้)
`SlipRow.imagePath` เป็น path ไฟล์ในเครื่องและตั้งใจไม่ซิงค์ ตอนออกจากระบบตาราง slips
ถูกล้าง เมื่อ login กลับมาแถวสลิปถูก restore แต่ `imagePath = null` → ตัวเปิดดูสลิป
(`SlipImage`) แสดง**ไอคอน placeholder แทนรูปสลิปทุกใบ** ทั้งที่รูปต้นฉบับยังอยู่ใน
แกลเลอรีของเครื่องเดิม และ `assetId` (id ของรูปในแกลเลอรี) ก็ซิงค์กลับมาด้วยแล้ว

**แก้:** `SlipImage` resolve ตาม path ก่อน ถ้าไฟล์ไม่อยู่/ไม่มี path ให้ fallback เปิดรูปจาก
แกลเลอรีด้วย `AssetEntity.fromId(assetId)` → สลิปที่เคยจดกลับมาดูได้เหมือนเดิมบนเครื่องเดิม

### 2ข. เวอร์ชันก่อน 4 ก.ค. ทำลายแถวที่ยังไม่ push ตอนออกจากระบบ (แก้ไปแล้วใน PR #40)
โค้ดก่อน `5ef1dda` ออกจากระบบแบบ `signOut()` → `clearAllData()` ทันที **โดยไม่ flush
แถว pending และไม่เตือน** — สลิปที่เพิ่งสแกน (ยัง pending อยู่หลัง debounce 3 วิ, push
ล้มเหลวระหว่าง full sync, หรือออฟไลน์) ถูกลบทิ้งก่อนถึงคลาวด์ถาวร ถ้าผู้ใช้เจอปัญหานี้
ด้วย build เก่า ข้อมูลที่หายไปแล้ว**กู้คืนไม่ได้** (คลาวด์ไม่เคยได้รับ) แต่ build ปัจจุบันมี
`flushPending` + dialog เตือนเมื่อยังมีแถวค้างแล้ว

### 2ค. ความเสี่ยงเชิงระบบ: sync ล้มเหลว "เงียบสนิท" (บรรเทาในรอบนี้ + ต้องเช็ก backend)
ทุก error ใน `sync()`/`pushOnly()` ถูก `catch (_)` กลืนโดยไม่มีร่องรอย ถ้า backend มีปัญหา
— ที่พบบ่อยที่สุดคือ **Firestore rules ยังไม่ deploy** หรือ **สร้าง database ในโหมด test
แล้วกฎหมดอายุ 30 วัน** (โปรเจกต์นี้เป็นโปรเจกต์ Firebase Studio: `studio-3816117841-f3521`
ซึ่งมักถูกสร้างในโหมด test) — ทุก push/pull จะล้มด้วย `PERMISSION_DENIED` ตลอดไปโดย
ผู้ใช้ไม่มีทางรู้ ใช้แอปได้ปกติทุกอย่าง (local‑first) จนกระทั่ง**ออกจากระบบแล้วทุกอย่างหาย**
ซึ่งตรงกับอาการที่รายงานทั้งสองข้อพอดี

**แก้ในโค้ด:** log error ที่เคยถูกกลืน (`debugPrint`) เพื่อให้วินิจฉัยได้จาก logcat
**ต้องทำฝั่ง backend (ทำครั้งเดียว):**
1. เปิด Firebase console → Firestore → Rules ของโปรเจกต์ `studio-3816117841-f3521`
   ถ้าเห็นกฎแบบ `allow read, write: if request.time < timestamp.date(...)` (test mode)
   หรือ deny ทั้งหมด ให้ deploy กฎของ repo: `firebase deploy --only firestore:rules`
2. ทดสอบตามหัวข้อ "ตรวจสอบ" ใน `SETUP_FIREBASE.md`: เพิ่มรายการ 1 รายการแล้วดูว่า
   doc โผล่ใต้ `users/{uid}/transactions` ใน console จริง

### 2ง. ผู้ใช้ Google/Apple ครั้งแรกไม่ได้ starter data (แก้แล้วในรอบนี้)
`seedDefaults()` ถูกเรียกเฉพาะเส้นทางสมัครด้วยอีเมล ผู้ใช้ใหม่ที่กดปุ่ม Google/Apple
จากหน้า login (ไม่ผ่านหน้า signup) ได้บัญชีที่**ไม่มีหมวดหมู่/บัญชีเงินตั้งต้นเลย**
(คลาวด์ว่าง ไม่มีอะไรให้ pull) — อาการภายนอกดูเหมือน "ข้อมูลหาย" เช่นกัน
**แก้:** seed หลัง sign-in สำเร็จทุกเส้นทาง — ปลอดภัยกับผู้ใช้เดิมเพราะ seed ใช้
`updatedAt: 0` ข้อมูลจริงบนคลาวด์ชนะ LWW เสมอ และ seed ที่ผู้ใช้เคยลบมี tombstone
บนคลาวด์คอยชนะกลับ

---

## จุดที่ตรวจแล้ว "ทำงานถูกต้อง" (ยืนยันในการตรวจรอบนี้)

- ลำดับ sync ตอน login: pull ก่อน push + seed `updatedAt 0` → cloud ชนะ ไม่มีทาง
  default ทับข้อมูลจริง; `_pushDoc` มี LWW ฝั่ง push ผ่าน Firestore transaction
- Watermark ต่อ collection ถูกลบใน `clearAllData` → login ใหม่ pull เต็มเสมอ;
  มี margin 7 วันกัน clock เพี้ยน + clamp กัน clock เร็ว
- ออกจากระบบ (build ปัจจุบัน): `flushPending(10s)` → เช็ก `hasPendingRows` →
  เตือนก่อนทิ้ง → signOut → wipe ใน `finally`; `_sameUser` guard กันข้อมูลเก่า
  เขียนหลัง wipe / ปนบัญชีถัดไป
- Scanner gate: หลัง login ใหม่ การสแกนสลิปรอ restore สำเร็จก่อน (กัน re-import ซ้ำ)
  และ dedup ด้วย `assetId` + `transRef` ครอบเคส restore แล้ว
- Tombstone soft-delete + GC 90 วัน สัมพันธ์กับ pull margin ถูกต้อง; ลบแท็กมี cascade
  ที่ mark รายการที่เกี่ยวข้องให้ re-push
- `firestore.rules` จำกัดต่อ uid ถูกต้อง (ปัญหาที่เป็นไปได้คือ "ยังไม่ได้ deploy" ไม่ใช่ตัวกฎ)

## ข้อจำกัดที่เหลือ / ข้อเสนอแนะรอบถัดไป

1. **รูปโปรไฟล์ยังไม่ซิงค์** — เป็นไฟล์ในเครื่อง แก้จริงต้องใช้ Firebase Storage
   (หรือย่อรูปเป็น base64 ≤ ~100KB เก็บใน doc เดียว) — ยังไม่ทำในรอบนี้เพื่อไม่เพิ่ม
   dependency ใหม่โดยไม่จำเป็น
2. **รูปสลิปข้ามเครื่อง** — `assetId` ใช้ได้เฉพาะเครื่องที่มีรูปในแกลเลอรี เครื่องใหม่
   จะเห็นข้อมูลสลิปครบแต่ไม่มีรูป (ต้องใช้ Storage เช่นกัน)
3. **ควรมีตัวบอกสถานะซิงค์ใน UI** (ซิงค์ล่าสุดเมื่อไร / มีกี่รายการค้าง / error ล่าสุด)
   — ตอนนี้ log แล้วแต่ผู้ใช้ทั่วไปยังมองไม่เห็น ถ้ามีหน้านี้ ปัญหาแบบ 2ค จะโผล่ทันที
4. **Server timestamp** — `updatedAt` ยังอิงนาฬิกาเครื่อง (มี margin/clamp บรรเทาแล้ว)
   ตามแผนเดิมของ engine ควรย้ายไป `FieldValue.serverTimestamp()` ในอนาคต

## ไฟล์ที่แก้ในรอบนี้

| ไฟล์ | สาระ |
|---|---|
| `lib/data/local/database.dart` | whitelist + marker + `pendingSyncedSettings`/`markSettingPushed`/`upsertPulledSetting`/`getAllSettings`; `clearAllData` ล้าง marker; `hasPendingRows` รวม settings |
| `lib/data/remote/sync_engine.dart` | `_pushSettings`/`_pullSettings` + log error ที่เคยถูกกลืน |
| `lib/bootstrap/providers.dart` | `nudgePush` เมื่อ settings เปลี่ยน |
| `lib/core/widgets/slip_image.dart` | fallback เปิดรูปสลิปจากแกลเลอรีผ่าน `assetId` |
| `lib/features/auth/presentation/login_screen.dart` | `seedDefaults()` หลัง sign-in ทุกเส้นทาง |
| `test/database_test.dart` | เทสต์ marker CAS / pulled setting / hasPendingRows / clearAllData |
| `SETUP_FIREBASE.md` | เพิ่มอาการ "ข้อมูลหายหลังล็อกอินใหม่" ในตารางปัญหาที่พบบ่อย |

## วิธีทดสอบด้วยตัวเอง

1. แก้ชื่อ/username/เบอร์ในโปรไฟล์ + ตั้งเป้าหมายออม → รอ ~3 วิ (debounce push) →
   ออกจากระบบ → ล็อกอินใหม่ → ค่าทั้งหมดต้องกลับมา (ดูใน console: `users/{uid}/settings/*`)
2. สแกนสลิป → ออกจากระบบ → ล็อกอินใหม่ → รายการสลิปต้องกลับมาและ**เปิดดูรูปได้**
3. แก้โปรไฟล์ตอนปิดเน็ต → กดออกจากระบบ → ต้องเจอคำเตือน "มีข้อมูลยังไม่ซิงค์"
4. สร้างบัญชีใหม่ด้วยปุ่ม Google → ต้องมีหมวดหมู่/บัญชีเงินตั้งต้นครบ
