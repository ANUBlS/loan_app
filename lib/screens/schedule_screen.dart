import 'package:flutter/material.dart';

import '../i18n/l10n.dart';
import '../models/loan.dart';
import '../theme.dart';
import '../utils/format.dart';

class ScheduleScreen extends StatefulWidget {
  final Loan loan;
  const ScheduleScreen({super.key, required this.loan});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final _focusKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    // Scroll to the first overdue payment, or the next one.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _focusKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOut,
          alignment: 0.3,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final loan = widget.loan;
    final now = DateTime.now();
    final overdue = loan.overdueInstallments(now);
    final focus = overdue.isNotEmpty ? overdue.first : loan.nextInstallment(now);

    return Scaffold(
      appBar: AppBar(title: Text(context.tr(loan.productName))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _LoanSummary(loan: loan),
            if (overdue.isNotEmpty) ...[
              const SizedBox(height: 12),
              _OverdueBanner(
                count: overdue.length,
                amount: loan.overdueAmount(now),
                currency: loan.currency,
              ),
            ],
            const SizedBox(height: 22),
            Row(
              children: [
                Text(
                  context.tr('schedule.title'),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const Spacer(),
                Text(
                  context.tr('schedule.paid_count', {
                    'paid': loan.paidCount,
                    'total': loan.schedule.length,
                  }),
                  style: const TextStyle(color: AppColors.muted),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const _Legend(),
            const SizedBox(height: 14),
            for (final inst in loan.schedule)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InstallmentTile(
                  key: focus != null && inst.number == focus.number
                      ? _focusKey
                      : null,
                  installment: inst,
                  status: loan.statusOf(inst, now),
                  currency: loan.currency,
                  today: now,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LoanSummary extends StatelessWidget {
  final Loan loan;
  const _LoanSummary({required this.loan});

  @override
  Widget build(BuildContext context) {
    final c = loan.currency;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          _row(context.tr('schedule.contract'), loan.contractNo),
          _row(context.tr('schedule.loan_amount'), formatMoney(loan.amount, c)),
          _row(
            context.tr('schedule.rate'),
            context.tr('schedule.rate_value',
                {'rate': loan.annualRate.toStringAsFixed(1)}),
          ),
          _row(context.tr('schedule.term'), formatTerm(loan.termMonths)),
          _row(context.tr('schedule.monthly'),
              formatMoney(loan.monthlyPayment, c)),
          _row(context.tr('schedule.paid_so_far'),
              formatMoney(loan.paidTotal, c), AppColors.paid),
          _row(context.tr('schedule.outstanding'),
              formatMoney(loan.outstandingPrincipal, c)),
          _row(context.tr('schedule.opened'), formatDate(loan.startDate)),
          if (loan.finalPaymentDate != null)
            _row(context.tr('schedule.final_payment'),
                formatDate(loan.finalPaymentDate!)),
        ],
      ),
    );
  }

  Widget _row(String label, String value, [Color color = AppColors.ink]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: AppColors.muted)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(fontWeight: FontWeight.w600, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverdueBanner extends StatelessWidget {
  final int count;
  final double amount;
  final String currency;

  const _OverdueBanner({
    required this.count,
    required this.amount,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.overdueBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.overdue),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.overdue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.trn('schedule.overdue_banner', count,
                  {'amount': formatMoney(amount, currency)}),
              style: const TextStyle(
                color: AppColors.overdue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        for (final s in InstallmentStatus.values) _item(context, s),
      ],
    );
  }

  Widget _item(BuildContext context, InstallmentStatus status) {
    final style = StatusStyle.of(status);
    final isUpcoming = status == InstallmentStatus.upcoming;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: isUpcoming ? Colors.white : style.color,
            shape: BoxShape.circle,
            border: isUpcoming ? Border.all(color: AppColors.upcoming) : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          context.tr(style.label),
          style: const TextStyle(fontSize: 13, color: AppColors.ink),
        ),
      ],
    );
  }
}

class InstallmentTile extends StatelessWidget {
  final Installment installment;
  final InstallmentStatus status;
  final String currency;
  final DateTime today;

  const InstallmentTile({
    super.key,
    required this.installment,
    required this.status,
    required this.currency,
    required this.today,
  });

  String _caption(BuildContext context) {
    final overdueDays = daysBetween(installment.dueDate, today);
    final daysLeft = daysBetween(today, installment.dueDate);
    return switch (status) {
      InstallmentStatus.paid => context.tr(
          'inst.paid_on', {'date': formatDate(installment.paidDate!)}),
      InstallmentStatus.overdue => context.trn('inst.overdue_by', overdueDays),
      InstallmentStatus.next => daysLeft == 0
          ? context.tr('inst.due_today')
          : context.trn('inst.due_in', daysLeft),
      InstallmentStatus.upcoming => context.tr('inst.scheduled'),
    };
  }

  @override
  Widget build(BuildContext context) {
    final style = StatusStyle.of(status);
    final isUpcoming = status == InstallmentStatus.upcoming;
    final emphasized = status == InstallmentStatus.next ||
        status == InstallmentStatus.overdue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isUpcoming ? AppColors.line : style.color,
          width: emphasized ? 1.6 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isUpcoming ? Colors.white : style.color,
              shape: BoxShape.circle,
              border: isUpcoming ? Border.all(color: AppColors.line) : null,
            ),
            child: status == InstallmentStatus.paid
                ? const Icon(Icons.check, size: 18, color: Colors.white)
                : Text(
                    '${installment.number}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isUpcoming ? AppColors.muted : Colors.white,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '#${installment.number}  ${formatDate(installment.dueDate)}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _caption(context),
                  style: TextStyle(
                    fontSize: 13,
                    color: isUpcoming ? AppColors.muted : style.color,
                    fontWeight: emphasized ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatMoney(installment.total, currency),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                context.tr('inst.principal',
                    {'v': formatAmount(installment.principal)}),
                style: const TextStyle(fontSize: 11, color: AppColors.muted),
              ),
              Text(
                context.tr('inst.interest',
                    {'v': formatAmount(installment.interest)}),
                style: const TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
