import '../models/debt_model.dart';
import '../repositories/debt_repository.dart';
import 'dart:math';

class DebtService {
  final DebtRepository _repository;

  DebtService(this._repository);

  Stream<List<DebtModel>> streamDebts() => _repository.streamDebts();
  Future<void> addDebt(DebtModel debt) => _repository.addDebt(debt);
  Future<void> updateDebt(DebtModel debt) => _repository.updateDebt(debt);
  Future<void> deleteDebt(String debtId) => _repository.deleteDebt(debtId);
  Future<void> addPayment(String debtId, double amount) => _repository.addPayment(debtId, amount);

  int calculatePayoffTime(double balance, double monthlyPayment, double annualRatePercent) {
    if (balance <= 0) return 0;
    
    final monthlyRate = (annualRatePercent / 100) / 12;
    
    if (monthlyRate == 0) {
      return (balance / monthlyPayment).ceil();
    }

    if (monthlyPayment <= balance * monthlyRate) {
      return -1;
    }

    final n = -log(1 - (monthlyRate * balance) / monthlyPayment) / log(1 + monthlyRate);
    return n.ceil();
  }
}
