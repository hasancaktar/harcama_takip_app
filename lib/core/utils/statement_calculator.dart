/// Kredi kartı kesim tarihi, ekstre dönemi ve son ödeme vadesi hesaplama motoru.
///
/// 28, 29 (artık yıl), 30 ve 31 gün çeken ayları, yıl geçişlerini ve gün sonu
/// sınırlarını güvenle yönetir. Tüm dönemler `YYYY-MM` biçimindedir.
abstract class StatementCalculator {
  static final RegExp _periodPattern = RegExp(r'^\d{4}-(0[1-9]|1[0-2])$');

  /// `YYYY-MM` biçiminin geçerli olup olmadığını döner.
  static bool isValidPeriod(String period) => _periodPattern.hasMatch(period);

  /// Verilen tarihin takvim ayı dönemini (`YYYY-MM`) döner.
  static String periodOf(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';

  /// Dönemi ay sayısı kadar kaydırır. Örnek: ('2026-12', 1) -> '2027-01'
  static String shiftPeriod(String period, int months) {
    final start = periodStart(period);
    return periodOf(DateTime(start.year, start.month + months, 1));
  }

  /// Dönemin ilk gününü (00:00) döner.
  static DateTime periodStart(String period) {
    final parts = period.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]), 1);
  }

  /// [endPeriod] dahil olmak üzere geriye doğru [count] adet dönem üretir (eskiden yeniye).
  static List<String> lastPeriods(String endPeriod, int count) {
    return List<String>.generate(
      count,
      (i) => shiftPeriod(endPeriod, i - count + 1),
    );
  }

  /// Verilen yıl ve ay için geçerli (clamp edilmiş) kesim gününü bulur.
  /// Örneğin hedef gün 31 ve ay Şubat (2026) ise 28 döner.
  static int getEffectiveCutoffDay(int year, int month, int targetCutoffDay) {
    assert(
      targetCutoffDay >= 1 && targetCutoffDay <= 31,
      'Kesim günü 1-31 arasında olmalıdır',
    );
    final lastDayOfMonth = DateTime(year, month + 1, 0).day;
    return targetCutoffDay > lastDayOfMonth ? lastDayOfMonth : targetCutoffDay;
  }

  /// Verilen yıl ve ay için kesim anını (gün sonu 23:59:59.999) oluşturur.
  static DateTime getCutoffDateTime(int year, int month, int targetCutoffDay) {
    final effectiveDay = getEffectiveCutoffDay(year, month, targetCutoffDay);
    return DateTime(year, month, effectiveDay, 23, 59, 59, 999);
  }

  /// Kredi kartı harcamasının ait olduğu ekstre dönemini (`YYYY-MM`) hesaplar.
  ///
  /// - İşlem o ayın kesim anına kadar (kesim günü dahil) yapıldıysa: o ayın dönemi.
  /// - Kesim gününden sonra yapıldıysa: bir sonraki ayın dönemi.
  static String resolveStatementPeriod(
    DateTime transactionDate,
    int cutoffDay,
  ) {
    final cutoff = getCutoffDateTime(
      transactionDate.year,
      transactionDate.month,
      cutoffDay,
    );
    if (transactionDate.isAfter(cutoff)) {
      return periodOf(
        DateTime(transactionDate.year, transactionDate.month + 1, 1),
      );
    }
    return periodOf(transactionDate);
  }

  /// Bir harcamanın hangi döneme yazılacağını belirler.
  ///
  /// Kredi kartı ile ödenen harcamalar kartın kesim gününe göre ekstre dönemine,
  /// diğer tüm ödeme yöntemleri ise harcamanın yapıldığı takvim ayına yazılır.
  static String periodForExpense({
    required DateTime date,
    required String paymentMethod,
    int? cutoffDay,
  }) {
    if (paymentMethod == 'credit_card' && cutoffDay != null) {
      return resolveStatementPeriod(date, cutoffDay);
    }
    return periodOf(date);
  }

  /// Belirtilen ekstre dönemi için son ödeme tarihini hesaplar.
  static DateTime calculateDueDate({
    required String statementPeriod,
    required int cutoffDay,
    int paymentDueDaysAfterCutoff = 10,
  }) {
    final start = periodStart(statementPeriod);
    final cutoffDate = getCutoffDateTime(start.year, start.month, cutoffDay);
    return DateTime(
      cutoffDate.year,
      cutoffDate.month,
      cutoffDate.day + paymentDueDaysAfterCutoff,
    );
  }

  /// [now] anından sonraki ilk kesim tarihini döner (bugün kesim günüyse bugün).
  static DateTime nextCutoffDate(DateTime now, int cutoffDay) {
    final thisMonth = getCutoffDateTime(now.year, now.month, cutoffDay);
    if (!now.isAfter(thisMonth)) return thisMonth;
    final next = DateTime(now.year, now.month + 1, 1);
    return getCutoffDateTime(next.year, next.month, cutoffDay);
  }

  /// Bir taksit planı için her taksitin ekstre dönemini, kesim ve son ödeme tarihini üretir.
  /// Tüm taksitler başlangıçta `upcoming` durumundadır; işlenme zamanı
  /// [InstallmentPostingPolicy] tarafından belirlenir.
  static List<StatementInstallmentScheduleItem> generateSchedule({
    required DateTime startDate,
    required int cutoffDay,
    required int totalInstallments,
    required List<int> installmentCentsList,
    int paymentDueDaysAfterCutoff = 10,
  }) {
    assert(installmentCentsList.length == totalInstallments);

    final firstPeriod = resolveStatementPeriod(startDate, cutoffDay);
    return List<StatementInstallmentScheduleItem>.generate(totalInstallments, (
      i,
    ) {
      final period = shiftPeriod(firstPeriod, i);
      final start = periodStart(period);
      final cutoffDate = getCutoffDateTime(start.year, start.month, cutoffDay);
      return StatementInstallmentScheduleItem(
        installmentNumber: i + 1,
        amountInCents: installmentCentsList[i],
        statementPeriod: period,
        statementCutoffDate: cutoffDate,
        dueDate: DateTime(
          cutoffDate.year,
          cutoffDate.month,
          cutoffDate.day + paymentDueDaysAfterCutoff,
        ),
        status: 'upcoming',
      );
    });
  }
}

/// Taksitlerin harcama olarak ne zaman işleneceğini belirleyen kural.
///
/// Bir taksit, ait olduğu ekstre döneminin takvim ayı geldiğinde (veya geçtiğinde)
/// harcama olarak işlenir. Böylece içinde bulunulan ayın ekstresi, kesim
/// tarihinden önce de doğru toplamı gösterir. Bulut fonksiyonu da aynı kuralı uygular.
abstract class InstallmentPostingPolicy {
  static bool isDue(StatementInstallmentScheduleItem item, DateTime now) {
    return item.status == 'upcoming' &&
        item.statementPeriod.compareTo(StatementCalculator.periodOf(now)) <= 0;
  }

  /// Harcama belgesi için deterministik (idempotent) kimlik.
  static String expenseIdFor(
    String planId,
    StatementInstallmentScheduleItem item,
  ) => '${planId}_${item.installmentNumber}_${item.statementPeriod}';
}

class StatementInstallmentScheduleItem {
  final int installmentNumber;
  final int amountInCents;
  final String statementPeriod;
  final DateTime statementCutoffDate;
  final DateTime dueDate;
  final String status; // 'upcoming' | 'posted'

  const StatementInstallmentScheduleItem({
    required this.installmentNumber,
    required this.amountInCents,
    required this.statementPeriod,
    required this.statementCutoffDate,
    required this.dueDate,
    required this.status,
  });

  bool get isPosted => status == 'posted';

  StatementInstallmentScheduleItem copyWith({String? status}) {
    return StatementInstallmentScheduleItem(
      installmentNumber: installmentNumber,
      amountInCents: amountInCents,
      statementPeriod: statementPeriod,
      statementCutoffDate: statementCutoffDate,
      dueDate: dueDate,
      status: status ?? this.status,
    );
  }

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
