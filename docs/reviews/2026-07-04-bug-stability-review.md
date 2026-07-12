# รายงานตรวจสอบบัคและความเสถียรของแอป MoneyBun

**วันที่ตรวจ:** 4 กรกฎาคม 2026 · **ฐานโค้ด:** `main` @ `3d306a3` (~22,700 บรรทัด Dart, 110 ไฟล์)

## วิธีตรวจ

1. รัน toolchain จริงตาม CI: `flutter pub get` → `gen-l10n` → `build_runner` → **`flutter analyze` = 0 issues** → **`flutter test` = ผ่านทั้ง 98 เทสต์**
2. อ่านโค้ดละเอียดทุกชั้น: data (Drift/ตาราง/migration), sync engine + controller, Firestore mappers/rules, auth, slip pipeline (QR/TLV/OCR/extractor/importer), recurring service, repositories, router, providers, utils, widgets, ทุก screen, ทุก sheet, AndroidManifest/Gradle, CI workflows, l10n
3. บัคที่สงสัยถูกยืนยันด้วยการอ่าน call site ประกอบ และบางรายการเขียนเทสต์ repro รันจริง (TLV parser)

**ภาพรวม:** คุณภาพโค้ดโดยรวมอยู่ในเกณฑ์ดีมาก — สถาปัตยกรรม local-first + LWW sync ออกแบบรัดกุม, มีเทสต์ครอบคลุม logic สำคัญ, analyzer สะอาด อย่างไรก็ตามพบบัคจริง **1 รายการระดับวิกฤต, 9 กลุ่มระดับสำคัญ, และ ~25 รายการระดับรอง** โดยปัญหาส่วนใหญ่กระจุกอยู่ใน 3 รูปแบบเชิงระบบ (ดูท้ายรายงาน)

---

## ระดับวิกฤต (Critical)

### C1 — สมัครสมาชิกแล้วบัญชีใหม่อาจไม่มีหมวดหมู่/บัญชีเงินเลย (seeding race)
`lib/features/auth/presentation/signup_screen.dart:181-213`

ทันทีที่ Firebase ประกาศ user ใหม่ router redirect (`app_router.dart:49-57` ผูกกับ `authStateChanges`) จะเตะหน้า `/signup` ทิ้ง ระหว่างที่ `signUpWithEmail` ยังรอ round-trip `updateDisplayName` อยู่ → widget ถูก dispose → `ref.read(settingsRepositoryProvider)` (บรรทัด 194) โยน exception → ถูก `catch` กลืนเงียบ ๆ → **`seedDefaults()` (197), `setFirstSyncDone(true)` (201), `setDisplayName` (203) ถูกข้ามทั้งหมด**

`seedDefaults()` ไม่ถูกเรียกจากที่อื่นตอน runtime (มีแค่ `onCreate`/migration ของ DB) ดังนั้นเส้นทาง "ออกจากระบบ (ล้าง DB) → สมัครบัญชีใหม่บนเครื่องเดิม" จะได้บัญชีที่**ไม่มีหมวดหมู่และบัญชีเงินตั้งต้นถาวร** (cloud ว่างเปล่า ไม่มีอะไรให้ restore)

**แนวแก้:** capture `repo`/`db` ก่อน `await` (แบบเดียวกับที่ `settings_screen._logout` ทำไว้ถูกแล้ว) และอย่าผูกงาน seeding กับอายุของ widget

---

## ระดับสำคัญ (Major)

### M1 — ออกจากระบบทิ้งข้อมูลที่ยังไม่ได้ซิงค์ → ข้อมูลหายถาวร
`lib/features/settings/presentation/settings_screen.dart:169-171`

`_logout` เรียก `signOut()` → `clearAllData()` โดย**ไม่ push ข้อมูลค้างก่อน** แถวที่ยัง `pending*` (เพิ่ม/แก้ภายใน ~3 วิ ก่อนหน้า เพราะ debounce push 3 วิ; แก้ระหว่าง full sync กำลังวิ่ง ซึ่ง `pushOnly` จะ no-op เพราะ `_running` และไม่มีการ retry — ดู M-D14; หรือแก้ตอนออฟไลน์ทั้งหมด) จะถูกลบทิ้งโดยไม่ถึง cloud ข้อความยืนยัน (`logoutBody`) บอกว่า "ข้อมูลของคุณถูกบันทึกไว้แล้ว" ซึ่งไม่จริงในกรณีนี้

**แนวแก้:** `await engine.pushOnly()` แบบมี timeout ก่อน signOut + ถ้ายังมีแถวค้าง/ไม่มีเน็ต ให้เตือนผู้ใช้ก่อน

### M2 — Pull ที่ค้างกลางอากาศเขียนข้อมูลบัญชีเก่าหลังล้าง DB → ข้อมูลปนข้ามบัญชี
`lib/data/remote/sync_engine.dart` (ทุก `_pull*`)

Sync ไม่มีกลไก cancel; `_logout` ไม่รอ sync ที่กำลังวิ่ง pull ที่ยิงไปก่อน signOut สามารถ resolve หลัง `clearAllData()` แล้ว `batchUpsert*` เขียนแถวของบัญชีเก่า (สถานะ `synced`) กลับเข้า DB ที่เพิ่งล้าง → บัญชีถัดไปที่ล็อกอินเห็นข้อมูลของคนก่อน (ฝั่ง slip scanner มี `isCancelled` ป้องกันเคสนี้แล้ว แต่ sync engine ไม่มี) เสริมด้วย V14: `_logout` ไม่มี error handling — ถ้า `signOut()`/`clearAllData()` โยน ลำดับล้างที่เหลือถูกข้ามเงียบ ๆ

**แนวแก้:** เช็ค uid/generation token ก่อนเขียน DB ในแต่ละ `_pull*` หรือรอ/ยกเลิก sync ที่วิ่งอยู่ตอน logout + ใส่ try/finally ใน `_logout`

### M3 — Race ระหว่าง push กับ markSynced ทำให้การแก้ไขล่าสุดไม่ถูกอัปโหลด
`lib/data/remote/sync_engine.dart:163-169` (และ `_push*` ทุกตัว), `database.dart:555-558`

หลัง `_pushDoc` (round-trip เครือข่าย) โค้ดเรียก `markTransactionSynced(id)` ซึ่งตั้ง `syncStatus=synced` **แบบไม่มีเงื่อนไข** ถ้าผู้ใช้แก้แถวเดิมระหว่าง push กำลังบิน (repo ตั้ง `pendingUpdate` + `updatedAt` ใหม่) จะถูกทับเป็น `synced` → การแก้ไขใหม่ไม่ถูก push (และ pull ก็ไม่ดึงกลับเพราะ local ใหม่กว่า cloud) เครื่องอื่นไม่เห็นการแก้ไขนี้ และถ้าเครื่องนี้ sign-out ภายหลัง = หายถาวร

**แนวแก้:** compare-and-set — `UPDATE ... WHERE id = ? AND updatedAt = ?` (ใช้ค่า `updatedAt` ที่อ่านตอน push)

### M4 — กดปุ่มซ้ำ (double-tap) สร้างข้อมูลซ้ำ + pop ซ้อนปิดหน้าจอข้างใต้ (พบซ้ำกันหลายจุด)
ไม่มี busy/single-flight guard และ `PrimaryButton` ไม่มีสถานะ loading ระหว่าง submit:
- `add_transaction_sheet.dart:474-529` — บันทึกซ้ำได้ 2 รายการ (คนละ UUID) + `pop` ซ้ำปิด route ข้างใต้
- `budget_sheet.dart:401-434` — งบซ้ำ 2 แถวสำหรับหมวดเดียวกัน → ยอดงบถูกนับสองเท่าถาวร
- `add_category_sheet.dart:174-189` — หมวดหมู่ซ้ำ + pop ซ้อน
- `recurring_rule_sheet.dart:338-362` — กฎประจำซ้ำ 2 กฎ → รายการอัตโนมัติถูกสร้างซ้ำทุกงวด
- `category_picker_sheet.dart:106-110` — แตะหมวดรัว ๆ = pop 2 ครั้ง ปิดชีต Add ข้างใต้ ข้อมูลที่พิมพ์หาย
- `add_transaction_sheet.dart:531-553` — dialog ยืนยันลบซ้อนสองชั้น → pop เกิน

**แนวแก้:** guard กลางที่เดียว เช่น flag `_busy` เซ็ตก่อน await แรก + ปิดปุ่มด้วยสถานะ loading + ใช้ `maybePop`/pop ครั้งเดียว

### M5 — ปุ่ม social login กดรัวได้ / `_run` re-enter ได้
`login_screen.dart:116-131, 164-184` — `_busy` ปิดเฉพาะปุ่มอีเมล; ปุ่ม Google/Apple ไม่เคยถูก disable และ `_run` ไม่มี `if (_busy) return` → `GoogleSignIn.authenticate()` ซ้อนกัน ตัวที่สองโยน exception บน Android, snack error ซ้อน

### M6 — เปลี่ยนชื่อ/ไอคอน/สีหมวดหมู่แล้วหน้าจัดการยังโชว์ค่าเก่า
`category_tag_board.dart:537-545` — `didUpdateWidget` ของ grid จะ resync ก็ต่อเมื่อ**เซ็ตของ id เปลี่ยน**เท่านั้น การ rename (id เดิม) จึงไม่ trigger → tile แสดงชื่อเก่าจนกว่าจะมี add/delete หรือเข้าหน้าใหม่ (การแก้จากเครื่องอื่นผ่าน sync ก็ stale เช่นกัน)

### M7 — เลือกรูปโปรไฟล์: crash path หลายทาง
`profile_screen.dart:129-149` — (a) `pickImage` ไม่มี try/catch: แตะรัวเปิด picker ซ้อน → `PlatformException(already_active)` เป็น unhandled error (b) ไม่มี `mounted` ก่อน `ref.read` หลังกลับจาก picker (ผู้ใช้ back ออกจากหน้าได้ง่ายเพราะ picker เป็น activity แยก) → `StateError`, avatar ไม่ถูกบันทึก, ไฟล์ที่ copy แล้วตกค้าง

### M8 — ประสิทธิภาพหน้า Search และ All-transactions กับข้อมูลเยอะ
- `search_screen.dart:79-88,166-208` — ทุก keystroke สแกนทุกรายการ (lowercase note+ชื่อหมวดต่อแถว) และ render ผลด้วย `ListView(children:[...])` แบบไม่ lazy → ข้อมูลหลักพันแถวค้างเป็นวินาที/เสี่ยง ANR บนเครื่องช้า
- `all_transactions_screen.dart:78-112` — list ไม่ lazy เช่นกัน; โหมด "ปี" สร้าง widget ทุกรายการในเฟรมเดียว

**แนวแก้:** `ListView.builder` + debounce การค้นหา (หรือ query ผ่าน SQL LIKE ใน Drift)

### M9 — เลขคณิตสัปดาห์พังใน timezone ที่มี DST (แฝงสำหรับผู้ใช้ในไทย)
`app_date.dart:38-47` + `date_period.dart:54-58` — ใช้ `Duration`-based arithmetic ข้ามวัน DST เปลี่ยน → กด "สัปดาห์ถัดไป" ครั้งแรกไม่ขยับ (normalize กลับสัปดาห์เดิม), period picker เลือกสัปดาห์ผิด, กราฟเปรียบเทียบมีแท่งซ้ำ, ธุรกรรมชั่วโมงสุดท้ายของวันเสาร์หายจากยอดรวมสัปดาห์, `difference().inDays` จัดแท่งผิดวัน ประเทศไทยไม่มี DST จึงไม่กระทบผู้ใช้หลัก แต่กระทบผู้ใช้ที่ตั้งเครื่องเป็น timezone อื่น

**แนวแก้:** ใช้ calendar arithmetic — `DateTime(y, m, d - offset)` แทน `subtract/add(Duration(days: n))`

---

## ระดับรอง (Minor) — จัดกลุ่มตามหัวข้อ

### Slip pipeline / นำเข้าสลิป
| # | ที่ | ปัญหา |
|---|----|-------|
| S1 | `tlv_parser.dart:44-47, 60-65` | **ยืนยันด้วย repro test แล้ว:** `int.tryParse` รับ "-1" ได้ → length ติดลบผ่าน guard `end > data.length` → `substring` โยน `RangeError` (QR แปลกปลอม 1 รูปทำให้รูปนั้น error ตลอด) — แก้โดย reject `len < 0` |
| S2 | `slip_importer.dart:283-287` | รูปที่ error ค้าง (เช่น S1, ไฟล์ decode ไม่ได้) ทำให้ `_saveScannedUpTo` ไม่เคยถูกเรียก → cursor ไม่ขยับ → ทุกสแกน re-OCR ทั้งหน้าต่างเดือนซ้ำ ๆ (เปลืองแบต/เวลา) |
| S3 | `slip_importer.dart:329-330` | ใน loop ต่อรูป เรียก `_importedAssetIds()`/`_importedSlipRefs()` อ่านทั้งตารางใหม่ทุกรูป — O(รูป×สลิป) ช้าเมื่อ backlog ใหญ่ |
| S4 | `slip_importer.dart:255` | รูปที่ gallery ไม่รู้เวลาสร้าง (`createDateTime` = epoch 0) จะไม่เข้าหน้าต่างสแกนตลอดกาล — ข้ามเงียบ ๆ |
| S5 | `slip_extractor.dart:146-153` | วันที่ OCR เพี้ยนแบบ "31/02/69" ถูก DateTime normalize เป็น 3 มี.ค. แทนที่จะ reject แล้ว fallback ไปวันที่รูป (try/catch เป็น dead code — Dart DateTime ไม่โยน) |
| S6 | `slip_extractor.dart:79-87`, `slip_importer.dart:371` | Heuristic "เลขบวกที่ใหญ่สุด" อ่านบรรทัดยอดคงเหลือเป็นยอดโอนได้ (สลิปที่พิมพ์ balance); สลิปอ่านไม่ออกสร้างรายการ ฿0 |
| S7 | `tlv_parser.dart:117-131` | transRef อาจได้ค่า blob ของ template แม่แทน ref จริง (parent ถูก flatten ก่อนลูก) — deterministic จึงไม่พัง dedup แต่เสีย confidence bonus |

### Lifecycle / `ref` หลัง `await` (เสี่ยง `UnmountedRefException` เมื่อ auth redirect เตะ route ระหว่าง dialog/sheet เปิดอยู่)
- `home_screen.dart:306→313-319, 333→350`; `all_transactions_screen.dart:150→158-161`; closure `onDelete` ที่ส่งให้ `showSlipViewer` (`home_screen.dart:297`, `all_transactions_screen.dart:135`)
- `add_transaction_sheet.dart:457-470, 410-416, 443-446`; `category_tag_board.dart:198, 227, 291`; `manage_recurring_screen.dart:166`
- `TextEditingController` ใน dialog ไม่ถูก dispose: `add_transaction_sheet.dart:421`, `category_tag_board.dart:208, 235, 265`
- `providers.dart:283-287` — callback `scan(auto:true)` หลัง `awaitInitialSync` ไม่มี guard ตอน container ถูก dispose

### ความถูกต้องของข้อมูล/การแสดงผล
- `colors.dart:60-64` — `AppColors.forHex` ใช้ `int.parse` ไม่มี guard: `colorHex` เสีย/ว่างจาก cloud หนึ่งแถวทำให้ Stats/Budget/Home/Search แดงพร้อมกัน (call sites: `stats_screen.dart:601`, `budget_screen.dart:233`, `budget_sheet.dart:159`, `txn_display.dart:42`, `category_tag_board.dart:402,625`, `recurring_rule_sheet.dart:212`) — ควรใช้ `tryParse` + สี fallback
- `money.dart:39-44` — `Money.compact` ไม่รองรับค่าลบ → การ์ดเกินงบโชว์ "฿-500" (`home_screen.dart:511,553-557`, `budget_screen.dart:58,129-134`)
- `money.dart:54-61` — `parseToCents` รับ "1e5" (=฿100,000) และไม่มีเพดานค่า
- `add_transaction_sheet.dart:490` — `_persistLive` ในโหมดแก้ไขเขียนยอด 0 ทับได้เงียบ ๆ (ต่างจาก `_save` ที่ validate)
- `savings_goal_screen.dart:57` — `~/ 100` ตัดเศษสตางค์ตอนเปิดแก้ไข → round-trip แล้วเงินเป้าหมายหายเศษ
- `accounts_sheet.dart:23-37` — toggle ธนาคารคำนวณจาก snapshot เก่า (แตะเร็ว 2 ปุ่มอันแรก revert; เฟรมแรก settings null → แตะแล้วล้างค่า disabled ทั้งหมด)
- `app_date.dart:99-113` — `formatWeekRange` ข้ามปีใหม่แสดงปีของวันสิ้นสัปดาห์กับวันต้นสัปดาห์ผิด (แสดงผลเท่านั้น)
- `recurring_rule_sheet.dart:319-336` — เลือกวันเริ่มย้อนหลังได้ถึงปี 2015 → backfill สูงสุด 400 รายการต่อการเปิดแอปโดยไม่เตือน

### Auth / bootstrap / infra
- `login_screen.dart:177-181` + `auth_errors.dart:13-37` — ผู้ใช้กดยกเลิก Google/Apple sign-in เอง ได้ snack "เข้าสู่ระบบไม่สำเร็จ" (map เฉพาะ `FirebaseAuthException`) — ควรเงียบเมื่อ cancel
- `auth_service.dart:96-105` — `identityToken` ของ Apple เป็น null ได้ ไม่มี guard ก่อนสร้าง credential
- `splash_screen.dart:25-54` — `_boot` ไม่มี error handling: DB เปิดไม่ได้ → ค้างหน้า splash ตลอดไป ไม่มี retry
- `main.dart` — ไม่มี `FlutterError.onError` / `PlatformDispatcher.instance.onError` / crash reporting → error ใน release มองไม่เห็นเลย (ช่องโหว่ observability สำคัญสำหรับแอป sync)
- `help_screen.dart:304-312` — mailto ผ่าน `queryParameters` เข้ารหัสช่องว่างเป็น `+` → หัวข้ออีเมลเพี้ยน
- `app_router.dart:171-185` — `asBroadcastStream()` ไม่จำเป็น (stream ของ FirebaseAuth เป็น broadcast อยู่แล้ว) และ subscription ชั้นในไม่ถูกยกเลิกตอน dispose (ไม่กระทบจริงเพราะ router อายุเท่าแอป); ไม่มี `errorBuilder` สำหรับ deep-link ผิด; redirect ไป `/login` ทิ้งปลายทางเดิม (ไม่มี return-to)
- `providers.dart:346-351` — `transactionByIdProvider` เป็น family ที่ไม่ autoDispose (ตอนนี้ไม่มีผู้เรียก = dead code แต่ถ้าเริ่มใช้จะ leak stream ต่อ id); `tagUsageProvider`, `onboardingSeenProvider` ไม่ถูกใช้ และ doc ของตัวหลัง stale
- `sync_controller.dart:102-105` — `nudgePush` ที่ debounce ไประหว่าง full sync จะถูก `_running` กลืนโดยไม่ retry → แถว pending รอ trigger ถัดไป (ขยายความเสี่ยง M1)
- Repository API ที่มีขอบคม (ยังไม่มีผู้เรียกที่โดนจริง): `category_repository.dart:29-41` (`save(id:)` รีเซ็ต `sortOrder`→0, `createdAt`→now), `tag_repository.dart:47-64` (rename ที่ไม่ส่ง `colorHex` ซ้ำจะล้างสี — call site ปัจจุบันส่งครบ)
- `android/app/build.gradle.kts` — release ยังเซ็นด้วย debug key (TODO ที่รู้อยู่แล้ว): Google Sign-In จะใช้ได้เฉพาะเมื่อ SHA-1 ของ debug key ลงทะเบียนใน Firebase และเผยแพร่ Play Store ไม่ได้จนกว่าจะมี signing จริง

### เทสต์ที่ควรเพิ่ม (จากการ cross-check กับ `test/`)
`addMonths(31 ม.ค., 1)`/`addYears(29 ก.พ., 1)` (behavior ยังไม่ถูก pin), `formatWeekRange` ข้ามปี, formatter พ.ศ. (`formatDay/Month/Year` locale th), `daysRemaining`, `Money.compact` (ยังไม่มีเทสต์เลย รวม case ติดลบ), `parseToCents('1e5')`, `budgetForWindow` กับเดือน ก.พ./31 วัน, TLV length ติดลบ (S1)

---

## จุดที่ตรวจแล้ว "สะอาด"

- **Sync design:** LWW ด้วย `updatedAt`, seed `updatedAt=0` เพื่อให้ cloud ชนะ, pull margin 7 วัน + tombstone GC 90 วัน (สัมพันธ์กันถูกต้อง), watermark clamp กัน clock เร็ว, `_pushDoc` เช็ค LWW ฝั่ง push ผ่าน transaction
- **Recurring:** anchor-day clamp ข้ามเดือนสั้นถูกต้อง (31 → 28 ก.พ. → 31 มี.ค.), occurrence id แบบ deterministic กันซ้ำข้ามเครื่อง, cap 400
- **Calculator / budget_math / money formatting:** ครบทุก edge (÷0, precedence, เปอร์เซ็นต์, ปัดเศษ)
- **Firestore rules:** จำกัดต่อ uid ถูกต้อง, default deny; indexes ว่างเพียงพอสำหรับ query ที่ใช้
- **l10n:** คีย์ th/en ตรงกัน 328 = 328
- **Widgets/painters:** AnimationController dispose ครบ, CustomPainter ทุกตัว guard กรณี degenerate, pixel data ตรวจด้วยสคริปต์ครบ 103 glyphs
- **AndroidManifest:** permission ครบถ้วนถูกต้องสำหรับ photo_manager (Android 13+/14 partial access/legacy)
- **Export/Currency/Theme/ForgotPassword/Onboarding screens:** สะอาด (export มี busy flag ที่ถูกต้อง — เป็นแบบอย่างที่ควรใช้กับ M4)

---

## รูปแบบปัญหาเชิงระบบ (แก้ครั้งเดียวได้หลายจุด)

1. **ไม่มี single-flight guard บนปุ่ม submit แบบ async ที่จบด้วย `Navigator.pop`** → บัคตระกูล M4 ทั้งหมด — แนะนำทำ helper/mixin กลาง (เซ็ต busy ก่อน await แรก + ปุ่ม loading + pop ครั้งเดียว) แล้วไล่ใช้ทุก sheet
2. **ใช้ `ref`/`setState` หลัง `await` โดยไม่เช็ค `mounted`** — อันตรายเป็นพิเศษเพราะ auth-refresh redirect ของ go_router สามารถถอด route ได้ทุกเมื่อ (ต้นเหตุของ C1 ด้วย) — แนะนำ capture provider ก่อน await + เช็ค `mounted` หลังทุก await ที่มี UI
3. **เส้นทาง sign-out/account-switch ไม่ atomic** (M1, M2, V14) — ควรมี "logout orchestrator" เดียว: push ค้าง → หยุด/รอ sync → signOut → wipe → reset ภายใต้ try/finally

## ลำดับการแก้ที่แนะนำ

1. C1 (signup seeding) — กระทบผู้ใช้ใหม่ตรง ๆ และแก้ง่าย (ย้าย 3 บรรทัดขึ้นก่อน await / capture ก่อน)
2. M1+M2+V14 (logout orchestration) — เส้นทางข้อมูลหาย/ข้อมูลปนบัญชี
3. M4+M5 (busy guard กลาง) — บัคข้อมูลซ้ำที่ผู้ใช้เจอได้ทุกวัน
4. M3 (compare-and-set markSynced) — ปิด race ของ sync
5. S1+S2 (TLV negative length + error ไม่ block cursor) — เสถียรภาพ scanner
6. ที่เหลือตามสะดวก (M6-M9 และ minor)
