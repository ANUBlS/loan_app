import 'package:flutter/material.dart';

import '../data/loan_repository.dart';
import '../data/mock_data.dart';
import '../i18n/l10n.dart';
import '../models/loan.dart';
import '../theme.dart';
import '../widgets/loan_widgets.dart';

/// Contracts of one loan ([loanId]) or of all loans (Documents tab).
class DocumentsScreen extends StatelessWidget {
  final String? loanId;
  const DocumentsScreen({super.key, this.loanId});

  @override
  Widget build(BuildContext context) {
    final repo = LoanRepository.instance;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('docs.title'))),
      body: ListenableBuilder(
        listenable: repo,
        builder: (context, _) {
          final List<Loan> loans;
          if (loanId == null) {
            loans = repo.loans;
          } else {
            final loan = repo.byId(loanId!);
            loans = loan == null ? <Loan>[] : [loan];
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              for (final loan in loans) ...[
                if (loanId == null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                    child: Text(
                      '${context.tr(loan.productName)}  ·  ${loan.contractNo}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                WhiteCard(
                  child: Column(
                    children: [
                      for (var i = 0; i < MockData.documents.length; i++) ...[
                        if (i > 0) const Divider(height: 1, indent: 68),
                        _DocTile(doc: MockData.documents[i]),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _DocTile extends StatelessWidget {
  final LoanDocument doc;
  const _DocTile({required this.doc});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.paidBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.picture_as_pdf_outlined, color: AppColors.paid),
      ),
      title: Text(
        context.tr(doc.nameKey),
        style: const TextStyle(fontSize: 15, color: AppColors.ink),
      ),
      subtitle: Text(
        context.tr('docs.size', {'kb': doc.sizeKb}),
        style: const TextStyle(fontSize: 12, color: AppColors.muted),
      ),
      trailing: TextButton(
        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('docs.mock'))),
        ),
        child: Text(context.tr('docs.read')),
      ),
    );
  }
}
