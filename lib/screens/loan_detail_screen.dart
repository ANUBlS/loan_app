import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/loan_repository.dart';
import '../i18n/l10n.dart';
import '../models/loan.dart';
import '../services/payment_flow.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/loan_widgets.dart';
import 'documents_screen.dart';
import 'schedule_screen.dart';

/// Blue header with progress, then Operations / History tabs.
class LoanDetailScreen extends StatefulWidget {
  final String loanId;
  const LoanDetailScreen({super.key, required this.loanId});

  @override
  State<LoanDetailScreen> createState() => _LoanDetailScreenState();
}

class _LoanDetailScreenState extends State<LoanDetailScreen> {
  final _repo = LoanRepository.instance;
  int _tab = 0;
  bool _paying = false;

  Future<void> _pay(Loan loan) async {
    setState(() => _paying = true);
    await payNextInstallment(context, loan);
    if (mounted) setState(() => _paying = false);
  }

  void _showInfo(Loan loan) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: LoanSummaryCard(loan: loan),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _repo,
      builder: (context, _) {
        final loan = _repo.byId(widget.loanId);
        if (loan == null) return const Scaffold();

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: Scaffold(
            backgroundColor: AppColors.primary,
            body: Column(
              children: [
                _Header(loan: loan),
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        _Tabs(
                          index: _tab,
                          labels: [
                            context.tr('detail.tab_operations'),
                            context.tr('detail.tab_history'),
                          ],
                          onChanged: (i) => setState(() => _tab = i),
                        ),
                        Expanded(
                          child: _tab == 0
                              ? _operations(context, loan)
                              : _history(context, loan),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _operations(BuildContext context, Loan loan) {
    final inst = loan.firstUnpaid;
    final overdueList = loan.overdueInstallments();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        if (inst == null)
          WhiteCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.verified, color: AppColors.paid),
                const SizedBox(width: 10),
                Text(
                  context.tr('card.fully_repaid'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.paid,
                  ),
                ),
              ],
            ),
          )
        else ...[
          WhiteCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr(
                          overdueList.isNotEmpty
                              ? 'detail.overdue_since'
                              : 'detail.due_on',
                          {'date': formatDate(inst.dueDate)},
                        ),
                        style: TextStyle(
                          fontSize: 13,
                          color: overdueList.isNotEmpty
                              ? AppColors.overdue
                              : AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatMoney(inst.total, loan.currency),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(112, 46),
                    backgroundColor: overdueList.isNotEmpty
                        ? AppColors.overdue
                        : AppColors.primary,
                  ),
                  onPressed: _paying ? null : () => _pay(loan),
                  child: _paying
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(context.tr('detail.pay_now')),
                ),
              ],
            ),
          ),
          if (overdueList.length > 1) ...[
            const SizedBox(height: 12),
            OverdueBanner(
              count: overdueList.length,
              amount: loan.overdueAmount(),
              currency: loan.currency,
            ),
          ],
        ],
        const SizedBox(height: 16),
        WhiteCard(
          child: Column(
            children: [
              _menu(
                Icons.calendar_month_outlined,
                context.tr('detail.schedule'),
                () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ScheduleScreen(loanId: loan.id),
                )),
              ),
              const Divider(height: 1, indent: 56),
              _menu(
                Icons.description_outlined,
                context.tr('detail.contracts'),
                () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => DocumentsScreen(loanId: loan.id),
                )),
              ),
              const Divider(height: 1, indent: 56),
              _menu(
                Icons.info_outline,
                context.tr('detail.info'),
                () => _showInfo(loan),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _menu(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppColors.ink),
      title: Text(
        title,
        style: const TextStyle(fontSize: 16, color: AppColors.ink),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
      onTap: onTap,
    );
  }

  Widget _history(BuildContext context, Loan loan) {
    final paid = loan.schedule.where((i) => i.isPaid).toList().reversed.toList();
    if (paid.isEmpty) {
      return Center(
        child: Text(
          context.tr('detail.history_empty'),
          style: const TextStyle(color: AppColors.muted),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: paid.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) =>
          PaymentTile(installment: paid[i], currency: loan.currency),
    );
  }
}

/// One paid installment, used in loan history and the History tab.
class PaymentTile extends StatelessWidget {
  final Installment installment;
  final String currency;
  final String? subtitle;

  const PaymentTile({
    super.key,
    required this.installment,
    required this.currency,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return WhiteCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.paidBg,
            child: Icon(Icons.check, color: AppColors.paid),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subtitle ??
                      context.tr('detail.payment_n', {'n': installment.number}),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle == null
                      ? formatDate(installment.paidDate!)
                      : '${context.tr('detail.payment_n', {'n': installment.number})}'
                          '  ·  ${formatDate(installment.paidDate!)}',
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              ],
            ),
          ),
          Text(
            '-${formatMoney(installment.total, currency)}',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final Loan loan;
  const _Header({required this.loan});

  @override
  Widget build(BuildContext context) {
    final pct = loan.amount == 0
        ? 0
        : (loan.paidPrincipal / loan.amount * 100).round().clamp(0, 100);
    const white70 = TextStyle(color: Colors.white70, fontSize: 13);
    const big = TextStyle(
      color: Colors.white,
      fontSize: 30,
      fontWeight: FontWeight.w700,
    );
    const amount = TextStyle(
      color: Colors.white,
      fontSize: 16,
      fontWeight: FontWeight.w600,
    );

    return Container(
      decoration: const BoxDecoration(gradient: AppColors.headerGradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  Expanded(
                    child: Text(
                      context.tr(loan.productName),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('$pct %', style: big),
                              Text(context.tr('detail.paid_pct'),
                                  style: white70),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${loan.paidCount}/${loan.schedule.length}',
                              style: big,
                            ),
                            Text(context.tr('detail.payments_made'),
                                style: white70),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct / 100,
                        minHeight: 6,
                        backgroundColor: Colors.white24,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(formatMoney(loan.paidTotal, loan.currency),
                                  style: amount),
                              Text(context.tr('detail.paid'), style: white70),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              formatMoney(
                                  loan.outstandingPrincipal, loan.currency),
                              style: amount,
                            ),
                            Text(context.tr('detail.remaining'),
                                style: white70),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  final int index;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  const _Tabs({
    required this.index,
    required this.labels,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => onChanged(i),
                child: Column(
                  children: [
                    Text(
                      labels[i],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight:
                            i == index ? FontWeight.w600 : FontWeight.w400,
                        color: i == index ? AppColors.ink : AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 3,
                      color: i == index ? AppColors.primary : AppColors.line,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
