import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../data/loan_repository.dart';
import '../i18n/l10n.dart';
import '../models/loan.dart';
import '../services/amount_visibility.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/loan_carousel.dart';
import '../widgets/loan_widgets.dart';
import '../widgets/profile_menu.dart';
import '../widgets/server_dialog.dart';
import 'all_loans_screen.dart';
import 'loan_detail_screen.dart';
import 'register_screen.dart';
import 'schedule_screen.dart';

/// Home tab: greeting, quick actions, swipeable loan cards, summary.
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
  final _visibility = AmountVisibility.instance;
  String _name = '';

  /// Saved on the device (see AmountVisibility), so it survives app restarts.
  bool get _hidden => _visibility.hidden;

  @override
  void initState() {
    super.initState();
    _visibility.addListener(_onVisibilityChanged);
    AuthService().userName().then((n) {
      if (mounted) setState(() => _name = n);
    });
  }

  @override
  void dispose() {
    _visibility.removeListener(_onVisibilityChanged);
    super.dispose();
  }

  void _onVisibilityChanged() {
    if (mounted) setState(() {});
  }

  String _money(double v) => _hidden ? '$hiddenAmount AZN' : formatMoney(v);

  void _openLoan(Loan loan) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LoanDetailScreen(loanId: loan.id)),
    );
  }

  void _openUrgentSchedule() {
    final loan = _repo.urgentLoan;
    if (loan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.instance.t('home.nothing_to_pay'))),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ScheduleScreen(loanId: loan.id)),
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

            return RefreshIndicator(
              onRefresh: _repo.refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
                children: [
                  // Header: avatar, greeting, eye, bell
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
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
                          onPressed: _visibility.toggle,
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
                  ),
                  const SizedBox(height: 12),

                  // Loading / connection problems
                  if (_repo.isLoading && !_repo.hasData)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: LinearProgressIndicator(),
                    ),
                  if (_repo.error != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: _ErrorCard(error: _repo.error!),
                    ),
                  const SizedBox(height: 4),

                  // Quick actions
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _tile(Icons.add_card, AppColors.primary,
                            context.tr('home.action_order'), widget.onOrderLoan),
                        _tile(Icons.calendar_month, const Color(0xFF7C3AED),
                            context.tr('home.action_schedule'),
                            _openUrgentSchedule),
                        _tile(Icons.description, const Color(0xFF0EA5E9),
                            context.tr('home.action_docs'),
                            () => widget.onOpenTab(2)),
                        _tile(Icons.translate, const Color(0xFFF97316),
                            context.tr('home.action_language'),
                            () => showLanguagePicker(context)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Swipeable loan cards (edge to edge, like the video)
                  LoanCarousel(
                    loans: loans,
                    hideAmounts: _hidden,
                    onOpen: _openLoan,
                    onOrder: widget.onOrderLoan,
                  ),
                  const SizedBox(height: 14),

                  // "All my loans" pill
                  Center(
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AllLoansScreen(),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 10),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                context.tr('loans.all_button'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.ink,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.arrow_forward,
                                  size: 18, color: AppColors.ink),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Compact summary
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: WhiteCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.tr('loans.total_outstanding'),
                                  style: const TextStyle(
                                      fontSize: 13, color: AppColors.muted),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _money(outstanding),
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.ink,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  context.tr('home.open_count',
                                      {'n': open.length}),
                                  style: const TextStyle(
                                      fontSize: 13, color: AppColors.muted),
                                ),
                              ],
                            ),
                          ),
                          if (overdue > 0)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  context.tr('state.overdue'),
                                  style: const TextStyle(
                                      fontSize: 13, color: AppColors.overdue),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _money(overdue),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.overdue,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),

                  if (applications.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SectionTitle(context.tr('loans.applications')),
                          for (final a in applications)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _ApplicationTile(application: a),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
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
          application.status == 'rejected'
              ? Pill(
                  text: context.tr('loans.rejected'),
                  color: AppColors.overdue,
                  background: AppColors.overdueBg,
                )
              : Pill(
                  text: context.tr('loans.under_review'),
                  color: AppColors.next,
                  background: AppColors.nextBg,
                ),
        ],
      ),
    );
  }
}

/// Shown on Home when the server could not be reached or the session ended.
class _ErrorCard extends StatelessWidget {
  final ApiException error;
  const _ErrorCard({required this.error});

  @override
  Widget build(BuildContext context) {
    final repo = LoanRepository.instance;
    return WhiteCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                error.isNetwork ? Icons.cloud_off_outlined : Icons.error_outline,
                color: AppColors.overdue,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  error.userMessage,
                  style: const TextStyle(color: AppColors.ink),
                ),
              ),
            ],
          ),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 4,
            children: [
              if (error.isSessionExpired)
                TextButton(
                  onPressed: () => AuthService().signOut().then((_) {
                    if (!context.mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                      (_) => false,
                    );
                  }),
                  child: Text(context.tr('home.sign_in_again')),
                )
              else ...[
                if (error.isNetwork)
                  TextButton(
                    onPressed: () => showServerDialog(context),
                    child: Text(context.tr('server.title')),
                  ),
                TextButton(
                  onPressed: repo.isLoading ? null : repo.refresh,
                  child: Text(context.tr('common.retry')),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
