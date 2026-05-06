# Admin Dashboard Developer Guide

## Quick Start

### 1. Launch Admin Dashboard
```bash
# Web (Chrome)
flutter run -t lib/main_admin.dart -d chrome

# Desktop (macOS/Linux/Windows)
flutter run -t lib/main_admin.dart -d macos
```

### 2. Login Credentials
- Email: `admin@expensesplit.com`
- Password: (same as Firebase Auth password)
- Requirement: Firestore user document must have `role: "admin"`

### 3. Navigation
- **Overview**: KPI dashboard with charts
- **User Directory**: User management and search
- **Merchant Intelligence**: Vendor catalog management
- **System Logs**: OCR audit logs

---

## Code Architecture

### Entry Point: lib/main_admin.dart

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: AdminApp()));
}
```

**Key Points**:
- Initializes Firebase before running app
- Wraps AdminApp with ProviderScope for Riverpod
- Same Firebase config as mobile app

---

### Root Widget: lib/admin/admin_app.dart

The security guard that controls access:

```dart
class AdminApp extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(adminAuthStateProvider);
    
    return authState.when(
      data: (userProfile) {
        if (userProfile == null) return AdminLoginScreen();
        if (userProfile.role != 'admin') return AccessDeniedScreen();
        return AdminDashboardShell();
      },
      loading: () => LoadingScreen(),
      error: (error, stack) => ErrorScreen(error: error),
    );
  }
}
```

**Access Control**:
1. Watch auth state (user object from Firebase)
2. If null → show login
3. If role != 'admin' → show access denied
4. If role == 'admin' → show dashboard

---

### Authentication Service: lib/admin/services/admin_auth_service.dart

```dart
class AdminAuthService {
  // Check if current user is admin
  Future<bool> isAdmin() async {
    final userDoc = await _firestore
        .collection('users')
        .doc(_auth.currentUser!.uid)
        .get();
    return userDoc.data()?['role'] == 'admin';
  }

  // Get user profile with role info
  Future<UserModel> getCurrentUserProfile() async {
    final userDoc = await _firestore
        .collection('users')
        .doc(_auth.currentUser!.uid)
        .get();
    return UserModel.fromFirestore(userDoc);
  }
}
```

**Key Methods**:
- `isAdmin()`: Check admin role
- `getCurrentUserProfile()`: Fetch full user doc
- `signOut()`: Sign out current user

---

### Riverpod Providers: lib/admin/providers/admin_providers.dart

**Authentication Providers**:

```dart
// Service provider
final adminAuthServiceProvider = Provider<AdminAuthService>((ref) {
  return AdminAuthService();
});

// Auth state stream (watches Firebase auth changes)
final adminAuthStateProvider = StreamProvider<UserModel?>((ref) async* {
  final authService = ref.watch(adminAuthServiceProvider);
  
  yield* FirebaseAuth.instance.authStateChanges().asyncMap((user) {
    if (user == null) return null;
    return authService.getCurrentUserProfile();
  });
});

// Check if current user is admin
final isAdminProvider = FutureProvider<bool>((ref) {
  return ref.watch(adminAuthServiceProvider).isAdmin();
});
```

**Navigation Provider**:

```dart
enum AdminSection { overview, userDirectory, merchantIntelligence, systemLogs }

final currentAdminSectionProvider = StateProvider<AdminSection>((ref) {
  return AdminSection.overview;
});
```

---

## Implementing a New Screen

### Step 1: Create Screen File

```dart
// lib/admin/screens/new_screen.dart

class MyNewScreen extends StatefulWidget {
  const MyNewScreen({super.key});

  @override
  State<MyNewScreen> createState() => _MyNewScreenState();
}

class _MyNewScreenState extends State<MyNewScreen> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Screen content
        ],
      ),
    );
  }
}
```

### Step 2: Update AdminSection Enum

```dart
// lib/admin/providers/admin_providers.dart
enum AdminSection { 
  overview, 
  userDirectory, 
  merchantIntelligence, 
  systemLogs,
  newScreen,  // Add here
}
```

### Step 3: Update Dashboard Shell

```dart
// lib/admin/screens/dashboard_shell.dart

// Add nav item
NavigationRailDestination(
  icon: const Icon(Icons.star_outline),
  selectedIcon: const Icon(Icons.star),
  label: const Text('New Screen'),
),

// Add case in screen routing
case AdminSection.newScreen:
  return const MyNewScreen();
```

---

## Working with Firestore Data

### Pattern: Read with StreamProvider

```dart
// Define provider
final usersStreamProvider = StreamProvider<List<UserModel>>((ref) async* {
  yield* FirebaseFirestore.instance
      .collection('users')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList());
});

// Use in widget
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(usersStreamProvider);
    
    return usersAsync.when(
      data: (users) => ListView.builder(
        itemCount: users.length,
        itemBuilder: (context, index) => UserCard(user: users[index]),
      ),
      loading: () => const CircularProgressIndicator(),
      error: (error, stack) => Text('Error: $error'),
    );
  }
}
```

### Pattern: Query with Parameters (Family Modifier)

```dart
// Filter by search term
final filteredUsersProvider = StreamProvider.family<List<UserModel>, String>(
  (ref, searchQuery) async* {
    yield* FirebaseFirestore.instance
        .collection('users')
        .orderBy('displayName')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserModel.fromFirestore(doc))
            .where((user) => user.displayName
                .toLowerCase()
                .contains(searchQuery.toLowerCase()))
            .toList());
  },
);

// Use with search state
final searchQueryProvider = StateProvider<String>((ref) => '');

class SearchableList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchQuery = ref.watch(searchQueryProvider);
    final usersAsync = ref.watch(filteredUsersProvider(searchQuery));
    
    return Column(
      children: [
        TextField(
          onChanged: (value) {
            ref.read(searchQueryProvider.notifier).state = value;
          },
        ),
        Expanded(
          child: usersAsync.when(
            data: (users) => ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, index) => UserCard(user: users[index]),
            ),
            loading: () => const Shimmer(),
            error: (error, stack) => ErrorWidget(error: error),
          ),
        ),
      ],
    );
  }
}
```

### Pattern: Mutation with WriteBatch

```dart
Future<void> updateUserStatus(String userId, String status) async {
  final batch = FirebaseFirestore.instance.batch();
  
  final userRef = FirebaseFirestore.instance
      .collection('users')
      .doc(userId);
  
  batch.update(userRef, {
    'status': status,
    'updatedAt': FieldValue.serverTimestamp(),
  });
  
  await batch.commit();
}

// Call from button
ElevatedButton(
  onPressed: () async {
    await updateUserStatus(userId, 'restricted');
    ref.invalidate(usersStreamProvider);  // Refresh data
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('User restricted')),
    );
  },
  child: const Text('Restrict User'),
)
```

---

## Styling & Theming

### Using AdminTheme Colors

```dart
Container(
  color: AdminTheme.surfaceCard,
  border: Border.all(color: AdminTheme.slateGray),
  child: Text(
    'Hello Admin',
    style: GoogleFonts.poppins(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: AdminTheme.textLight,
    ),
  ),
)
```

### Color Reference

```dart
// Palette
AdminTheme.primaryDark      // #004D40 - Main buttons
AdminTheme.accentTeal       // #00BCD4 - Highlights
AdminTheme.surfaceCard      // #242424 - Card backgrounds
AdminTheme.textLight        // #ECEFF1 - Primary text
AdminTheme.textSecondary    // #7A8E99 - Secondary text
AdminTheme.successGreen     // #4CAF50 - Success states
AdminTheme.warningOrange    // #FFA726 - Warnings
AdminTheme.errorRed         // #EF5350 - Errors
```

### Text Styling

```dart
// Heading
GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)

// Subheading
GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)

// Body
GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)

// Small
GoogleFonts.poppins(fontSize: 12, color: AdminTheme.textSecondary)
```

---

## Data Structure Reference

### User Model
```dart
class UserModel {
  final String id;
  final String displayName;
  final String email;
  final String role;           // 'admin' or 'user'
  final String status;          // 'active' or 'restricted'
  final int totalExpenses;
  final DateTime createdAt;
}
```

### OCR Log Structure
```dart
{
  'systemExtractedValue': 'RM 125.50',
  'userEnteredValue': 'RM 125.55',
  'userCorrection': 0.15,      // 15% difference
  'timestamp': Timestamp,
  'userId': 'userId',
  'receiptUrl': 'gs://...',
}
```

### Merchant/Vendor Catalog
```dart
{
  'name': 'Zus Coffee',
  'category': 'Food & Drinks',
  'createdAt': Timestamp,
  'createdBy': 'adminId',
  'isActive': true,
}
```

---

## Testing Features Locally

### Mock Data for Development

```dart
// In screens, you can add demo data when Firestore not available
List<UserModel> mockUsers = [
  UserModel(
    id: '1',
    displayName: 'John Doe',
    email: 'john@example.com',
    role: 'user',
    status: 'active',
    totalExpenses: 1500,
    createdAt: DateTime.now(),
  ),
];
```

### Test Firebase Auth

```bash
# Emulator (if using Firebase emulator suite)
firebase emulators:start
```

Configure in main_admin.dart:
```dart
if (kDebugMode) {
  FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
  FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
}
```

---

## Performance Optimization

### Implement Pagination

```dart
class PaginatedUsers extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pageSize = 10;
    final currentPage = ref.watch(currentPageProvider);
    
    final usersAsync = ref.watch(
      paginatedUsersProvider((
        page: currentPage,
        pageSize: pageSize,
      )),
    );
    
    return Column(
      children: [
        usersAsync.when(
          data: (users) => DataTable(rows: [...]),
          loading: () => Shimmer(),
          error: (e, s) => ErrorWidget(),
        ),
        PaginationControls(
          currentPage: currentPage,
          onNextPage: () {
            ref.read(currentPageProvider.notifier).state++;
          },
          onPreviousPage: () {
            ref.read(currentPageProvider.notifier).state--;
          },
        ),
      ],
    );
  }
}
```

### Debounce Search Input

```dart
final searchQueryProvider = StateProvider<String>((ref) => '');

final debouncedSearchProvider = FutureProvider<List<UserModel>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  
  if (query.isEmpty) {
    return [];  // Return empty on empty search
  }
  
  // Firestore doesn't support "contains", use orderBy + in-memory filter
  final snapshot = await FirebaseFirestore.instance
      .collection('users')
      .orderBy('displayName')
      .snapshots()
      .first;
  
  return snapshot.docs
      .map((doc) => UserModel.fromFirestore(doc))
      .where((user) => user.displayName.toLowerCase().contains(query.toLowerCase()))
      .toList();
});
```

---

## Common Tasks

### Task: Add a New KPI Card

```dart
// In overview_screen.dart
_buildKPICard(
  icon: Icons.trending_up,
  title: 'New Metric',
  value: '1,234',
  subtitle: 'Compared to last month',
  color: AdminTheme.accentTeal,
)
```

### Task: Add a New Table Column

```dart
// In user_directory_screen.dart
DataColumn(label: Text('New Column')),

// Add data in DataRow
DataCell(Text(user.newField)),
```

### Task: Add Export Functionality

```dart
ElevatedButton.icon(
  onPressed: () async {
    final csv = const ListToCsvConverter().convert(usersList);
    final bytes = utf8.encode(csv);
    // Save or share file
  },
  icon: const Icon(Icons.download),
  label: const Text('Export CSV'),
)
```

---

## Deployment Checklist

- [ ] All admin features tested locally
- [ ] Firestore security rules configured for admin access
- [ ] User with role 'admin' created in Firestore
- [ ] Firebase Auth email verified
- [ ] All required dependencies in pubspec.yaml
- [ ] Code passes `dart analyze`
- [ ] Code formatted with `dart format`
- [ ] Built with `flutter build web -t lib/main_admin.dart`
- [ ] Deployed to Firebase Hosting
- [ ] Tested on production Firebase project

