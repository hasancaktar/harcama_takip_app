/// Kredi kartı kesim tarihi, ekstre dönemi ve son ödeme vadesi hesaplama motoru.
/// 28, 29 (artık yıl), 30 ve 31 gün çeken ayları, yıl atlamalarını ve saat sınırlarını güvenle yönetir.
abstract class StatementCalculator {
  /// Verilen yıl ve ay için geçerli (clamp edilmiş) kesim gününü bulur.
  /// Örneğin hedef gün 31 ise ve ay Şubat ise (2026), 28 döner.
  static int getEffectiveCutoffDay(int year, int month, int targetCutoffDay) {
    assert(targetCutoffDay >= 1 && targetCutoffDay <= 31, 'Kesim günü 1-31 arasında olmalıdır');
    // DateTime(year, month + 1, 0).day o ayın son gün sayısını verir (ör. 28, 29, 30, 31)
    final lastDayOfMonth = DateTime(year, month + 1, 0).day;
    return targetCutoffDay > lastDayOfMonth ? lastDayOfMonth : targetCutoffDay;
  }

  /// Verilen yıl ve ay için kesin kesim tarihini (23:59:59.999) oluşturur.
  static DateTime getCutoffDateTime(int year, int month, int targetCutoffDay) {
    final effectiveDay = getEffectiveCutoffDay(year, month, targetCutoffDay);
    return DateTime(year, month, effectiveDay, 23, 59, 59, 999);
  }

  /// Harcama tarihi ile kartın kesim gününü karşılaştırarak harcamanın
  /// ait olduğu ekstre dönemini (YYYY-MM) hesaplar.
  ///
  /// Kural:
  /// - İşlem, o ayın kesim anından (23:59:59.999) önce veya tam kesim günündeyse: o ayın dönemine (`YYYY-MM`) aittir.
  /// - İşlem, kesim gününü geçmişse (örneğin ertesi gün): bir sonraki aya (`YYYY-MM`) aittir.
  static String resolveStatementPeriod(DateTime transactionDate, int cutoffDay) {
    final year = transactionDate.year;
    final month = transactionDate.month;
    final cutoffDateTime = getCutoffDateTime(year, month, cutoffDay);

    if (transactionDate.isAfter(cutoffDateTime)) {
      // Bir sonraki ekstre dönemine geçer (Yıl geçişi DateTime tarafından otomatik yönetilir)
      final nextMonth = DateTime(year, month + 1, 1);
      final formattedMonth = nextMonth.month.toString().padLeft(2, '0');
      return '${nextMonth.year}-$formattedMonth';
    } else {
      final formattedMonth = month.toString().padLeft(2, '0');
      return '$year-$formattedMonth';
    }
  }

  /// Belirtilen ekstre dönemi (YYYY-MM) için son ödeme tarihini hesaplar.
  /// [paymentDueDaysAfterCutoff]: Kesim tarihinden kaç gün sonra son ödeme günü olduğu (varsayılan: 10 gün).
  static DateTime calculateDueDate({
    required String statementPeriod,
    required int cutoffDay,
    int paymentDueDaysAfterCutoff = 10,
  }) {
    final parts = statementPeriod.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);

    final cutoffDate = getCutoffDateTime(year, month, cutoffDay);
    return cutoffDate.add(Duration(days: paymentDueDaysAfterCutoff));
  }

  /// Bir taksit planı için her bir taksitin beklenen ekstre dönemlerini ve kesim tarihlerini üretir.
  static List<StatementInstallmentScheduleItem> generateSchedule({
    required DateTime startDate,
    required int cutoffDay,
    required int totalInstallments,
    required List<int> installmentCentsList,
    int paymentDueDaysAfterCutoff = 10,
  }) {
    assert(installmentCentsList.length == totalInstallments);

    final List<StatementInstallmentScheduleItem> schedule = [];
    // İlk taksitin dönemini belirle
    final initialPeriod = resolveStatementPeriod(startDate, cutoffDay);
    final initialParts = initialPeriod.split('-');
    int currentYear = int.parse(initialParts[0]);
    int currentMonth = int.parse(initialParts[1]);

    for (int i = 0; i < totalInstallments; i++) {
      final periodMonthDate = DateTime(currentYear, currentMonth + i, 1);
      final periodYear = periodMonthDate.year;
      final periodMonth = periodMonthDate.month;
      final formattedPeriod = '$periodYear-${periodMonth.toString().padLeft(2, '0')}';

      final cutoffDate = getCutoffDateTime(periodYear, periodMonth, cutoffDay);
      final dueDate = cutoffDate.add(Duration(days: paymentDueDaysAfterCutoff));

      schedule.add(StatementInstallmentScheduleItem(
        installmentNumber: i + 1,
        amountInCents: installmentCentsList[i],
        statementPeriod: formattedPeriod,
        statementCutoffDate: cutoffDate,
        dueDate: dueDate,
        status: i == 0 ? 'posted' : 'upcoming',
      ));
    }

    return schedule;
  }
}

class StatementInstallmentScheduleItem {
  final int installmentNumber;
  final int amountInCents;
  final String statementPeriod;
  final DateTime statementCutoffDate;
  final DateTime dueDate;
  final String status;

  const StatementInstallmentScheduleItem({
    required this.installmentNumber,
    required this.amountInCents,
    required this.statementPeriod,
    required this.statementCutoffDate,
    required this.dueDate,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'installmentNumber': installmentNumber,
      'amountInCents': amountInCents,
      'statementPeriod': statementPeriod,
      'statementCutoffDate': statementCutoffDate.toIso8601String(),
      'dueDate': dueDate.toIso8601String(),
      'status': status,
    };
  }
}
