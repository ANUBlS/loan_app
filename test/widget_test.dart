import 'package:flutter_test/flutter_test.dart';
import 'package:loan_app/utils/loan_math.dart';

void main() {
  test('zero-rate annuity splits evenly', () {
    expect(annuityPayment(12000, 0, 12), 1000);
  });

  test('schedule principal sums to loan amount', () {
    final schedule = buildSchedule(
      amount: 5000,
      annualRate: 18,
      termMonths: 24,
      startDate: DateTime(2025, 1, 31),
    );
    final principal = schedule.fold<double>(0, (s, i) => s + i.principal);
    expect(round2(principal), 5000);
    expect(schedule.last.balanceAfter, 0);
    expect(schedule[0].dueDate, DateTime(2025, 2, 28));
  });
}
