# Changelog

## [1.0.12+14] - 2026-06-06
### Fixed
- Fixed massive UI stuttering and frame drops by removing redundant internal animations across the app.
- Eliminated all loading lags when navigating between bottom tabs by removing the heavy AnimatedSwitcher container.
- Completely replaced legacy PageRouteBuilder custom transitions with native, fully-optimized MaterialPageRoute transitions for the Camera Scanner and Settings screens.
- Enabled instant image loading for all receipt thumbnails by utilizing a zero-fade CachedNetworkImage implementation.
## [1.0.11+13] - 2026-06-05
### Added
- Implemented a new sleek Month Selector in the Expenses view, replacing the Category Filter based on the Stitch design mockup.
- Grouped transactions in the Expenses view by relative dates (e.g. "Today", "Yesterday").
### Changed
- Dramatically improved "Add Expense" performance by decoupling blocking AI network calls from the UI thread.
- Updated the AI Advisor loading toast notification to use consistent dark-theme styling instead of the default Android pink color.
### Fixed
- Fixed AI Advisor insight generation to accurately pull statistics for the selected historical month instead of strictly the current month.
## [1.0.10+12] - 2026-06-05
### Fixed
- Fixed timezone parsing bug in AI Insights generation function.
- Fixed UI inconsistencies with the Add Expense screen's Merchant vendor field inner border.
- Corrected text wrapping issues on long Category tags (e.g., "Entertainment").
### Changed
- Replaced the live-view camera for receipt attachment with an interactive bottom sheet modal supporting both Camera and Gallery inputs.
- Redesigned the snackbar notifications in Reports & Insights for higher contrast and readability.

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
