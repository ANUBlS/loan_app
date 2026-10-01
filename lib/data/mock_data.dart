import '../models/loan.dart';
import '../utils/loan_math.dart';

class LoanProduct {
  final LoanType type;
  /// Translation key for the short name (chips), e.g. product.consumer
  final String name;

  /// Translation key for the full loan name, e.g. product.consumer_loan
  final String loanName;
  final double annualRate;
  final double minAmount;
  final double maxAmount;
  final double step;
  final int minTerm;
  final int maxTerm;

  const LoanProduct({
    required this.type,
    required this.name,
    required this.loanName,
    required this.annualRate,
    required this.minAmount,
    required this.maxAmount,
    required this.step,
    required this.minTerm,
    required this.maxTerm,
  });

  int get amountDivisions => ((maxAmount - minAmount) / step).round();
}

class LoanDocument {
  /// Translation key of the document name.
  final String nameKey;
  final int sizeKb;
  const LoanDocument(this.nameKey, this.sizeKb);
}

class MockData {
  static const documents = <LoanDocument>[
    LoanDocument('doc.application', 98),
    LoanDocument('doc.schedule', 100),
    LoanDocument('doc.bureau', 118),
    LoanDocument('doc.agreement', 140),
    LoanDocument('doc.insurance', 67),
    LoanDocument('doc.disbursement', 69),
  ];

  static const currency = 'AZN';

  static const products = <LoanProduct>[
    LoanProduct(
      type: LoanType.consumer,
      name: 'product.consumer',
      loanName: 'product.consumer_loan',
      annualRate: 17,
      minAmount: 500,
      maxAmount: 30000,
      step: 100,
      minTerm: 6,
      maxTerm: 60,
    ),
    LoanProduct(
      type: LoanType.car,
      name: 'product.car',
      loanName: 'product.car_loan',
      annualRate: 13.5,
      minAmount: 5000,
      maxAmount: 80000,
      step: 500,
      minTerm: 12,
      maxTerm: 84,
    ),
    LoanProduct(
      type: LoanType.mortgage,
      name: 'product.mortgage',
      loanName: 'product.mortgage_loan',
      annualRate: 8,
      minAmount: 10000,
      maxAmount: 300000,
      step: 1000,
      minTerm: 36,
      maxTerm: 300,
    ),
    LoanProduct(
      type: LoanType.business,
      name: 'product.business',
      loanName: 'product.business_loan',
      annualRate: 15,
      minAmount: 5000,
      maxAmount: 150000,
      step: 1000,
      minTerm: 6,
      maxTerm: 84,
    ),
  ];

  /// Translation keys.
  static const purposes = <String>[
    'purpose.personal',
    'purpose.car',
    'purpose.home',
    'purpose.renovation',
    'purpose.education',
    'purpose.business',
  ];

  /// Dates are relative to today so paid / overdue / next always look realistic.
  static List<Loan> loans() {
    final today = dateOnly(DateTime.now());
    return [
      _loan(
        id: 'L001',
        type: LoanType.consumer,
        name: 'product.consumer_loan',
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
        name: 'product.car_loan',
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
        name: 'product.mortgage_loan',
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
        name: 'product.express_loan',
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
