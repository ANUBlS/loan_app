import 'package:flutter/material.dart';

import '../data/loan_repository.dart';
import '../i18n/l10n.dart';
import '../widgets/loan_widgets.dart';
import 'loan_detail_screen.dart';

/// Full list of loans ("All my loans").
class AllLoansScreen extends StatelessWidget {
  const AllLoansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = LoanRepository.instance;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('loans.all_title'))),
      body: ListenableBuilder(
        listenable: repo,
        builder: (context, _) {
          final loans = repo.loans;
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            itemCount: loans.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) => LoanCard(
              loan: loans[i],
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LoanDetailScreen(loanId: loans[i].id),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
