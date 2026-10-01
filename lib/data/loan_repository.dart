import 'package:flutter/foundation.dart';

import '../models/loan.dart';
import '../utils/loan_math.dart';
import 'mock_data.dart';

/// Single source of loan data. Swap the mock calls for API calls later
/// without touching the screens.
class LoanRepository extends ChangeNotifier {
  LoanRepository._();
  static final LoanRepository instance = LoanRepository._();

  final List<Loan> _loans = MockData.loans();
  final List<LoanApplication> _applications = [];

  List<Loan> get loans {
    final sorted = [..._loans];
    sorted.sort((a, b) => a.state.index.compareTo(b.state.index));
    return sorted;
  }

  List<LoanApplication> get applications => List.unmodifiable(_applications);

  Loan? byId(String id) {
    for (final l in _loans) {
      if (l.id == id) return l;
    }
    return null;
  }

  /// Most urgent open loan: overdue first, otherwise the nearest due date.
  Loan? get urgentLoan {
    final open = _loans.where((l) => l.state != LoanState.closed).toList();
    if (open.isEmpty) return null;
    for (final l in open) {
      if (l.state == LoanState.overdue) return l;
    }
    open.sort((a, b) => a.firstUnpaid!.dueDate.compareTo(b.firstUnpaid!.dueDate));
    return open.first;
  }

  /// All paid installments of all loans, newest first.
  List<(Loan, Installment)> get paymentHistory {
    final list = <(Loan, Installment)>[
      for (final l in _loans)
        for (final i in l.schedule)
          if (i.isPaid) (l, i),
    ];
    list.sort((a, b) => b.$2.paidDate!.compareTo(a.$2.paidDate!));
    return list;
  }

  /// Mock payment: marks the earliest unpaid installment as paid today.
  Installment? payNext(String loanId) {
    final index = _loans.indexWhere((l) => l.id == loanId);
    if (index < 0) return null;
    final loan = _loans[index];
    final i = loan.schedule.indexWhere((s) => !s.isPaid);
    if (i < 0) return null;
    final paid = loan.schedule[i].copyWith(paidDate: DateTime.now());
    final schedule = [...loan.schedule];
    schedule[i] = paid;
    _loans[index] = loan.copyWith(schedule: schedule);
    notifyListeners();
    return paid;
  }

  LoanApplication submitApplication({
    required LoanProduct product,
    required double amount,
    required int termMonths,
    required String purpose,
  }) {
    final now = DateTime.now();
    final app = LoanApplication(
      id: 'APP-${now.millisecondsSinceEpoch.toString().substring(7)}',
      type: product.type,
      productName: product.loanName,
      amount: amount,
      termMonths: termMonths,
      annualRate: product.annualRate,
      monthlyPayment:
          round2(annuityPayment(amount, product.annualRate, termMonths)),
      purpose: purpose,
      currency: MockData.currency,
      createdAt: now,
    );
    _applications.insert(0, app);
    notifyListeners();
    return app;
  }
}
