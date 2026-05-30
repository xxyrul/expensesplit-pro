# ExpenseSplit Pro — FYP Report Section

## Purpose
ExpenseSplit Pro is a receipt-tracking system with OCR-based receipt parsing, vendor intelligence, and an admin dashboard for reviewing OCR corrections and maintaining a global vendor dictionary.

## Architecture (high level)
- Mobile app (Flutter): receipt scanning, add/edit expenses, local UI.
- Admin web (Flutter web): OCR review queue, vendor intelligence hub, expense management.
- Backend: Cloud Firestore (users/{uid}/expenses, users/{uid}/ocr_logs, ocr_learning, vendor_catalog).

## Key components and files
- OCR parsing: `lib/services/receipt_scanner_service.dart`
- Vendor intelligence: `lib/services/vendor_intelligence_service.dart`
- Admin OCR review: `admin_web/lib/screens/ocr_review_queue.dart`
- Global vendor dictionary: `admin_web/lib/services/vendor_dictionary_service.dart`

## Running and switching Firebase projects
- Admin web uses environment defines. Example:
```bash
flutter run -t lib/main_admin.dart -d chrome \
  --dart-define=FIREBASE_API_KEY=YOUR_API_KEY \
  --dart-define=FIREBASE_APP_ID=YOUR_APP_ID \
  --dart-define=FIREBASE_PROJECT_ID=YOUR_PROJECT_ID 
```
If omitted, the app uses the generated `DefaultFirebaseOptions`.

## Data repair tool
- File: `tools/repair_expenses.js` — scans `users/*/expenses` and writes `repair_report.csv`.
- To run report-only:
```bash
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
npm install
node tools/repair_expenses.js --report repair_report.csv
```
- To apply patches (after reviewing report):
```bash
node tools/repair_expenses.js --report repair_report.csv --apply
```
- The script will back up original values into `metadata.originalVendor` and `metadata.originalAmount` before patching.

## Tests
- Unit tests for OCR parsing: `test/receipt_scanner_test.dart` (run with `flutter test`).

## Next recommendations
- Add CI to run `flutter test` on PRs.
- Add a staging Firestore project for safe testing and a dashboard to display active project.
