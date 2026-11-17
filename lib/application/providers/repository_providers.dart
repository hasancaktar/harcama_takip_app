import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/firebase_auth_repository.dart';
import '../../core/constants/app_constants.dart';
import '../../data/repositories/firestore_admin_repository.dart';
import '../../data/services/notification_server_client.dart';
import '../../domain/repositories/i_notification_server.dart';
import '../../domain/repositories/i_admin_repository.dart';
import '../../data/repositories/firestore_account_data_repository.dart';
import '../../data/repositories/firestore_budget_repository.dart';
import '../../data/repositories/firestore_card_repository.dart';
import '../../data/repositories/firestore_expense_repository.dart';
import '../../data/repositories/firestore_installment_repository.dart';
import '../../data/repositories/firestore_team_repository.dart';
import '../../data/repositories/firestore_user_repository.dart';
import '../../domain/repositories/i_auth_repository.dart';
import '../../domain/repositories/i_budget_repository.dart';
import '../../domain/repositories/i_card_repository.dart';
import '../../domain/repositories/i_expense_repository.dart';
import '../../domain/repositories/i_installment_repository.dart';
import '../../domain/repositories/i_team_repository.dart';
import '../../domain/repositories/i_user_repository.dart';
import '../services/installment_posting_service.dart';
import '../services/notification_service.dart';
import '../services/push_token_service.dart';

// Depolar arayüz üzerinden sağlanır; testlerde `overrideWithValue` ile sahte
// uygulamalar verilebilir.

final authRepositoryProvider = Provider<IAuthRepository>(
  (ref) => FirebaseAuthRepository(),
);
final expenseRepositoryProvider = Provider<IExpenseRepository>(
  (ref) => FirestoreExpenseRepository(),
);
final cardRepositoryProvider = Provider<ICardRepository>(
  (ref) => FirestoreCardRepository(),
);
final installmentRepositoryProvider = Provider<IInstallmentRepository>(
  (ref) => FirestoreInstallmentRepository(),
);
final teamRepositoryProvider = Provider<ITeamRepository>(
  (ref) => FirestoreTeamRepository(),
);
final budgetRepositoryProvider = Provider<IBudgetRepository>(
  (ref) => FirestoreBudgetRepository(),
);
final userRepositoryProvider = Provider<IUserRepository>(
  (ref) => FirestoreUserRepository(),
);
final accountDataRepositoryProvider = Provider<FirestoreAccountDataRepository>(
  (ref) => FirestoreAccountDataRepository(),
);

final installmentPostingServiceProvider = Provider<InstallmentPostingService>(
  (ref) => InstallmentPostingService(ref.watch(installmentRepositoryProvider)),
);
final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService.instance,
);
final pushTokenServiceProvider = Provider<PushTokenService>(
  (ref) => PushTokenService(
    ref.watch(userRepositoryProvider),
    notifications: ref.watch(notificationServiceProvider),
  ),
);

final categoryRepositoryProvider = Provider<ICategoryRepository>(
  (ref) => FirestoreCategoryRepository(),
);
final adminRepositoryProvider = Provider<IAdminRepository>(
  (ref) => FirestoreAdminRepository(),
);
final notificationServerProvider = Provider<INotificationServer>(
  (ref) => HttpNotificationServer(baseUrl: AppConstants.notificationServerUrl),
);
