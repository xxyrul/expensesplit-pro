# Changelog

## [1.0.6+7] - 2024-10-24
### Added
- Implemented Clean Architecture: migrated Firebase data operations into dedicated Repository classes (Expense, Budget, Goal, Debt).
- Reorganized state management: extracted Riverpod providers into a dedicated `providers` module with proper lifecycle management (`autoDispose`).
- Added `getMonthlyTrend` analytical function to automatically aggregate monthly expenses by category.
- Exposed comprehensive CSV Export functionality for user transactions via a dedicated provider.

### Changed
- Improved code maintainability by separating business logic (Services) from data access (Repositories).
- Refactored UI files to elegantly consume decoupled providers.
