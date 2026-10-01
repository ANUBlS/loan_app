enum LoanType { consumer, car, mortgage, business }

enum InstallmentStatus { paid, overdue, next, upcoming }

/// Order matters: loans are sorted overdue -> active -> closed.
enum LoanState { overdue, active, closed }

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Whole calendar days from [from] to [to] (DST-safe).
int daysBetween(DateTime from, DateTime to) =>
    DateTime.utc(to.year, to.month, to.day)
        .difference(DateTime.utc(from.year, from.month, from.day))
        .inDays;

class Installment {
  final int number;
  final DateTime dueDate;
  final double principal;
  final double interest;
  final double balanceAfter;
  final DateTime? paidDate;

  const Installment({
    required this.number,
    required this.dueDate,
    required this.principal,
    required this.interest,
    required this.balanceAfter,
    this.paidDate,
  });

  bool get isPaid => paidDate != null;
  double get total => principal + interest;

  Installment copyWith({DateTime? paidDate}) => Installment(
        number: number,
        dueDate: dueDate,
        principal: principal,
        interest: interest,
        balanceAfter: balanceAfter,
        paidDate: paidDate ?? this.paidDate,
      );
}

class Loan {
  final String id;
  final LoanType type;
  /// Translation key, e.g. product.car_loan
  final String productName;
  final String contractNo;
  final String currency;
  final double amount;
  final double annualRate;
  final int termMonths;
  final DateTime startDate;
  final List<Installment> schedule;

  const Loan({
    required this.id,
    required this.type,
    required this.productName,
    required this.contractNo,
    required this.currency,
    required this.amount,
    required this.annualRate,
    required this.termMonths,
    required this.startDate,
    required this.schedule,
  });

  Loan copyWith({List<Installment>? schedule}) => Loan(
        id: id,
        type: type,
        productName: productName,
        contractNo: contractNo,
        currency: currency,
        amount: amount,
        annualRate: annualRate,
        termMonths: termMonths,
        startDate: startDate,
        schedule: schedule ?? this.schedule,
      );

  int get paidCount => schedule.where((i) => i.isPaid).length;

  double get paidPrincipal => amount - outstandingPrincipal;

  /// Earliest unpaid installment (overdue ones come first by date).
  Installment? get firstUnpaid {
    for (final i in schedule) {
      if (!i.isPaid) return i;
    }
    return null;
  }

  double get paidTotal =>
      schedule.where((i) => i.isPaid).fold<double>(0, (s, i) => s + i.total);

  double get outstandingPrincipal => schedule
      .where((i) => !i.isPaid)
      .fold<double>(0, (s, i) => s + i.principal);

  double get monthlyPayment => schedule.isEmpty ? 0 : schedule.first.total;

  DateTime? get finalPaymentDate =>
      schedule.isEmpty ? null : schedule.last.dueDate;

  List<Installment> overdueInstallments([DateTime? now]) {
    final today = dateOnly(now ?? DateTime.now());
    return schedule
        .where((i) => !i.isPaid && dateOnly(i.dueDate).isBefore(today))
        .toList();
  }

  double overdueAmount([DateTime? now]) =>
      overdueInstallments(now).fold<double>(0, (s, i) => s + i.total);

  /// First unpaid installment that is due today or later.
  Installment? nextInstallment([DateTime? now]) {
    final today = dateOnly(now ?? DateTime.now());
    for (final i in schedule) {
      if (!i.isPaid && !dateOnly(i.dueDate).isBefore(today)) return i;
    }
    return null;
  }

  InstallmentStatus statusOf(Installment inst, [DateTime? now]) {
    if (inst.isPaid) return InstallmentStatus.paid;
    final today = dateOnly(now ?? DateTime.now());
    if (dateOnly(inst.dueDate).isBefore(today)) return InstallmentStatus.overdue;
    final next = nextInstallment(now);
    if (next != null && next.number == inst.number) {
      return InstallmentStatus.next;
    }
    return InstallmentStatus.upcoming;
  }

  LoanState get state {
    if (schedule.every((i) => i.isPaid)) return LoanState.closed;
    if (overdueInstallments().isNotEmpty) return LoanState.overdue;
    return LoanState.active;
  }
}

class LoanApplication {
  final String id;
  final LoanType type;
  final String productName;
  final double amount;
  final int termMonths;
  final double annualRate;
  final double monthlyPayment;
  final String purpose;
  final String currency;
  final DateTime createdAt;

  const LoanApplication({
    required this.id,
    required this.type,
    required this.productName,
    required this.amount,
    required this.termMonths,
    required this.annualRate,
    required this.monthlyPayment,
    required this.purpose,
    required this.currency,
    required this.createdAt,
  });
}
