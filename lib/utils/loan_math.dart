import 'dart:math' as math;

import '../models/loan.dart';

double round2(double v) => (v * 100).roundToDouble() / 100;

/// Monthly annuity payment. [annualRatePercent] e.g. 18 for 18%.
double annuityPayment(double principal, double annualRatePercent, int months) {
  if (months <= 0) return 0;
  final r = annualRatePercent / 12 / 100;
  if (r == 0) return principal / months;
  return principal * r / (1 - math.pow(1 + r, -months));
}

/// Adds calendar months, clamping the day (31 Jan + 1 month = 28/29 Feb).
DateTime addMonths(DateTime d, int months) {
  final total = d.month - 1 + months;
  final year = d.year + (total / 12).floor();
  final month = total % 12 + 1;
  final lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, math.min(d.day, lastDay));
}

/// Builds an annuity schedule. The first [paidCount] installments are marked paid.
List<Installment> buildSchedule({
  required double amount,
  required double annualRate,
  required int termMonths,
  required DateTime startDate,
  int paidCount = 0,
}) {
  final r = annualRate / 12 / 100;
  final payment = annuityPayment(amount, annualRate, termMonths);
  var balance = amount;
  final list = <Installment>[];

  for (var k = 1; k <= termMonths; k++) {
    final interest = round2(balance * r);
    var principal = round2(payment - interest);
    if (k == termMonths) principal = round2(balance);
    balance = round2(balance - principal);
    final due = addMonths(startDate, k);

    list.add(Installment(
      number: k,
      dueDate: due,
      principal: principal,
      interest: interest,
      balanceAfter: balance < 0 ? 0 : balance,
      paidDate: k <= paidCount ? due.subtract(Duration(days: k % 3)) : null,
    ));
  }
  return list;
}
