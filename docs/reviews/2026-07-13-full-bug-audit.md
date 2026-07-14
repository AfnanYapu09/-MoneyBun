# รายงานตรวจสอบบัคทั้งแอป MoneyBun (รอบ 13 ก.ค. 2026)

**ฐานโค้ด:** branch `claude/membership-v2-credits` @ `3a51e98` (+ แก้ overflow หน้าแพลนที่ยังไม่ commit)
**วิธีตรวจ:** review แบบขนาน 5 ระบบ (sync/ข้อมูล, membership v2, ไปป์ไลน์สลิป, UI ทุกหน้าจอ, auth/lifecycle) โดย agent อิสระ 5 ตัว แล้วตรวจทานข้อค้นพบสำคัญทุกข้อกับโค้ดจริงซ้ำอีกชั้น ประเด็นที่ผ่านการตรวจทานซ้ำจะติดป้าย **[ยืนยันแล้ว]**; ที่เหลือเป็น **[น่าเชื่อ]** (กลไก trace ครบแต่ต้องยืนยันด้วย runtime)

**ภาพรวม:** พบ **3 วิกฤต, 9 สำคัญ, ~20 รอง** — จุดแข็งเดิมยังอยู่ (LWW sync, tombstone, QuotaPeriod math, redeem atomicity ตรวจแล้วสะอาด) แต่บั๊กกระจุกใน 3 รูปแบบ: (1) งานที่วิ่งค้างข้ามการ sign-out/wipe, (2) companion/predicate ที่ไม่ครบ field ทำให้สถานะ sync เพี้ยน, (3) cursor/cutoff ของ scanner ที่หักล้างกันเอง

---

## ระดับวิกฤต (Critical)

### C1 — Migration พังสำหรับผู้ใช้ schema ≤ 6: เปิดแอปไม่ได้เลย [ยืนยันแล้ว]
`lib/data/local/database.dart:72-83`

`if (from < 7) m.createTable(recurringRules)` สร้างตารางตาม schema **ปัจจุบัน (v9)** ซึ่งมี `anchorDay` อยู่แล้ว จากนั้น `if (from < 9) m.addColumn(recurringRules, anchorDay)` จะ `ALTER TABLE ADD COLUMN` คอลัมน์ซ้ำ → SqliteException → DB เปิดไม่ได้ → แอปใช้ไม่ได้ถาวรสำหรับคนที่อัปเกรดจากเวอร์ชันก่อนมี recurring (v2–6) เครื่องปัจจุบันที่อยู่ v7+ ไม่โดน จึงทดสอบไม่เจอ

**แนวแก้:** เปลี่ยนเงื่อนไข addColumn เป็น `if (from >= 7 && from < 9)`

### C2 — ถูกเตะออกจากระบบเอง (token หมดอายุ/ถูกเพิกถอน) ไม่ล้างข้อมูลเครื่อง → ข้อมูลปนข้ามบัญชี [ยืนยันแล้ว]
`lib/data/remote/sync_controller.dart:27-36`, `lib/core/router/app_router.dart`

การล้าง DB (`clearAllData` + `resetUserData`) อยู่ที่เดียวคือ `_logout` ในหน้าตั้งค่า — sign-out ที่มาจากทางอื่น (Firebase เพิกถอน token, เปลี่ยนรหัสผ่านเครื่องอื่น, แอปถูก kill ระหว่าง `signOut()` กับ `finally`-wipe) แค่ redirect ไป /login โดยข้อมูลบัญชี A ค้างเต็มเครื่อง → บัญชี B ที่ล็อกอินต่อเห็นข้อมูล A ปนกับของตัวเอง แถวที่ยัง pending ของ A จะถูก **push ขึ้น cloud ของ B** และ watermark เก่าของ A ทำให้ first pull ของ B เป็น incremental ข้ามเอกสารเก่าของ B ถาวร

**แนวแก้:** จำ uid ล่าสุดไว้ (settings key ประจำเครื่อง) แล้วตอน auth-state เปลี่ยนเป็น null/uid ใหม่ที่ไม่ตรง ให้ wipe ก่อนปล่อยเข้า

### C3 — สมัคร/ล็อกอินด้วย Google ไม่ seed หมวดหมู่+บัญชีตั้งต้น [ยืนยันแล้ว]
`lib/features/auth/presentation/login_screen.dart:223-252` เทียบ `_run` บรรทัด 194

`_google()` ไม่ผ่าน `_run` และไม่เรียก `db.seedDefaults()` (email/Apple เรียก) ทั้งที่คอมเมนต์ใน `_run` ระบุว่า login คือจุด seed เดียวของผู้ใช้ Google — เส้นทาง "ออกจากระบบ (DB ถูกล้าง) → บัญชี Google **ใหม่** ล็อกอินเครื่องเดิม" จะได้บัญชีไร้หมวดหมู่/บัญชีเงินถาวร (cloud ว่าง ไม่มีอะไร restore) ซ้ำรอย C1 ของรายงาน 4 ก.ค. แต่คนละเส้นทาง

**แนวแก้:** เรียก `seedDefaults()` ใน `_google` หลัง sign-in สำเร็จ (ปลอดภัยสำหรับผู้ใช้เดิม — seed ใช้ updatedAt 0 แพ้ LWW เสมอ)

---

## ระดับสำคัญ (Major)

### M1 — แก้ไขรายการประจำแล้ว "ไม่ซิงค์เลย" + ถูกเครื่องอื่น revert [ยืนยันแล้ว — เจอโดย 2 agent อิสระ]
`lib/features/recurring/presentation/recurring_rule_sheet.dart:368-382`

Companion ตอน `_save` ไม่ตั้ง `syncStatus` — สำหรับ rule ที่เคย sync แล้ว `insertOnConflictUpdate` จะอัปเดตเฉพาะคอลัมน์ที่มีใน companion → `syncStatus` คง `synced` → `pendingRecurringRules()` ไม่เลือก → ไม่ push ตลอดกาล ซ้ำร้าย `runDue()` ของเครื่องอื่น bump `updatedAt` ของ rule แล้ว push → LWW ทับการแก้ไขในเครื่องนี้ → แก้ยอด 100→500 แล้วเด้งกลับ 100 เอง และตอน logout `hasPendingRows()` มองไม่เห็น → การแก้ไขหายถาวรโดยไม่มีคำเตือน (budget_sheet.dart:402-410 แก้ trap เดียวกันนี้ไว้ถูกแล้ว — ลอก pattern มาได้เลย)

### M2 — สลิปที่ถูกบล็อกเพราะโควต้าหมด จะไม่ถูกอ่านอีกเลย แม้เติมเครดิต/อัป Ultra [ยืนยันแล้ว]
`lib/features/slip/data/slip_importer.dart:143-155` (effectiveCutoff) หักล้าง 364-368 (quotaBlockedAt)

สแกน import จากใหม่→เก่า พอโควต้าหมดกลางแบตช์ รูปใหม่สุดถูก import ไปแล้ว (กลายเป็น watermark) ส่วนรูปเก่ากว่าถูกบล็อก โค้ดตั้งใจถอย cursor ไว้ที่ `blockedAt - 1` เพื่อให้รอบหน้าอ่านซ้ำ **แต่** `effectiveCutoff` เอา max(watermark, cursor) → cutoff ข้ามรูปที่ถูกบล็อกทั้งหมด → ผู้ใช้ Free ที่มีสลิปค้าง 20 ใบ เติมเครดิตมาเพื่ออ่านมันโดยเฉพาะ ก็ไม่มีวันได้ กลไก `oldestErrorAt` (retry รูปที่อ่านพลาด) โดนหักล้างแบบเดียวกัน หมายเหตุ: `test/slip_album_test.dart:46-58` assert พฤติกรรม max นี้ไว้ — ต้องแก้ test พร้อมกัน

**แนวแก้:** ให้ watermark เป็น floor เฉพาะกรณีไม่มี device cursor หรือให้ blocked/error holdback มีอำนาจ cap เหนือ watermark

### M3 — ผู้ใช้ Pro-จากเครดิต ไม่เคยได้รายการประจำอัตโนมัติ [ยืนยันแล้ว]
`lib/features/home/presentation/home_screen.dart:129-135` + `providers.dart:277-287`

`_materialiseRecurring` เช็ค `ref.read(planProvider).canUseRecurring` ณ จังหวะที่ `membershipProvider` (StreamProvider) เพิ่งถูก initialize → `.value` เป็น null → fallback `creditBalance: 0` → Free → `return` ก่อนถึง `runDue()` และเพราะเป็น `ref.read` (ไม่มี listener) stream อาจถูก pause ไม่มีวัน resolve — `runDue` ไม่ถูกเรียกจากที่อื่นเลย ผู้ใช้ dev/Ultra ไม่โดน (fallback resolve ได้จาก settings) เจ้าของแอปจึงทดสอบไม่เจอ

**แนวแก้:** `await ref.read(membershipProvider.future)` ก่อนเช็ค gate

### M4 — ต้นเหตุ warning "setState() called during build" ที่หน้าตั้งค่า [กลไกยืนยันกับ source ของ riverpod]
`providers.dart:263-287` + `settings_screen.dart:58` + `app.dart:27`

Chain `planProvider → membershipProvider → appSettingsProvider` ถูก initialize ด้วย `ref.read` (ไม่มี listener = inactive) ทุกครั้งที่ settings เปลี่ยน (ซึ่งเกิดตลอด: sync bookkeeping, lastSlipReadAt ฯลฯ) invalidation ค้างสะสมเพราะ scheduler ของ Riverpod 3 ข้าม element ที่ inactive → พอเปิดหน้าตั้งค่า `ref.watch(planProvider)` flush การ rebuild ค้างทั้งหมด **กลางการ build ของ SettingsScreen** → `setState` บน root UncontrolledProviderScope → exception (จับได้/ไม่พัง แต่ spam log ทุกครั้งที่เปิดหน้าตั้งค่า)

**แนวแก้ (บรรทัดเดียว):** เพิ่ม `ref.watch(membershipProvider);` ใน `MoneyBunApp.build` ข้าง `ref.watch(syncControllerProvider)` — ให้ chain มี listener ถาวร invalidation จะถูก flush ตอนต้นเฟรมแทนกลาง build (และช่วยพราง M3 แต่ควรแก้ M3 ตรงๆ ด้วย)

### M5 — เครื่องที่ออฟไลน์เกิน 7 วัน: ข้อมูลที่จดไว้ push ขึ้น cloud แล้ว แต่เครื่องอื่น "ไม่มีวันดึงเจอ"
`lib/data/remote/sync_engine.dart` (`_pushDoc` ใช้ updatedAt เดิม + `_incrementalPull` ดึงเฉพาะ `updatedAt > watermark − 7d`)

เครื่อง A ออฟไลน์ 30 วันแล้วกลับมา push เอกสารที่ stamp เวลาเก่า → query ของเครื่อง B (watermark = วันนี้) ไม่มีวัน return เอกสารเหล่านั้น → B ขาดข้อมูลถาวรแบบเงียบๆ (reinstall/full pull เท่านั้นที่กู้ได้) — margin 7 วันออกแบบไว้กัน clock skew ไม่ได้กันระยะออฟไลน์

**แนวแก้:** ตอน push เอกสารที่ updatedAt เก่ากว่า margin ให้ re-stamp เป็น server time (หรือเก็บ `pushedAt` แยก field แล้ว query จากมัน)

### M6 — Crash ในจังหวะแคบทำให้ sync ติดลูป PERMISSION_DENIED ถาวร (ผู้ใช้ Ultra) [น่าเชื่อ]
`sync_engine.dart:486-489` + `firestore.rules` write carve-out ของ `ultraUntil`

`ultraUntil` อยู่ใน syncedSettingsKeys (push ได้) แต่ rules ห้าม client เขียน — ปกติ pull จะ mark ว่า pushed แล้วก่อน แต่ถ้าแอปตายระหว่าง `upsertPulledSetting` กับ `markSettingPushed` แถวจะค้างสถานะ pending → `_pushSettings` ทุกรอบพยายาม push → โดน deny → `sync()` คืน false ตลอดไป → scanner ถูก gate ถาวร (จนกว่าจะ sign out)

**แนวแก้:** ตัด `ultraUntil` ออกจาก push list (client ไม่มีสิทธิ์เขียนโดย design อยู่แล้ว) + ทำสองคำสั่งนี้ใน transaction เดียว

### M7 — แถวสรุปหมวด/แท็กในหน้าสถิติล้นแนวนอน (pattern เดียวกับที่เพิ่งแก้หน้าแพลน) [ยืนยันจาก code quote]
`lib/features/stats/presentation/stats_screen.dart:666-680` (_CategoryBar), `:713-724` (_TagBar)

`Row(spaceBetween)` ที่ Text ชื่อหมวด (ผู้ใช้ตั้งเองได้ยาวๆ) + Text จำนวนเงิน ไม่มี `Flexible`/`ellipsis` → ชื่อไทยยาว + ยอดหลักหมื่น = RenderFlex overflow (`_BudgetBar` ใน budget_screen.dart:270-279 ทำถูกแล้ว — ลอก pattern) จุดเสี่ยงเดียวกันอีกสอง: badge เปอร์เซ็นต์หัวหน้าสถิติ (`:125,162-173` — 199900% ได้ถ้าฐานเดือนก่อนเล็ก) และ `_TappedSummary` ใน comparison_screen.dart:265-285

### M8 — สลิปคนละใบถูกมองเป็นใบเดียวกัน เพราะ OCR หยิบ "เลขบัตรที่ถูก mask" มาเป็น transRef [น่าเชื่อ]
`lib/features/slip/data/slip_extractor.dart:158-168`

`_firstRef` จับ `[A-Z0-9]{10,30}` ตัวแรก — `XXXXXXXXXXXX1234` (เลขบัตร mask) มักอยู่เหนือเลขอ้างอิงจริงบนสลิป และผ่านเงื่อนไข "มีทั้งตัวเลข+ตัวอักษร" พอดี → สลิปจ่ายบัตรใบที่สองที่ mask เหมือนกัน (ไม่มี QR ให้อ่าน) โดน dedup ข้ามอย่างเงียบๆ ไม่ import

**แนวแก้:** blacklist token ที่มี X≥4 ตัวติดกัน / ให้น้ำหนัก token ที่อยู่ใกล้คำว่า "เลขที่รายการ/Ref"

### M9 — ครอบครัว race ตอน logout: งานค้างเขียนทับหลัง wipe [น่าเชื่อ — เจอสอดคล้องกัน 3 agent]
`sync_engine.dart` (ทุก `_pullX`: เช็ค `_sameUser` แล้วมี await ก่อน `_saveWatermark` โดยไม่เช็คซ้ำ), `providers.dart:144-147` (`syncAvatarFromCloud`/`creditsService.refresh` แบบ unawaited ไม่เช็ค uid ตอนจบ), `settings_screen.dart:249-256`

Sync/callback ที่คร่อม `clearAllData()` อยู่สามารถ: (a) เขียน watermark เก่ากลับ → restore รอบถัดไปขาดท่อน, (b) เขียนแถวบัญชีเก่ากลับเข้า DB ที่เพิ่งล้าง, (c) `setAvatarPath` ของ A หลัง wipe → B เห็นรูปโปรไฟล์ของ A (`restoreAvatarPath` มี early-return เมื่อ pointer ชี้ไฟล์จริง เลยไม่ทับคืน), (d) `setFirstSyncDone(true)` หลัง wipe → scanner gate เปิดก่อน restore → สลิปซ้ำ

**แนวแก้:** generation token (นับทุกครั้งที่ auth เปลี่ยน) ให้ทุกงาน async จับไว้ตอนเริ่มและเช็คก่อน "ทุกการเขียน" ไม่ใช่แค่ตอนเริ่ม

---

## ระดับรอง (Minor) — เรียงตามความน่าแก้

1. **Album keyword จับพลาดด้วย substring** — `'kma'`⊂"Bookmarks", `'citi'`⊂"Cities", `'prompt'`⊂"Prompts" (slip_importer.dart:161-192) → import ทั้งอัลบั้มเป็นรายจ่าย + เผาโควต้า ควร match แบบ word-boundary
2. **รูป photoTakenAt=0 หลุด loophole โควต้า** — importer เก็บ 0 (ไม่ใช่ NULL) แต่ predicate ฝั่ง DB กัน NULL เท่านั้น (database.dart:580-584 vs slip_importer.dart:470-473) → นับโควต้าตอนสแกนแต่คืนเงินเงียบๆ ในบัญชีถาวร
3. **สลิป+รายการเขียนไม่ atomic** — crash ระหว่าง `_slips.save` กับ `_txns.save` (slip_importer.dart:470-484) = orphan กินโควต้า + assetId dedup ทำให้ไม่ retry ตลอดกาล → ครอบด้วย DB transaction
4. **Snackbar "กำลัง restore" ตาย** — เงื่อนไข if/else ซ้ำกัน byte-ต่อ-byte (home_screen.dart:346,354) → สาขาที่สองไม่มีวันถึง
5. **`_google` โชว์ error ตอนผู้ใช้แค่ปิด account chooser** — ขาด `isAuthCancelled` ที่ `_run` มี (login_screen.dart:245-249)
6. **Apple sign-in ทิ้งชื่อที่ได้ครั้งเดียว** — ไม่อ่าน `givenName/familyName` (auth_service.dart:131-155); Apple ไม่ส่งซ้ำ → displayName เป็น "คุณบัน" ตลอด
7. **Double-tap "ออกจากระบบ" ซ้อน dialog ได้** — `_loggingOut` ตั้งหลัง await แรก (settings_screen.dart:215-228); ยืนยันตัวค้างทีหลัง = wipe ซ้ำทับบัญชีใหม่ได้
8. **Wiggle AnimationController repeat() ตลอดชีวิตหน้า** — ticker 60fps แม้ไม่ได้อยู่โหมดแก้ไข (category_tag_board.dart:371-374, 772-775) → เปลืองแบตบนเครื่องเป้าหมาย
9. **ชื่อธนาคารตรึงภาษาไทยใน locale EN** — `.nameTh` ตายตัว (account_flow.dart:39-40, accounts_sheet.dart:106)
10. **TextEditingController รั่ว** ใน profile `_editField` (profile_screen.dart:200-226) + dispose เร็วเกินใน dialog หลายจุด (add_transaction_sheet.dart:417, category_tag_board.dart:228,259,298)
11. **`ref.read`/`setState` หลัง await ไม่เช็ค mounted** ~10 จุด (stats_screen.dart:377,387; category_tag_board.dart:273; budget_screen.dart:188; budget_sheet.dart:375; recurring_rule_sheet.dart:333; add_transaction_sheet.dart:432-445 ฯลฯ) — โค้ดเบสมี pattern ถูกต้องอยู่แล้ว แค่บางจุดไม่ตาม
12. **membershipProvider ไม่ recompute ตามเวลา** — เปิดแอปค้างข้ามรอบรีเซ็ต/Ultra หมดอายุ ตัวเลขค้าง (providers.dart:263-272; enforcement จริงไม่กระทบ)
13. **ผู้ใช้ referral ระบบเก่า (v1) นับเป็น "ใหม่" ใน v2** — redeem ได้อีกรอบ (อาจเป็น migration choice ที่ยอมรับได้ — เจ้าของตัดสิน)
14. **Device hash แตกสองค่าได้** ถ้า android_id plugin ล้มเหลวชั่วคราว (device_id_service.dart:39-53) → redeem ซ้ำเครื่องเดิมได้
15. **แก้แล้วออฟไลน์: recurring ไม่ materialise ทั้ง session** — ไม่มี `firstSyncDone` bypass แบบที่ scanner มี (home_screen.dart:129-136) + `_bootFlow` ค้างทั้ง launch ถ้า tour ยังไม่เห็น+ออฟไลน์ (home_screen.dart:54-79)
16. **migration v5 reskin stamp updatedAt ใหม่ทั้งแถว** — เครื่องอัปเกรดช้า revert ชื่อหมวดที่เครื่องอื่นเพิ่งแก้ (database.dart:108-124; historical แต่ pattern ต้องจำ)
17. **สลิปข้ามเดือนที่ถูกบล็อกหาย** — cutoff ไม่ถอยก่อนต้นเดือนปัจจุบัน (slip_importer.dart:148) ขัดกับ comment ที่สัญญาว่า "เดือนหน้าเก็บให้"
18. **CRC ที่บังเอิญเท่ากับ 0x6304** ทำ validate พลาด (tlv_parser.dart:101-108; โอกาส 1/65536 กระทบแค่ confidence bonus)
19. **first-sync skeleton ไม่โชว์ให้บัญชีที่สองใน session เดียว** — `_firstSyncStarted` ไม่ reset ตอน sign-out (sync_controller.dart:89)
20. **redeem +300 นับซ้ำชั่วคราว** ถ้า refresh พื้นหลังชิงตัดหน้า (referral_screen.dart:144-149; self-healing)

## ตรวจแล้วสะอาด (ไม่พบปัญหา)

- คณิต `QuotaPeriod` ทุก edge (สมัคร 29/30/31 ม.ค., ปีอธิกสุรทิน, ธ.ค.→ม.ค., เที่ยงคืนพอดี, timezone)
- Redeem batch 4-doc vs rules getAfter/existsAfter — ล็อกกันครบ, A↔B พร้อมกัน serialize ถูก
- `deviceIdFallback` รอด signout ครบทุกเส้นทาง; cache ทุก key ถูกล้างตอน signout ถูกต้อง
- Firestore rules: LIST ทุก query ผ่าน (carve-out อยู่ฝั่ง write เท่านั้น — บทเรียน 8e4bd16 ถูกใช้ถูกแล้ว)
- Mapper ทุก collection field ตรงกัน; เงินเป็น int cents สองฝั่ง; ไม่มี TZ conversion
- ปี พ.ศ./ค.ศ. ใน extractor + วันที่เป็นไปไม่ได้ถูก reject; ARB th/en คีย์+placeholder ตรงกันหมด
- Double-tap guard ในชีตหลักครบแล้ว (แก้ตามรายงาน 4 ก.ค. แล้วจริง); tombstone GC 90 วัน vs margin 7 วันถูกต้อง
- การเว้น `awaitInitialSync` ไม่มี timeout escape หลุดกลับมา (invariant ยังศักดิ์สิทธิ์)
