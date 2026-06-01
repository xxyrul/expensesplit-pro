import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/debt_repository.dart';
import '../services/debt_service.dart';
import '../models/debt_model.dart';

final debtRepositoryProvider = Provider<DebtRepository>((ref) {
  return DebtRepository();
});

final debtServiceProvider = Provider<DebtService>((ref) {
  final repository = ref.watch(debtRepositoryProvider);
  return DebtService(repository);
});

final debtsStreamProvider = StreamProvider.autoDispose<List<DebtModel>>((ref) {
  final service = ref.watch(debtServiceProvider);
  return service.streamDebts();
});
