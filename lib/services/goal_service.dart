import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/goal_model.dart';

final goalServiceProvider = Provider<GoalService>((ref) {
  return GoalService();
});

final goalsStreamProvider = StreamProvider.autoDispose<List<GoalModel>>((ref) {
  final goalService = ref.watch(goalServiceProvider);
  return goalService.streamGoals();
});

class GoalService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get userId => _auth.currentUser?.uid;

  CollectionReference get _goalsCollection {
    if (userId == null) throw Exception("User is not logged in");
    return _firestore.collection('users').doc(userId).collection('goals');
  }

  Stream<List<GoalModel>> streamGoals() {
    final uid = userId;
    if (uid == null) return Stream.value([]);
    
    return _firestore.collection('users').doc(uid).collection('goals')
        .orderBy('targetDate', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return GoalModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  Future<void> addGoal(GoalModel goal) async {
    await _goalsCollection.add(goal.toMap());
  }

  Future<void> updateGoal(GoalModel goal) async {
    if (goal.id == null) return;
    await _goalsCollection.doc(goal.id).update(goal.toMap());
  }

  Future<void> addSavings(String goalId, double amountToAdd) async {
    if (amountToAdd <= 0) return;
    
    final docRef = _goalsCollection.doc(goalId);
    
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;
      
      final currentData = snapshot.data() as Map<String, dynamic>;
      final double currentSaved = (currentData['currentAmount'] ?? 0.0).toDouble();
      
      transaction.update(docRef, {
        'currentAmount': currentSaved + amountToAdd,
      });
    });
  }

  Future<void> deleteGoal(String goalId) async {
    await _goalsCollection.doc(goalId).delete();
  }
}
