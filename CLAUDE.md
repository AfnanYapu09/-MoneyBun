# MoneyBun — CLAUDE.md

Thai income/expense tracker ("แอปจดรายรับรายจ่ายด้วยสลิป/QR"). Flutter + Riverpod 3 + Drift (local-first) + Firebase (auth/sync). Repo: `AfnanYapu09/-MoneyBun`. The owner communicates in Thai — reply in Thai, keep code/comments in English.

## ⚠️ Traps that have wasted whole sessions

- **Nested stale copy**: `-MoneyBun/-MoneyBun/` is an OLD untracked copy (gitignored via `/-MoneyBun/`). It poisons `flutter analyze` and grep output — **always filter out paths containing `-MoneyBun\-MoneyBun`**. Never edit files there. Another stale copy lives at `C:\Users\Lenovo\StudioProjects\-MoneyBun`.
- **Firestore rules**: excluding a doc-id from a collection's READ rule (e.g. `!(docId == 'ultraUntil')`) denies every LIST query over that collection — rules are not filters. This broke ALL settings sync in production once. Only carve doc-ids out of WRITE rules; reads stay whole-collection.
- **Debug cold start is 4–6s (blank splash)** on the test phone — that is NOT a bug. Verify startup speed on `flutter build apk --release` (<1s) before diagnosing.
- **"Lost connection to device"** during `flutter run` is routine on the test phone; the app keeps running. Paired Firebase sign-out/sign-in seconds apart in logcat = redeploy shuffle, not real session loss.

## Commands

```bash
flutter pub get
flutter test                          # run BEFORE on-device verification
flutter analyze                       # ignore hits under -MoneyBun\-MoneyBun\
flutter run -d 099304033R001598       # Infinix X6831, Android 13 (owner's test phone)
flutter build apk --release           # release perf checks
flutter build appbundle --release     # Play Store .aab (needs android/key.properties)
flutter gen-l10n                      # after editing lib/l10n/app_*.arb
dart run build_runner build --delete-conflicting-outputs   # after Drift table changes
```

adb: `C:\Users\Lenovo\AppData\Local\Android\Sdk\platform-tools\adb.exe`

## Architecture (lib/)

- `main.dart` / `app.dart` — entry; `bootstrap/providers.dart` — **all Riverpod providers are manual** (no codegen); `bootstrap/firebase_options.dart`.
- `data/local/` — Drift database (source of truth). Tables in `data/local/tables/`. Regenerate `database.g.dart` with build_runner.
- `data/remote/` — `auth_service.dart` (Google/Apple sign-in; web client id hardcoded intentionally), `sync_engine.dart` + `sync_controller.dart` (Firestore sync), `firestore_mappers.dart`.
- `data/repositories/` — repository layer between providers and DB.
- `features/<name>/` — feature-first UI: home, slip (scanner), plan (membership), settings, stats, transactions, add_transaction, accounts, categories, tags, recurring, auth, onboarding, splash.
- `core/` — router (go_router), theme, shared widgets, utils.
- `l10n/` — ARB files, **th is the template**, en secondary. Generated files under `l10n/generated/`.
- Root: `firestore.rules`, `firestore.indexes.json`, `docs/reviews/` (past audit reports).

## Hard invariants — do not undo

- **No shared_preferences.** All persisted settings go through the Drift Settings table via `SettingsKeys` + `SettingsRepository`.
- **Slip scanner + recurring materialisation are gated behind `SyncController.awaitInitialSync()`** (completes only when a sync really ran). Do NOT add timeout escapes — that caused duplicate slip imports on login.
- **Profile photo sync uses NO Firebase Storage** (owner has no Blaze plan): base64 in the synced `avatarImage` settings doc, materialised to a local file after each full sync. Don't propose firebase_storage for small blobs.
- **Slip reading is fully on-device** (QR + ML Kit Latin OCR). No server-side OCR.
- **Referral device lock** uses `android_id` package (true ANDROID_ID). NOT `device_info_plus` — its `.id` is `Build.ID` (wrong value).
- Wordmark font: Fraunces VARIABLE (`FrauncesVar`), FontVariation opsz 144 / WONK 1.

## Membership v2 (features/plan/)

- Free = 30 scans per **personal cycle** anchored to day-after-signup (auth `creationTime`, month-end clamped) — see `QuotaPeriod` in `lib/features/plan/domain/`.
- Pro = permanent referral credits (+300 both sides, never expire, free quota consumed first). Fully **derived** from Firestore docs + local slips — no stored counters. `proMonth` is RETIRED (key kept only for cleanup).
- Redeem = atomic 4-doc Firestore batch verified by `getAfter`/`existsAfter` in rules. Redeemer must be NEW (never redeemed and never been redeemed-from).
- Ultra = console-set `ultraUntil` (unlimited).
- Session caches in settings (`creditsGranted`, `hasRedeemed`, `hasReferred`, `signupAtMs`) are cleared on signout, but `deviceIdFallback` must SURVIVE signout.

## Testing & device workflow

- The owner tests on the physical phone personally — **don't inject adb taps while they're mid-flow**; check `dumpsys window | grep mCurrentFocus` is `com.moneybun.moneybun` before any tap.
- Verify with `flutter test` first, on-device screenshots second. The owner wants every feature verified with a screenshot.
- Uninstall-for-testing is acceptable (data restores from cloud after Google login).
- Release builds sign with the real upload keystore (`android/app/upload-keystore.jks` + `android/key.properties`, both gitignored; falls back to debug signing when absent). **The owner holds the only copy** — never regenerate or overwrite it.
- `google-services.json` is gitignored; refresh via Firebase CLI (`firebase apps:android:sha:create` / `apps:sdkconfig`, project `studio-3816117841-f3521`).
