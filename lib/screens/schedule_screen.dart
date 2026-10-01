import 'package:flutter/material.dart';

import '../data/loan_repository.dart';
import '../i18n/l10n.dart';
import '../models/loan.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/loan_widgets.dart';

/// Payment schedule as a table: Next / Past / All.
/// Rows: paid = green, overdue = red, next = blue, upcoming = white.
class ScheduleScreen extends StatefulWidget {
  final String loanId;
  const ScheduleScreen({super.key, required this.loanId});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  int _filter = 0; // 0 next, 1 past, 2 all

  void _showRow(Installment inst, InstallmentStatus status, Loan loan) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: InstallmentTile(
            installment: inst,
            status: status,
            currency: loan.currency,
            today: DateTime.now(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = LoanRepository.instance;
    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final loan = repo.byId(widget.loanId);
        if (loan == null) return const Scaffold();

        final now = DateTime.now();
        final overdue = loan.overdueInstallments(now);
        final rows = switch (_filter) {
          0 => loan.schedule.where((i) => !i.isPaid).toList(),
          1 => loan.schedule.where((i) => i.isPaid).toList(),
          _ => loan.schedule,
        };
        final filters = [
          context.tr('schedule.tab_next'),
          context.tr('schedule.tab_past'),
          context.tr('schedule.tab_all'),
        ];

        return Scaffold(
          appBar: AppBar(title: Text(context.tr('schedule.title'))),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              Text(
                context.tr('schedule.account'),
                style: const TextStyle(fontSize: 14, color: AppColors.ink),
              ),
              const SizedBox(height: 2),
              Text(
                loan.contractNo,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 18),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var i = 0; i < filters.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          showCheckmark: false,
                          label: Text(
                            filters[i],
                            style: TextStyle(
                              color: i == _filter
                                  ? AppColors.primary
                                  : AppColors.ink,
                              fontWeight: i == _filter
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                          selected: i == _filter,
                          onSelected: (_) => setState(() => _filter = i),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const _Legend(),
              if (overdue.isNotEmpty) ...[
                const SizedBox(height: 12),
                OverdueBanner(
                  count: overdue.length,
                  amount: loan.overdueAmount(now),
                  currency: loan.currency,
                ),
              ],
              const SizedBox(height: 12),
              Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.line),
                ),
                child: Column(
                  children: [
                    Container(
                      color: AppColors.tableHeader,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          _head(context.tr('schedule.col_date'), 3),
                          _head(context.tr('schedule.col_amount'), 2),
                          _head(context.tr('schedule.col_principal'), 2),
                          _head(context.tr('schedule.col_interest'), 2),
                        ],
                      ),
                    ),
                    if (rows.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          context.tr('schedule.empty'),
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ),
                    for (final inst in rows)
                      _row(inst, loan.statusOf(inst, now), loan),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _head(String text, int flex) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 2,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
      ),
    );
  }

  Widget _row(Installment inst, InstallmentStatus status, Loan loan) {
    final style = StatusStyle.of(status);
    final textColor =
        status == InstallmentStatus.overdue ? AppColors.overdue : AppColors.ink;
    final cell = TextStyle(fontSize: 13, color: textColor);

    return InkWell(
      onTap: () => _showRow(inst, status, loan),
      child: Container(
        decoration: BoxDecoration(
          color: style.background,
          border: const Border(top: BorderSide(color: AppColors.line)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: status == InstallmentStatus.upcoming
                          ? AppColors.line
                          : style.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    formatDate(inst.dueDate),
                    style: cell.copyWith(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                formatAmount(inst.total),
                textAlign: TextAlign.center,
                style: cell.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                formatAmount(inst.principal),
                textAlign: TextAlign.center,
                style: cell,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                formatAmount(inst.interest),
                textAlign: TextAlign.center,
                style: cell,
              ),
            ),
          ],
        ),
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

/// Detail card of one installment (shown when a table row is tapped).
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isUpcoming ? AppColors.line : style.color),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isUpcoming ? Colors.white : style.color,
              shape: BoxShape.circle,
              border: isUpcoming ? Border.all(color: AppColors.line) : null,
            ),
            child: status == InstallmentStatus.paid
                ? const Icon(Icons.check, size: 20, color: Colors.white)
                : Text(
                    '${installment.number}',
                    style: TextStyle(
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
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _caption(context),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isUpcoming ? AppColors.muted : style.color,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatMoney(installment.total, currency),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                context.tr('inst.principal',
                    {'v': formatAmount(installment.principal)}),
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              Text(
                context.tr('inst.interest',
                    {'v': formatAmount(installment.interest)}),
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
