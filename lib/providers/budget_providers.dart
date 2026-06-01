import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/budget_repository.dart';
import '../services/budget_service.dart';
import '../services/auth_service.dart';

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepository();
});

final budgetServiceProvider = Provider<BudgetService>((ref) {
  final repository = ref.watch(budgetRepositoryProvider);
  return BudgetService(repository);
});

final budgetsStreamProvider = StreamProvider.autoDispose<Map<String, double>>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  final service = ref.watch(budgetServiceProvider);

  return authState.when(
    data: (user) {
      if (user == null) return Stream.value({});
      return service.getBudgets();
    },
    loading: () => Stream.value({}),
    error: (_, __) => Stream.value({}),
  );
});
