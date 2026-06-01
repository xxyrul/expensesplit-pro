import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/goal_repository.dart';
import '../services/goal_service.dart';
import '../models/goal_model.dart';

final goalRepositoryProvider = Provider<GoalRepository>((ref) {
  return GoalRepository();
});

final goalServiceProvider = Provider<GoalService>((ref) {
  final repository = ref.watch(goalRepositoryProvider);
  return GoalService(repository);
});

final goalsStreamProvider = StreamProvider.autoDispose<List<GoalModel>>((ref) {
  final service = ref.watch(goalServiceProvider);
  return service.streamGoals();
});
