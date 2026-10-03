import 'package:flutter/material.dart';

import '../data/loan_repository.dart';
import '../i18n/l10n.dart';
import '../models/loan.dart';
import '../utils/format.dart';
import 'identity.dart';

/// Confirm -> biometrics or passcode -> mark the earliest unpaid installment as paid.
/// Used by the home carousel and the loan screen.
Future<bool> payNextInstallment(BuildContext context, Loan loan) async {
  final inst = loan.firstUnpaid;
  if (inst == null) return false;
  final l = L10n.instance;
  final amount = formatMoney(inst.total, loan.currency);

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(ctx.tr('pay.confirm_title')),
      content: Text(ctx.tr('pay.confirm_body', {
        'amount': amount,
        'n': inst.number,
        'loan': ctx.tr(loan.productName),
      })),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(ctx.tr('common.cancel')),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(ctx.tr('detail.pay_now')),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;

  final ok = await confirmIdentity(context, l.t('pay.reason'));
  if (!ok || !context.mounted) return false;
  final messenger = ScaffoldMessenger.of(context);

  LoanRepository.instance.payNext(loan.id);
  messenger.showSnackBar(
    SnackBar(content: Text(l.t('pay.success', {'amount': amount}))),
  );
  return true;
}
