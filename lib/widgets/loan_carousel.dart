import 'package:flutter/material.dart';

import '../i18n/l10n.dart';
import '../models/loan.dart';
import '../services/payment_flow.dart';
import '../theme.dart';
import '../utils/format.dart';
import 'loan_widgets.dart';

/// Swipeable stack of loan cards, one loan per card,
/// plus a last card for ordering a new loan.
class LoanCarousel extends StatefulWidget {
  final List<Loan> loans;
  final bool hideAmounts;
  final ValueChanged<Loan> onOpen;
  final VoidCallback onOrder;

  const LoanCarousel({
    super.key,
    required this.loans,
    required this.hideAmounts,
    required this.onOpen,
    required this.onOrder,
  });

  @override
  State<LoanCarousel> createState() => _LoanCarouselState();
}

class _LoanCarouselState extends State<LoanCarousel> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _colorAt(int i) =>
      i < widget.loans.length ? _slideColor(widget.loans[i]) : Colors.white;

  /// Current scroll position in pages (e.g. 1.4 while swiping 1 -> 2).
  double get _position =>
      _controller.hasClients && _controller.position.haveDimensions
          ? _controller.page ?? _page.toDouble()
          : _page.toDouble();

  @override
  Widget build(BuildContext context) {
    final count = widget.loans.length + 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final pos = _position.clamp(0.0, (count - 1).toDouble());
          final current = pos.round();
          final nextIndex = current + 1 < count ? current + 1 : current;
          final behind = Color.lerp(_colorAt(nextIndex), Colors.black, 0.10)!;

          return Column(
            children: [
              SizedBox(
                height: 258,
                child: Stack(
                  children: [
                    // Edge of the next card, peeking behind (stays still).
                    Positioned(
                      top: 0,
                      left: 16,
                      right: 16,
                      height: 30,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        decoration: BoxDecoration(
                          color: behind,
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      top: 9,
                      child: LayoutBuilder(
                        builder: (context, box) => PageView.builder(
                          controller: _controller,
                          itemCount: count,
                          onPageChanged: (i) => setState(() => _page = i),
                          itemBuilder: (context, i) => _fade(
                            index: i,
                            pos: pos,
                            width: box.maxWidth,
                            child: i < widget.loans.length
                                ? _LoanSlide(
                                    loan: widget.loans[i],
                                    hideAmounts: widget.hideAmounts,
                                    onOpen: () => widget.onOpen(widget.loans[i]),
                                  )
                                : _NewLoanSlide(onOrder: widget.onOrder),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < count; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == current ? 18 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: i == current
                            ? AppColors.primary
                            : const Color(0xFFCBD2DC),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  /// Keeps every card in the same spot: the leaving card drifts a little,
  /// shrinks and fades out while the next card fades in underneath.
  Widget _fade({
    required int index,
    required double pos,
    required double width,
    required Widget child,
  }) {
    final delta = index - pos; // 0 = fully visible
    final d = delta.abs().clamp(0.0, 1.0);
    final opacity = (1 - d * 1.15).clamp(0.0, 1.0);
    final scale = 1 - 0.06 * d;
    // Cancel most of the page slide so cards cross-fade in place.
    final dx = -delta * width * 0.88;

    return Transform.translate(
      offset: Offset(dx, 0),
      child: Transform.scale(
        scale: scale,
        child: Opacity(
          opacity: opacity,
          child: IgnorePointer(ignoring: d > 0.5, child: child),
        ),
      ),
    );
  }
}

/// Rounded tappable card surface.
class _CardSurface extends StatelessWidget {
  final Color color;
  final VoidCallback? onTap;
  final Widget child;

  const _CardSurface({required this.color, required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }
}

Color _slideColor(Loan loan) {
  if (loan.state == LoanState.closed) return const Color(0xFFE5E7EB);
  return switch (loan.type) {
    LoanType.consumer => const Color(0xFFD3E2FD),
    LoanType.car => const Color(0xFFD5EFE3),
    LoanType.mortgage => const Color(0xFFF6DCE4),
    LoanType.business => const Color(0xFFE4DDFB),
  };
}

class _LoanSlide extends StatelessWidget {
  final Loan loan;
  final bool hideAmounts;
  final VoidCallback onOpen;

  const _LoanSlide({
    required this.loan,
    required this.hideAmounts,
    required this.onOpen,
  });

  String _money(double v) => hideAmounts
      ? '$hiddenAmount ${loan.currency}'
      : formatMoney(v, loan.currency);

  Widget _bigAmount(double v) {
    const style = TextStyle(
      color: AppColors.ink,
      fontSize: 30,
      fontWeight: FontWeight.w800,
    );
    if (hideAmounts) return Text('$hiddenAmount ${loan.currency}', style: style);
    final s = formatAmount(v);
    final dot = s.lastIndexOf('.');
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: s.substring(0, dot)),
          TextSpan(
            text: '${s.substring(dot)} ${loan.currency}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, {Color color = AppColors.ink}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(170),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12.5, color: color, fontWeight: FontWeight.w500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final closed = loan.state == LoanState.closed;
    final overdue = loan.state == LoanState.overdue;
    final inst = loan.firstUnpaid;
    final next = loan.nextInstallment();

    return _CardSurface(
      color: _slideColor(loan),
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${context.tr(loan.productName)}  •  '
            '${context.tr(closed ? 'state.closed' : 'carousel.remaining')}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: AppColors.ink),
          ),
          const SizedBox(height: 4),
          _bigAmount(closed ? loan.amount : loan.outstandingPrincipal),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _chip(context.tr('carousel.amount', {'amount': _money(loan.amount)})),
              if (overdue)
                _chip(
                  context.tr('card.overdue_amount',
                      {'amount': _money(loan.overdueAmount())}),
                  color: AppColors.overdue,
                )
              else if (next != null)
                _chip(context.tr('carousel.next',
                    {'date': formatDate(next.dueDate)})),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 46),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    backgroundColor:
                        overdue ? AppColors.overdue : AppColors.primary,
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: closed || inst == null
                      ? null
                      : () => payNextInstallment(context, loan),
                  icon: Icon(
                    closed ? Icons.verified_outlined : Icons.event_repeat,
                    size: 18,
                  ),
                  label: Text(
                    closed || inst == null
                        ? context.tr('card.fully_repaid')
                        : context.tr(
                            overdue
                                ? 'carousel.pay_overdue'
                                : 'carousel.pay_monthly',
                            {'amount': _money(inst.total)},
                          ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 46,
                height: 46,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(46, 46),
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: onOpen,
                  child: const Icon(Icons.arrow_forward),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NewLoanSlide extends StatelessWidget {
  final VoidCallback onOrder;
  const _NewLoanSlide({required this.onOrder});

  @override
  Widget build(BuildContext context) {
    return _CardSurface(
      color: Colors.white,
      onTap: onOrder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.add_card, color: AppColors.primary),
          ),
          const SizedBox(height: 14),
          Text(
            context.tr('carousel.new_title'),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.tr('carousel.new_body'),
            style: const TextStyle(fontSize: 14, color: AppColors.muted),
          ),
          const Spacer(),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(140, 46),
              backgroundColor: AppColors.ink,
            ),
            onPressed: onOrder,
            child: Text(context.tr('carousel.new_button')),
          ),
        ],
      ),
    );
  }
}
