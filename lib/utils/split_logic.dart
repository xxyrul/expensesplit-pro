Map<String, double> calculateEqualSplit(double totalAmount, List<String> userIds) {
  if (userIds.isEmpty) return {};

  // Convert to cents to handle money math safely without floating-point errors
  int totalCents = (totalAmount * 100).round();
  int numUsers = userIds.length;
  
  int baseSplitCents = totalCents ~/ numUsers;
  int remainderCents = totalCents % numUsers;

  Map<String, double> splitResult = {};
  
  for (int i = 0; i < numUsers; i++) {
    int userAmountCents = baseSplitCents;
    
    // Assign any extra cents to the first user in the list (the payer)
    if (i == 0) {
      userAmountCents += remainderCents;
    }
    
    splitResult[userIds[i]] = userAmountCents / 100.0;
  }
  
  return splitResult;
}
