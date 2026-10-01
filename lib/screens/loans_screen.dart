import 'package:flutter/material.dart';

import '../data/loan_repository.dart';
import '../i18n/l10n.dart';
import '../models/loan.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/loan_widgets.dart';
import '../widgets/profile_menu.dart';
import 'loan_detail_screen.dart';
import 'schedule_screen.dart';

/// Home tab: greeting, quick actions, summary card and the list of loans.
class LoansScreen extends StatefulWidget {
  final VoidCallback onOrderLoan;
  final ValueChanged<int> onOpenTab;

  const LoansScreen({
    super.key,
    required this.onOrderLoan,
    required this.onOpenTab,
  });

  @override
  State<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends State<LoansScreen> {
  final _repo = LoanRepository.instance;
  String _name = '';
  bool _hidden = false;

  @override
  void initState() {
    super.initState();
    AuthService().userName().then((n) {
      if (mounted) setState(() => _name = n);
    });
  }

  String _money(double v) =>
      _hidden ? '$hiddenAmount AZN' : formatMoney(v);

  void _openLoan(Loan loan) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LoanDetailScreen(loanId: loan.id)),
    );
  }

  void _openUrgent({bool schedule = false}) {
    final loan = _repo.urgentLoan;
    if (loan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.instance.t('home.nothing_to_pay'))),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => schedule
            ? ScheduleScreen(loanId: loan.id)
            : LoanDetailScreen(loanId: loan.id),
      ),
    );
  }

  List<(Color, IconData, String)> _alerts(BuildContext context) {
    final today = dateOnly(DateTime.now());
    final list = <(Color, IconData, String)>[];
    for (final loan in _repo.loans) {
      final name = context.tr(loan.productName);
      final overdue = loan.overdueAmount();
      if (overdue > 0) {
        list.add((
          AppColors.overdue,
          Icons.error_outline,
          context.tr('notif.overdue',
              {'loan': name, 'amount': formatMoney(overdue, loan.currency)}),
        ));
        continue;
      }
      final next = loan.nextInstallment();
      if (next != null && daysBetween(today, next.dueDate) <= 7) {
        list.add((
          AppColors.primary,
          Icons.event_outlined,
          context.tr('notif.due', {
            'loan': name,
            'amount': formatMoney(next.total, loan.currency),
            'date': formatDate(next.dueDate),
          }),
        ));
      }
    }
    return list;
  }

  void _showNotifications() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final alerts = _alerts(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  ctx.tr('notif.title'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 12),
                if (alerts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      ctx.tr('notif.empty'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  )
                else
                  for (final a in alerts)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(a.$2, color: a.$1, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              a.$3,
                              style: const TextStyle(color: AppColors.ink),
                            ),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: _repo,
          builder: (context, _) {
            final loans = _repo.loans;
            final applications = _repo.applications;
            final open =
                loans.where((l) => l.state != LoanState.closed).toList();
            final outstanding =
                open.fold<double>(0, (s, l) => s + l.outstandingPrincipal);
            final overdue =
                open.fold<double>(0, (s, l) => s + l.overdueAmount());
            final hasAlerts = _alerts(context).isNotEmpty;
            final firstName = _name.trim().split(' ').first;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                // Header: avatar, greeting, eye, bell
                Row(
                  children: [
                    const ProfileAvatarButton(),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        firstName.isEmpty
                            ? context.tr('home.greeting_plain')
                            : context.tr('home.greeting', {'name': firstName}),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _hidden = !_hidden),
                      icon: Icon(
                        _hidden
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppColors.ink,
                      ),
                    ),
                    IconButton(
                      onPressed: _showNotifications,
                      icon: Badge(
                        isLabelVisible: hasAlerts,
                        smallSize: 9,
                        child: const Icon(
                          Icons.notifications_none,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Quick actions
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _tile(Icons.add_card, AppColors.primary,
                        context.tr('home.action_order'), widget.onOrderLoan),
                    _tile(Icons.calendar_month, const Color(0xFF7C3AED),
                        context.tr('home.action_schedule'),
                        () => _openUrgent(schedule: true)),
                    _tile(Icons.description, const Color(0xFF0EA5E9),
                        context.tr('home.action_docs'),
                        () => widget.onOpenTab(2)),
                    _tile(Icons.translate, const Color(0xFFF97316),
                        context.tr('home.action_language'),
                        () => showLanguagePicker(context)),
                  ],
                ),
                const SizedBox(height: 16),

                // Summary card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.cardBlue,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('loans.total_outstanding'),
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _money(outstanding),
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          Pill(
                            text: context.tr('home.open_count',
                                {'n': open.length}),
                            color: AppColors.ink,
                            background: Colors.white,
                          ),
                          if (overdue > 0)
                            Pill(
                              text: context.tr('card.overdue_amount',
                                  {'amount': _money(overdue)}),
                              color: AppColors.overdue,
                              background: Colors.white,
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _blueButton(Icons.payments_outlined,
                                context.tr('home.pay'), _openUrgent),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _blueButton(Icons.history,
                                context.tr('home.history'),
                                () => widget.onOpenTab(1)),
                          ),
                        ],
                      ),
                    ],
                  ),
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
                  _EmptyState(onOrderLoan: widget.onOrderLoan)
                else
                  for (final loan in loans)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: LoanCard(
                        loan: loan,
                        hideAmounts: _hidden,
                        onTap: () => _openLoan(loan),
                      ),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _tile(IconData icon, Color color, String label, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: const TextStyle(fontSize: 12, color: AppColors.ink),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _blueButton(IconData icon, String label, VoidCallback onTap) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      label: Text(label, overflow: TextOverflow.ellipsis),
    );
  }
}

class _ApplicationTile extends StatelessWidget {
  final LoanApplication application;
  const _ApplicationTile({required this.application});

  @override
  Widget build(BuildContext context) {
    return WhiteCard(
      padding: const EdgeInsets.all(14),
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
    return WhiteCard(
      padding: const EdgeInsets.all(24),
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
