import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/stream_utils.dart';
import '../../domain/entities/credit_card.dart';
import '../../domain/entities/debit_card.dart';
import '../../domain/entities/expense.dart';
import 'auth_providers.dart';
import 'repository_providers.dart';
import 'team_providers.dart';

/// Kullanıcının kendi kartları.
final ownCardsProvider = StreamProvider<List<CreditCard>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(cardRepositoryProvider).watchOwnCards(uid);
});

/// Harcama girerken seçilebilecek kartlar: kendi kartları + (takım modunda) takımla paylaşılan kartlar.
final availableCardsProvider = StreamProvider<List<CreditCard>>((ref) async* {
  final uid = ref.watch(currentUserIdProvider);
  final repo = ref.watch(cardRepositoryProvider);
  final teamIdFuture = ref.watch(
    workspaceProvider.selectAsync((w) => w.teamId),
  );
  if (uid == null) {
    yield const [];
    return;
  }
  final teamId = await teamIdFuture;
  if (teamId == null) {
    yield* repo.watchOwnCards(uid);
    return;
  }
  yield* mergeListStreams<CreditCard>(
    [repo.watchOwnCards(uid), repo.watchTeamSharedCards(teamId)],
    idOf: (c) => c.id,
  ).map((cards) => cards..sort((a, b) => a.createdAt.compareTo(b.createdAt)));
});

final cardByIdProvider = StreamProvider.autoDispose.family<CreditCard?, String>(
  (ref, id) {
    return ref.watch(cardRepositoryProvider).watchCard(id);
  },
);

typedef CardStatementKey = ({String cardId, String period});

/// Bir kartın belirli bir ekstre dönemindeki harcamaları.
final cardStatementExpensesProvider = StreamProvider.autoDispose
    .family<List<Expense>, CardStatementKey>((ref, key) async* {
      final uid = ref.watch(currentUserIdProvider);
      final repo = ref.watch(expenseRepositoryProvider);
      final cardFuture = ref.watch(cardByIdProvider(key.cardId).future);
      if (uid == null) {
        yield const [];
        return;
      }
      final card = await cardFuture;
      if (card == null) {
        yield const [];
        return;
      }
      yield* repo.watchCardExpenses(
        cardId: key.cardId,
        uid: uid,
        sharedTeamId: card.isSharedWithTeam ? card.teamId : null,
        period: key.period,
      );
    });

/// Kullanıcının banka kartları.
final debitCardsProvider = StreamProvider<List<DebitCard>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(debitCardRepositoryProvider).watchOwnCards(uid);
});

final debitCardByIdProvider = StreamProvider.autoDispose
    .family<DebitCard?, String>(
      (ref, id) => ref.watch(debitCardRepositoryProvider).watchCard(id),
    );

/// Bir banka kartından belirli ayda yapılan (kullanıcının kendi) harcamalar.
final debitCardExpensesProvider = StreamProvider.autoDispose
    .family<List<Expense>, CardStatementKey>((ref, key) {
      final uid = ref.watch(currentUserIdProvider);
      if (uid == null) return Stream.value(const []);
      return ref
          .watch(expenseRepositoryProvider)
          .watchCardExpenses(cardId: key.cardId, uid: uid, period: key.period);
    });
