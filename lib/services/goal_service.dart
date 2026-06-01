import '../models/goal_model.dart';
import '../repositories/goal_repository.dart';

class GoalService {
  final GoalRepository _repository;

  GoalService(this._repository);

  Stream<List<GoalModel>> streamGoals() => _repository.streamGoals();
  Future<void> addGoal(GoalModel goal) => _repository.addGoal(goal);
  Future<void> updateGoal(GoalModel goal) => _repository.updateGoal(goal);
  Future<void> addSavings(String goalId, double amountToAdd) => _repository.addSavings(goalId, amountToAdd);
  Future<void> deleteGoal(String goalId) => _repository.deleteGoal(goalId);
}
