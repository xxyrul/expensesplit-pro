# Changelog

## [1.0.7+9] - 2026-06-04
### Added
- Integrated Firebase Storage for Receipt Image Uploads directly into the mobile application.
- Created robust ReceiptPickerWidget with thumbnail preview and bandwidth-saving compression capabilities.
- Added `receiptImageUrl` tracking securely into `ExpenseModel` and Firestore backend.
### Changed
- Removed hardcoded conditional action buttons in the OCR Review Queue to allow dynamic re-processing.
- Updated Admin Action Notifier to accurately track and revert Approved/Rejected scans back to 'Pending' for correction.
- Upgraded OCR Vendor parsing with deep fallback mappings to intelligently detect and eliminate missing vendor names.
### Fixed
- Fixed layout overflows and bounds issues in the Dashboard UI.
- Solved Firebase Security Rules bug that improperly denied Admins write access to user logs and audit trails.

## [1.0.6+7] - 2024-10-24
### Added
- Implemented Clean Architecture: migrated Firebase data operations into dedicated Repository classes (Expense, Budget, Goal, Debt).
- Reorganized state management: extracted Riverpod providers into a dedicated `providers` module with proper lifecycle management (`autoDispose`).
- Added `getMonthlyTrend` analytical function to automatically aggregate monthly expenses by category.
- Exposed comprehensive CSV Export functionality for user transactions via a dedicated provider.

### Changed
- Improved code maintainability by separating business logic (Services) from data access (Repositories).
- Refactored UI files to elegantly consume decoupled providers.
