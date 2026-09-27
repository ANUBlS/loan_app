import 'package:flutter/material.dart';

import '../data/loan_repository.dart';
import '../models/loan.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/loan_widgets.dart';
import 'register_screen.dart';
import 'schedule_screen.dart';

class LoansScreen extends StatelessWidget {
  final VoidCallback onOrderLoan;
  const LoansScreen({super.key, required this.onOrderLoan});

  Future<void> _confirmReset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out and reset?'),
        content: const Text(
          'The user is removed from this device. '
          'You will register and scan biometrics again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await AuthService().reset();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = LoanRepository.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My loans'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'reset') _confirmReset(context);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'reset', child: Text('Sign out and reset')),
            ],
          ),
        ],
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
                const SectionTitle('Applications'),
                for (final a in applications)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ApplicationTile(application: a),
                  ),
              ],
              SectionTitle('Loans (${loans.length})'),
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
          const Text(
            'Total outstanding',
            style: TextStyle(color: Colors.white70, fontSize: 14),
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
              Expanded(child: _stat('Open loans', '$openCount', Colors.white)),
              Expanded(
                child: _stat(
                  'Overdue',
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
                  application.productName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatMoney(application.amount, application.currency)}, '
                  '${application.termMonths} months',
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const Pill(
            text: 'Under review',
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
          const Text(
            'You have no loans yet.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: AppColors.ink),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onOrderLoan,
            child: const Text('Order a loan'),
          ),
        ],
      ),
    );
  }
}
