import 'package:flutter/material.dart';

import '../models/loan.dart';
import '../theme.dart';
import '../utils/format.dart';

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
      LoanState.active => const Pill(
          text: 'Active',
          color: AppColors.primary,
          background: AppColors.primarySoft,
        ),
      LoanState.overdue => const Pill(
          text: 'Overdue',
          color: AppColors.overdue,
          background: AppColors.overdueBg,
        ),
      LoanState.closed => const Pill(
          text: 'Closed',
          color: AppColors.muted,
          background: Color(0xFFEDEFF1),
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

class LoanCard extends StatelessWidget {
  final Loan loan;
  final VoidCallback onTap;

  const LoanCard({super.key, required this.loan, required this.onTap});

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
            border: Border.all(
              color: isOverdue ? AppColors.overdue : AppColors.line,
              width: isOverdue ? 1.5 : 1,
            ),
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
                          loan.productName,
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
                isClosed ? 'Loan amount' : 'Outstanding',
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
              const SizedBox(height: 2),
              Text(
                formatMoney(
                  isClosed ? loan.amount : loan.outstandingPrincipal,
                  loan.currency,
                ),
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
                  backgroundColor: AppColors.line,
                  color: AppColors.paid,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${loan.paidCount} of ${loan.schedule.length} payments made',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.line),
              const SizedBox(height: 12),
              _footer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _footer() {
    const chevron = Icon(Icons.chevron_right, color: AppColors.muted);

    if (loan.state == LoanState.closed) {
      return const Row(
        children: [
          Icon(Icons.verified_outlined, color: AppColors.paid, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Fully repaid',
              style: TextStyle(
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
              'Overdue ${formatMoney(overdue, loan.currency)}',
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
            'Next payment ${formatDate(next.dueDate)}',
            style: const TextStyle(color: AppColors.ink),
          ),
        ),
        Text(
          formatMoney(next.total, loan.currency),
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
