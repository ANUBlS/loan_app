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

double _num(Object? v) => (v as num).toDouble();

/// "2026-08-24" -> local midnight; "2026-08-24T12:00:00+04:00" -> local time.
DateTime _date(Object? v) {
  final d = DateTime.parse(v as String);
  return d.isUtc ? d.toLocal() : d;
}

DateTime? _dateOrNull(Object? v) => v == null ? null : _date(v);

LoanType loanTypeFromJson(Object? v) => LoanType.values.byName(v as String);

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

  /// From the API's schedule row (GET /api/v1/loans/{id}).
  factory Installment.fromJson(Map<String, dynamic> j) => Installment(
        number: (j['number'] as num).toInt(),
        dueDate: _date(j['dueDate']),
        principal: _num(j['principal']),
        interest: _num(j['interest']),
        balanceAfter: _num(j['balanceAfter']),
        paidDate: _dateOrNull(j['paidDate']),
      );

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

  /// From GET /api/v1/loans/{id} (the response includes the schedule).
  factory Loan.fromJson(Map<String, dynamic> j) => Loan(
        id: j['id'] as String,
        type: loanTypeFromJson(j['type']),
        productName: j['productName'] as String,
        contractNo: j['contractNo'] as String,
        currency: j['currency'] as String,
        amount: _num(j['amount']),
        annualRate: _num(j['annualRate']),
        termMonths: (j['termMonths'] as num).toInt(),
        startDate: _date(j['startDate']),
        schedule: [
          for (final row in (j['schedule'] as List? ?? const []))
            Installment.fromJson(row as Map<String, dynamic>),
        ],
      );

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

  /// Number shown to the customer, e.g. APP-000123.
  final String reference;

  /// submitted | approved | rejected | cancelled
  final String status;
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
    this.reference = '',
    this.status = 'submitted',
  });

  /// From POST/GET /api/v1/applications.
  factory LoanApplication.fromJson(Map<String, dynamic> j) => LoanApplication(
        id: j['id'] as String,
        reference: (j['reference'] as String?) ?? '',
        status: (j['status'] as String?) ?? 'submitted',
        type: loanTypeFromJson(j['type']),
        productName: j['productName'] as String,
        amount: _num(j['amount']),
        termMonths: (j['termMonths'] as num).toInt(),
        annualRate: _num(j['annualRate']),
        monthlyPayment: _num(j['monthlyPayment']),
        purpose: j['purpose'] as String,
        currency: j['currency'] as String,
        createdAt: _date(j['createdAt']),
      );
}
