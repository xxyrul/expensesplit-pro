# ExpenseSplit Pro Admin Dashboard Setup Guide

## Overview

The ExpenseSplit Pro Admin Dashboard is a Flutter Web application that provides administrative functionality for managing the ExpenseSplit Pro platform. It shares the same Firebase backend with the mobile app but offers specialized tools for platform management, user oversight, and data analysis.

## Architecture

### Project Structure

```
lib/
├── admin/                          # Admin dashboard code
│   ├── admin_app.dart             # Root widget with security guard
│   ├── theme/
│   │   └── admin_theme.dart       # Dark teal theme and Material customization
│   ├── services/
│   │   └── admin_auth_service.dart # Admin authentication & role checking
│   ├── providers/
│   │   └── admin_providers.dart    # Riverpod state management
│   └── screens/
│       ├── login_screen.dart       # Firebase email/password auth
│       ├── dashboard_shell.dart    # Main layout with navigation
│       ├── overview_screen.dart    # KPI dashboard and charts
│       ├── user_directory_screen.dart # User management table
│       ├── merchant_intelligence_screen.dart # Vendor catalog management
│       └── system_logs_screen.dart # OCR audit logs
├── main.dart                       # Mobile app entry point
└── main_admin.dart                 # Admin dashboard entry point
```

### Key Technologies

- **Flutter**: Cross-platform UI framework
- **Firebase Auth**: Email/password authentication shared with mobile app
- **Cloud Firestore**: Real-time database for users, expenses, budgets, etc.
- **Riverpod**: State management with StreamProvider for real-time data
- **google_fonts**: Typography (Poppins font family)
- **fl_chart**: Data visualization (pending implementation)
- **Material 3**: Design system with dark theme customization

## Running the Admin Dashboard

### Prerequisites

1. **Flutter SDK**: 3.41.8 or compatible version
2. **Dart SDK**: 3.8.1+
3. **Firebase Project**: Same project configured for mobile app
4. **Admin Account**: User document with `role: 'admin'` in Firestore

### Launch Instructions

#### Option 1: Flutter Web (Recommended for Admin)

```bash
# Run admin dashboard on web
flutter run -t lib/main_admin.dart -d chrome

# Or with release mode for performance
flutter run -t lib/main_admin.dart -d chrome --release
```

#### Option 2: Flutter Desktop (Linux/macOS/Windows)

```bash
# Run on desktop platform
flutter run -t lib/main_admin.dart -d linux
flutter run -t lib/main_admin.dart -d macos
flutter run -t lib/main_admin.dart -d windows
```

#### Option 3: Specify Build Configuration

```bash
# Build for web
flutter build web -t lib/main_admin.dart

# Build for macOS
flutter build macos -t lib/main_admin.dart
```

## Authentication & Authorization

### Admin Setup Process

1. **Create Admin Account**:
   - Create a user account via mobile app or through Firebase Console
   - User email: `admin@expensesplit.com`

2. **Grant Admin Role**:
   - Navigate to Firestore console
   - Edit user document in `users/{userId}`
   - Add field: `role: "admin"`

3. **Login to Dashboard**:
   - Navigate to admin dashboard URL
   - Enter admin credentials
   - System validates `role == "admin"`

### Authentication Flow

```
unauthenticated → Login Screen → Firebase Auth → Check Role
                                                 ├→ Admin Role → Dashboard
                                                 └→ User Role → Access Denied
```

**Code Reference**: [admin_app.dart](lib/admin/admin_app.dart) - Security guard in `build()` method

## Admin Dashboard Features

### 1. Overview Screen
**Purpose**: Real-time KPI summary and platform analytics

**Features**:
- Total Platform Users (count from `users` collection)
- Active Monthly Liquidity (aggregated from expenses)
- Average OCR Accuracy (calculated from `ocr_logs`)
- Critical Budget Alerts (count of alerts > 80% threshold)

**Data Source**: Firestore collections
- `users` - user count
- `expenses` - sum by category
- `ocr_logs` - accuracy calculation
- `budget_alerts` - critical count

**Pending**: fl_chart implementation for "Platform Spend per Category" bar chart

### 2. User Directory Screen
**Purpose**: User management and activity monitoring

**Features**:
- Real-time user search (name, email)
- Pagination with DataTable
- User status: Active/Restricted
- Total expenses per user

**Columns**:
| Column | Source | Purpose |
|--------|--------|---------|
| Name | users.displayName | User identification |
| Email | users.email | Contact/authentication |
| Total Expenses | Sum of expenses by userId | Activity metric |
| Status | users.status | Moderation indicator |

**Pending**: 
- Real Firestore integration
- Debounced search filtering
- Pagination with sort support

### 3. Merchant Intelligence Screen
**Purpose**: Global vendor catalog management

**Features**:
- Add/Edit/Delete merchant mappings
- Category assignment (Food & Drinks, Transport, etc.)
- Search existing merchants
- Real-time sync with `vendor_catalog` collection

**Firestore Structure**:
```
vendor_catalog/{merchantId}
├── name: "Zus Coffee"
├── category: "Food & Drinks"
├── createdAt: timestamp
└── createdBy: adminId
```

**Pending**:
- Firestore CRUD operations
- Real-time search with debounce

### 4. System Logs Screen
**Purpose**: OCR audit logging and correction tracking

**Features**:
- Filter OCR scans where user correction > 10%
- Side-by-side comparison: "System Extracted Value" vs "User Entered Value"
- Severity highlighting (High: >20%, Medium: 10-20%, Low: <10%)
- Search and export functionality

**Firestore Query**:
```dart
ocr_logs.where('userCorrection', '>', 10)
  .orderBy('timestamp', descending: true)
  .limit(50)
```

**Data Structure**:
```
ocr_logs/{logId}
├── systemExtractedValue: "RM 125.50"
├── userEnteredValue: "RM 125.55"
├── userCorrection: 0.15  // 15% difference
├── timestamp: datetime
└── userId: userId
```

## Theme & Styling

### Color Palette

| Purpose | Color | Hex Code |
|---------|-------|----------|
| Primary | Deep Teal | #004D40 |
| Accent | Light Teal | #00BCD4 |
| Surface | Dark Gray | #242424 |
| Text Light | Off-White | #ECEFF1 |
| Text Secondary | Gray | #7A8E99 |
| Success | Green | #4CAF50 |
| Warning | Orange | #FFA726 |
| Error | Red | #EF5350 |

**Reference**: [admin_theme.dart](lib/admin/theme/admin_theme.dart)

### Typography

- **Font Family**: Poppins (via google_fonts)
- **Heading Sizes**: 18pt (title), 16pt (section), 14pt (card)
- **Body Sizes**: 14pt, 12pt, 11pt
- **Weights**: 600 (bold), 500 (semi), 400 (regular)

## State Management (Riverpod)

### Key Providers

**Authentication**:
```dart
// Check if user is authenticated and is admin
isAdminProvider  // FutureProvider<bool>

// Watch current user profile
adminAuthStateProvider  // StreamProvider<UserModel?>

// Access to auth service
adminAuthServiceProvider  // Provider<AdminAuthService>
```

**Navigation**:
```dart
// Current dashboard section
currentAdminSectionProvider  // StateProvider<AdminSection>

// AdminSection enum: { overview, userDirectory, merchantIntelligence, systemLogs }
```

**Reference**: [admin_providers.dart](lib/admin/providers/admin_providers.dart)

## Integration Checklist

### Pending Implementations (Priority Order)

- [ ] **System Logs Screen Data Integration**
  - Query `ocr_logs` collection filtered by userCorrection > 10%
  - Implement Firestore listener
  - Add search/export functionality

- [ ] **Overview KPI Integration**
  - Aggregate users count
  - Calculate monthly liquidity sum
  - Compute OCR accuracy percentage
  - Count critical alerts
  - Implement fl_chart bar chart for spend by category

- [ ] **User Directory Real-Time Integration**
  - Query users collection with search parameter
  - Implement PaginatedDataTable with sorting
  - Add debounced search filtering
  - Real-time status updates

- [ ] **Merchant Catalog CRUD**
  - Create Firestore service for vendor operations
  - Implement add/edit/delete handlers
  - Real-time list synchronization
  - Form validation and error handling

- [ ] **Search & Filtering**
  - Implement debounced search across all screens
  - Add filtering by date range (logs, transactions)
  - Status filter for users (active, restricted)

- [ ] **Data Export**
  - CSV export for user directory
  - PDF reports for system logs
  - Dashboard snapshots

- [ ] **Charts & Visualization**
  - Integrate fl_chart for KPI visualization
  - Implement "Spend by Category" bar chart
  - Add trend charts for user growth

- [ ] **Performance Optimization**
  - Firestore indexing for efficient queries
  - Pagination for large datasets
  - Caching strategy for KPI cards

## Firestore Security Rules

The admin dashboard requires specific security rule patterns:

```javascript
// Admin dashboard access
match /users/{userId} {
  allow read: if request.auth.uid == userId || 
              get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
  allow update: if request.auth.uid == userId || 
                get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
}

// Admin-only collections
match /ocr_logs/{document=**} {
  allow read: if get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
}

match /vendor_catalog/{document=**} {
  allow write: if get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
}
```

## Deployment

### Deploy Admin Dashboard to Firebase Hosting

```bash
# Build for production
flutter build web -t lib/main_admin.dart --release

# Deploy to Firebase Hosting
firebase deploy --only hosting
```

### Firebase Hosting Configuration

Create `firebase.json` with separate deploy targets for mobile and admin:

```json
{
  "hosting": {
    "admin": {
      "public": "build/web",
      "site": "expensesplit-admin"
    }
  }
}
```

Deploy with:
```bash
firebase deploy --only hosting:admin
```

## Troubleshooting

### Common Issues

**1. "Access Denied" After Login**
- Verify user document has `role: "admin"` in Firestore
- Check Firebase Auth user exists and email matches

**2. Firestore Read/Write Errors**
- Check security rules allow admin access
- Verify Firestore indexes exist for filtered queries
- Check network connectivity

**3. Performance Issues on Large Datasets**
- Implement pagination for user directory
- Add Firestore indexing for common queries
- Use StreamProvider with `.limit(50)` for logs

**4. UI Not Updating**
- Verify Riverpod provider is correctly invalidated after mutations
- Check StreamProvider is listening to collection changes
- Use `.watch()` on provider in ConsumerWidget

## Monitoring & Maintenance

### Regular Tasks

1. **Monthly**: Review OCR correction logs for pattern analysis
2. **Weekly**: Check critical budget alerts count and trends
3. **Daily**: Monitor admin dashboard access logs

### Metrics to Track

- OCR accuracy trend
- User growth rate
- Platform liquidity health
- Most common merchants
- Categories with highest spending

## Support & Documentation

### Related Files
- Mobile settings: [lib/screens/home/settings_view.dart](lib/screens/home/settings_view.dart)
- User model: [lib/models/user_model.dart](lib/models/user_model.dart)
- Firebase config: [lib/firebase_options.dart](lib/firebase_options.dart)

### External Resources
- [Flutter Web Documentation](https://flutter.dev/multi-platform/web)
- [Firebase Cloud Firestore Queries](https://firebase.google.com/docs/firestore/query-data/queries)
- [Riverpod Documentation](https://riverpod.dev/)
- [Material Design 3](https://m3.material.io/)
