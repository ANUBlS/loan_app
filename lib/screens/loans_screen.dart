import 'package:flutter/material.dart';

import '../data/loan_repository.dart';
import '../i18n/l10n.dart';
import '../models/loan.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/loan_widgets.dart';
import '../widgets/profile_menu.dart';
import 'schedule_screen.dart';

class LoansScreen extends StatelessWidget {
  final VoidCallback onOrderLoan;
  const LoansScreen({super.key, required this.onOrderLoan});

  @override
  Widget build(BuildContext context) {
    final repo = LoanRepository.instance;

    return Scaffold(
      appBar: AppBar(
        leading: const ProfileAvatarButton(),
        title: Text(context.tr('loans.title')),
      ),
      body: ListenableBuilder(
        listenable: repo,
        builder: (context, _) {
          final loans = repo.loans;
          final applications = repo.applications;
          final open = loans.where((l) => l.state != LoanState.closed).toList();
          final outstanding =
              open.fold<double>(0, (s, l) => s + l.outstandingPrincipal);
          final overdue = open.fold<double>(0, (s, l) => s + l.overdueAmount());

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              _SummaryCard(
                outstanding: outstanding,
                overdue: overdue,
                openCount: open.length,
              ),
              if (applications.isNotEmpty) ...[
                SectionTitle(context.tr('loans.applications')),
                for (final a in applications)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ApplicationTile(application: a),
                  ),
              ],
              SectionTitle(context.tr('loans.section', {'n': loans.length})),
              if (loans.isEmpty)
                _EmptyState(onOrderLoan: onOrderLoan)
              else
                for (final loan in loans)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: LoanCard(
                      loan: loan,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ScheduleScreen(loan: loan),
                        ),
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final double outstanding;
  final double overdue;
  final int openCount;

  const _SummaryCard({
    required this.outstanding,
    required this.overdue,
    required this.openCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('loans.total_outstanding'),
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 6),
          Text(
            formatMoney(outstanding),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _stat(
                  context.tr('loans.open_loans'),
                  '$openCount',
                  Colors.white,
                ),
              ),
              Expanded(
                child: _stat(
                  context.tr('loans.overdue'),
                  formatMoney(overdue),
                  overdue > 0 ? const Color(0xFFFF8A80) : Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ApplicationTile extends StatelessWidget {
  final LoanApplication application;
  const _ApplicationTile({required this.application});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          LoanTypeIcon(type: application.type),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(application.productName),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.tr('loans.app_line', {
                    'amount':
                        formatMoney(application.amount, application.currency),
                    'term': formatTerm(application.termMonths),
                  }),
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              ],
            ),
          ),
          Pill(
            text: context.tr('loans.under_review'),
            color: AppColors.next,
            background: AppColors.nextBg,
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onOrderLoan;
  const _EmptyState({required this.onOrderLoan});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr('loans.empty'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: AppColors.ink),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onOrderLoan,
            child: Text(context.tr('loans.order_button')),
          ),
        ],
      ),
    );
  }
}
