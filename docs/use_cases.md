# Use Case Mapping — ExpenseSplit Pro

This document maps the project's primary use cases (from the supplied diagram) to the repository files that implement them.

## Overview
- Purpose: Receipt scanning, OCR parsing, expense tracking, vendor intelligence and admin moderation.

## Use cases and code mapping

- Login / Register
  - Files: `admin_web/lib/screens/auth/admin_login_screen.dart`, `lib/services/auth_service.dart`

- Scan receipt / OCR
  - Files: `lib/screens/home/camera_scanner_view.dart`, `lib/services/receipt_scanner_service.dart`, `lib/utils/receipt_processing_ui.dart`

- Add expense (manual or prefilled from scan)
  - Files: `lib/screens/home/add_expense_screen.dart`, `lib/services/expense_service.dart`, `lib/models/expense_model.dart`

- Edit / Delete expense
  - Files: `lib/screens/home/add_expense_screen.dart`, `admin_web/lib/screens/expense_management.dart`, `lib/services/expense_service.dart`

- Auto-categorize vendor / Vendor intelligence
  - Files: `lib/services/vendor_intelligence_service.dart`, `admin_web/lib/screens/vendor_intelligence_hub.dart`, `admin_web/lib/widgets/vendor_learn_dialog.dart`

- Review OCR correction queue (admin)
  - Files: `admin_web/lib/screens/ocr_review_queue.dart`, `lib/models/ocr_log_model.dart`

- Manage global vendor catalog (admin)
  - Files: `admin_web/lib/screens/vendor_intelligence_hub.dart`, `admin_web/lib/services/vendor_dictionary_service.dart`

- Audit logs / Anomaly alerts
  - Files: `admin_web/lib/screens/anomaly_alerts.dart`, `admin_web/lib/services/audit_log_service.dart`

## How to navigate this mapping
- Each admin screen is under `admin_web/lib/screens/`.
- Core services shared with mobile reside in `lib/services/` and `lib/models/`.

If you want, I can add direct links with line numbers to specific functions next.
