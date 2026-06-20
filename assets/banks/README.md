# Bank logos

Logos shown in the "which banks to scan" sheet, used only to identify each bank
(nominative use). Each file is named `<id>.png`, matching a `BankCatalog` id in
`lib/core/constants/bank_catalog.dart` (e.g. `kbank.png`, `ghb.png`).

- Source: the open-source set `casperstack/thai-banks-logo` (see the project's
  `thai_banks_reference.json` for codes, brand colours and logo sources).
- The logos are trademarks of their respective owners; they are not modified and
  are used only to identify the bank, not to imply any endorsement or affiliation.

If an id has no `<id>.png` here (e.g. `make`, `truemoney`, `paotang`), the app
falls back to a brand-coloured badge with the bank's short name
(see `lib/core/widgets/bank_logo.dart`). To add a real logo, drop `<id>.png`
into this folder and rebuild.
