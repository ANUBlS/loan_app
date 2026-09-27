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
      productName: '${product.name} Loan',
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
