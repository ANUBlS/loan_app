import '../models/loan.dart';
import '../utils/loan_math.dart';

class LoanProduct {
  final LoanType type;
  final String name;
  final double annualRate;
  final double minAmount;
  final double maxAmount;
  final double step;
  final int minTerm;
  final int maxTerm;

  const LoanProduct({
    required this.type,
    required this.name,
    required this.annualRate,
    required this.minAmount,
    required this.maxAmount,
    required this.step,
    required this.minTerm,
    required this.maxTerm,
  });

  int get amountDivisions => ((maxAmount - minAmount) / step).round();
}

class MockData {
  static const currency = 'AZN';

  static const products = <LoanProduct>[
    LoanProduct(
      type: LoanType.consumer,
      name: 'Consumer',
      annualRate: 17,
      minAmount: 500,
      maxAmount: 30000,
      step: 100,
      minTerm: 6,
      maxTerm: 60,
    ),
    LoanProduct(
      type: LoanType.car,
      name: 'Car',
      annualRate: 13.5,
      minAmount: 5000,
      maxAmount: 80000,
      step: 500,
      minTerm: 12,
      maxTerm: 84,
    ),
    LoanProduct(
      type: LoanType.mortgage,
      name: 'Mortgage',
      annualRate: 8,
      minAmount: 10000,
      maxAmount: 300000,
      step: 1000,
      minTerm: 36,
      maxTerm: 300,
    ),
    LoanProduct(
      type: LoanType.business,
      name: 'Business',
      annualRate: 15,
      minAmount: 5000,
      maxAmount: 150000,
      step: 1000,
      minTerm: 6,
      maxTerm: 84,
    ),
  ];

  static const purposes = <String>[
    'Personal needs',
    'Car purchase',
    'Home purchase',
    'Renovation',
    'Education',
    'Business',
  ];

  /// Dates are relative to today so paid / overdue / next always look realistic.
  static List<Loan> loans() {
    final today = dateOnly(DateTime.now());
    return [
      _loan(
        id: 'L001',
        type: LoanType.consumer,
        name: 'Consumer Loan',
        contractNo: 'CL-2025-004187',
        amount: 5000,
        rate: 18,
        term: 24,
        start: addMonths(today, -10).subtract(const Duration(days: 5)),
        paid: 10,
      ),
      _loan(
        id: 'L002',
        type: LoanType.car,
        name: 'Car Loan',
        contractNo: 'AU-2026-000932',
        amount: 25000,
        rate: 14,
        term: 48,
        start: addMonths(today, -8).subtract(const Duration(days: 10)),
        paid: 6, // installments 7 and 8 are overdue
      ),
      _loan(
        id: 'L003',
        type: LoanType.mortgage,
        name: 'Mortgage',
        contractNo: 'MG-2026-000215',
        amount: 80000,
        rate: 9,
        term: 120,
        start: addMonths(today, -3).subtract(const Duration(days: 2)),
        paid: 3,
      ),
      _loan(
        id: 'L004',
        type: LoanType.consumer,
        name: 'Express Cash Loan',
        contractNo: 'EX-2025-011508',
        amount: 2000,
        rate: 20,
        term: 12,
        start: addMonths(today, -14),
        paid: 12, // fully repaid
      ),
    ];
  }

  static Loan _loan({
    required String id,
    required LoanType type,
    required String name,
    required String contractNo,
    required double amount,
    required double rate,
    required int term,
    required DateTime start,
    required int paid,
  }) {
    return Loan(
      id: id,
      type: type,
      productName: name,
      contractNo: contractNo,
      currency: currency,
      amount: amount,
      annualRate: rate,
      termMonths: term,
      startDate: start,
      schedule: buildSchedule(
        amount: amount,
        annualRate: rate,
        termMonths: term,
        startDate: start,
        paidCount: paid,
      ),
    );
  }
}
