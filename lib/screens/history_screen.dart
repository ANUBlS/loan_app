import 'package:flutter/material.dart';

import '../data/loan_repository.dart';
import '../i18n/l10n.dart';
import '../theme.dart';
import 'loan_detail_screen.dart';

/// All payments of all loans, newest first.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = LoanRepository.instance;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('history.title'))),
      body: ListenableBuilder(
        listenable: repo,
        builder: (context, _) {
          final items = repo.paymentHistory;
          if (items.isEmpty) {
            return Center(
              child: Text(
                context.tr('history.empty'),
                style: const TextStyle(color: AppColors.muted),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final (loan, inst) = items[i];
              return PaymentTile(
                installment: inst,
                currency: loan.currency,
                subtitle: context.tr(loan.productName),
              );
            },
          );
        },
      ),
    );
  }
}
