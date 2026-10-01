import 'package:flutter/material.dart';

import '../i18n/l10n.dart';
import '../models/loan.dart';
import '../theme.dart';
import '../utils/format.dart';

const hiddenAmount = '•••••';

IconData loanTypeIcon(LoanType type) => switch (type) {
      LoanType.consumer => Icons.shopping_bag_outlined,
      LoanType.car => Icons.directions_car_outlined,
      LoanType.mortgage => Icons.home_outlined,
      LoanType.business => Icons.storefront_outlined,
    };

class LoanTypeIcon extends StatelessWidget {
  final LoanType type;
  const LoanTypeIcon({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(loanTypeIcon(type), color: AppColors.primary),
    );
  }
}

class Pill extends StatelessWidget {
  final String text;
  final Color color;
  final Color background;

  const Pill({
    super.key,
    required this.text,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class LoanStateChip extends StatelessWidget {
  final LoanState state;
  const LoanStateChip({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      LoanState.active => Pill(
          text: context.tr('state.active'),
          color: AppColors.primary,
          background: AppColors.primarySoft,
        ),
      LoanState.overdue => Pill(
          text: context.tr('state.overdue'),
          color: AppColors.overdue,
          background: AppColors.overdueBg,
        ),
      LoanState.closed => Pill(
          text: context.tr('state.closed'),
          color: AppColors.muted,
          background: const Color(0xFFEDEFF1),
        ),
    };
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
      ),
    );
  }
}

/// White rounded container used for most blocks.
class WhiteCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const WhiteCard({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

class OverdueBanner extends StatelessWidget {
  final int count;
  final double amount;
  final String currency;

  const OverdueBanner({
    super.key,
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

/// Key facts of a loan (amount, rate, term...).
class LoanSummaryCard extends StatelessWidget {
  final Loan loan;
  const LoanSummaryCard({super.key, required this.loan});

  @override
  Widget build(BuildContext context) {
    final c = loan.currency;
    return WhiteCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
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
      padding: const EdgeInsets.symmetric(vertical: 6),
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

class LoanCard extends StatelessWidget {
  final Loan loan;
  final VoidCallback onTap;
  final bool hideAmounts;

  const LoanCard({
    super.key,
    required this.loan,
    required this.onTap,
    this.hideAmounts = false,
  });

  String _money(double v) =>
      hideAmounts ? '$hiddenAmount ${loan.currency}' : formatMoney(v, loan.currency);

  @override
  Widget build(BuildContext context) {
    final state = loan.state;
    final isClosed = state == LoanState.closed;
    final isOverdue = state == LoanState.overdue;
    final progress =
        loan.schedule.isEmpty ? 0.0 : loan.paidCount / loan.schedule.length;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: isOverdue
                ? Border.all(color: AppColors.overdue, width: 1.5)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  LoanTypeIcon(type: loan.type),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr(loan.productName),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          loan.contractNo,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  LoanStateChip(state: state),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                context.tr(isClosed ? 'card.loan_amount' : 'card.outstanding'),
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
              const SizedBox(height: 2),
              Text(
                _money(isClosed ? loan.amount : loan.outstandingPrincipal),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: AppColors.primarySoft,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                context.tr('card.payments_made', {
                  'paid': loan.paidCount,
                  'total': loan.schedule.length,
                }),
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.line),
              const SizedBox(height: 12),
              _footer(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _footer(BuildContext context) {
    const chevron = Icon(Icons.chevron_right, color: AppColors.muted);

    if (loan.state == LoanState.closed) {
      return Row(
        children: [
          const Icon(Icons.verified_outlined, color: AppColors.paid, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.tr('card.fully_repaid'),
              style: const TextStyle(
                color: AppColors.paid,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          chevron,
        ],
      );
    }

    final overdue = loan.overdueAmount();
    if (overdue > 0) {
      return Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.overdue, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.tr('card.overdue_amount', {'amount': _money(overdue)}),
              style: const TextStyle(
                color: AppColors.overdue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          chevron,
        ],
      );
    }

    final next = loan.nextInstallment();
    if (next == null) return const SizedBox.shrink();
    return Row(
      children: [
        const Icon(Icons.event_outlined, color: AppColors.next, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            context.tr('card.next_payment', {'date': formatDate(next.dueDate)}),
            style: const TextStyle(color: AppColors.ink),
          ),
        ),
        Text(
          _money(next.total),
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.next,
          ),
        ),
        chevron,
      ],
    );
  }
}
