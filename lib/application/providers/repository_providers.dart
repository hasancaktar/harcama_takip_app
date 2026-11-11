import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/i_auth_repository.dart';
import '../../domain/repositories/i_expense_repository.dart';
import '../../domain/repositories/i_card_repository.dart';
import '../../domain/repositories/i_installment_repository.dart';
import '../../domain/repositories/i_team_repository.dart';
import '../../domain/repositories/i_budget_repository.dart';
import '../../domain/repositories/i_user_repository.dart';
import '../../data/repositories/firebase_auth_repository.dart';
import '../../data/repositories/firestore_expense_repository.dart';
import '../../data/repositories/firestore_card_repository.dart';
import '../../data/repositories/firestore_installment_repository.dart';
import '../../data/repositories/firestore_team_repository.dart';
import '../../data/repositories/firestore_budget_repository.dart';
import '../../data/repositories/firestore_user_repository.dart';

final authRepositoryProvider = Provider<IAuthRepository>((ref) {
  return FirebaseAuthRepository();
});

final expenseRepositoryProvider = Provider<IExpenseRepository>((ref) {
  return FirestoreExpenseRepository();
});

final cardRepositoryProvider = Provider<ICardRepository>((ref) {
  return FirestoreCardRepository();
});

final installmentRepositoryProvider = Provider<IInstallmentRepository>((ref) {
  return FirestoreInstallmentRepository();
});

final teamRepositoryProvider = Provider<ITeamRepository>((ref) {
  return FirestoreTeamRepository();
});

final budgetRepositoryProvider = Provider<IBudgetRepository>((ref) {
  return FirestoreBudgetRepository();
});

final userRepositoryProvider = Provider<IUserRepository>((ref) {
  return FirestoreUserRepository();
});
