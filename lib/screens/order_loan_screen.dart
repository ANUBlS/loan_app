import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../data/loan_repository.dart';
import '../data/mock_data.dart';
import '../models/loan.dart';
import '../i18n/l10n.dart';
import '../services/identity.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../utils/loan_math.dart';
import '../widgets/loan_widgets.dart';

class OrderLoanScreen extends StatefulWidget {
  final VoidCallback? onSubmitted;
  const OrderLoanScreen({super.key, this.onSubmitted});

  @override
  State<OrderLoanScreen> createState() => _OrderLoanScreenState();
}

class _OrderLoanScreenState extends State<OrderLoanScreen> {
  final _incomeCtrl = TextEditingController();

  final _repo = LoanRepository.instance;
  late LoanProduct _product;
  late double _amount;
  late int _term;
  late String _purpose;
  bool _agreed = false;
  bool _busy = false;

  L10n get _l => L10n.instance;

  @override
  void initState() {
    super.initState();
    _purpose = _repo.purposes.first;
    _applyProduct(_repo.products.first, initial: true);
    if (!_repo.catalogLoaded) _loadCatalog();
  }

  /// Products, rates and limits come from GET /catalog.
  Future<void> _loadCatalog() async {
    try {
      await _repo.loadCatalog();
    } on ApiException catch (e) {
      if (mounted) _snack(e.userMessage);
      return;
    } catch (_) {
      return;
    }
    if (!mounted) return;
    setState(() {
      final same = _repo.products.where((p) => p.name == _product.name);
      _product = same.isEmpty ? _repo.products.first : same.first;
      _amount = ((_amount / _product.step).round() * _product.step)
          .clamp(_product.minAmount, _product.maxAmount)
          .toDouble();
      _term = _term.clamp(_product.minTerm, _product.maxTerm).toInt();
      if (!_repo.purposes.contains(_purpose)) _purpose = _repo.purposes.first;
    });
  }

  @override
  void dispose() {
    _incomeCtrl.dispose();
    super.dispose();
  }

  void _applyProduct(LoanProduct p, {bool initial = false}) {
    _product = p;
    final start = p.minAmount + (p.maxAmount - p.minAmount) / 4;
    _amount = ((start / p.step).round() * p.step)
        .clamp(p.minAmount, p.maxAmount)
        .toDouble();
    _term = (initial ? 24 : _term).clamp(p.minTerm, p.maxTerm).toInt();
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final income = double.tryParse(
      _incomeCtrl.text.replaceAll(' ', '').replaceAll(',', '.'),
    );
    final monthly = annuityPayment(_amount, _product.annualRate, _term);

    if (income == null || income <= 0) {
      _snack(_l.t('order.err_income'));
      return;
    }
    if (monthly > income * 0.5) {
      _snack(_l.t('order.err_ratio'));
      return;
    }

    if (_product.id == 0) {
      // Catalog not loaded yet: the server needs real product ids.
      await _loadCatalog();
      if (!mounted || _product.id == 0) return;
    }

    setState(() => _busy = true);
    final ok = await confirmIdentity(context, _l.t('auth.reason_apply'));
    if (!mounted) return;
    if (!ok) {
      setState(() => _busy = false);
      return;
    }

    LoanApplication? app;
    try {
      app = await _repo.submitApplication(
        product: _product,
        amount: _amount,
        termMonths: _term,
        purpose: _purpose,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _snack(e.userMessage);
      return;
    }
    if (!mounted || app == null) return;
    setState(() => _busy = false);
    final sent = app;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: AppColors.paid, size: 48),
        title: Text(ctx.tr('order.sent_title')),
        content: Text(
          ctx.tr('order.sent_body', {
            'product': ctx.tr(sent.productName),
            'amount': formatMoney(sent.amount, sent.currency),
            'term': formatTerm(sent.termMonths),
            'monthly': formatMoney(sent.monthlyPayment, sent.currency),
            'id': sent.reference.isEmpty ? sent.id : sent.reference,
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.tr('common.done')),
          ),
        ],
      ),
    );
    if (!mounted) return;

    setState(() {
      _agreed = false;
      _incomeCtrl.clear();
      _applyProduct(_product);
    });
    widget.onSubmitted?.call();
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = _product;
    final monthly = annuityPayment(_amount, p.annualRate, _term);
    final total = monthly * _term;

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('order.title'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _Label(context.tr('order.type')),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final product in _repo.products)
                ChoiceChip(
                  showCheckmark: false,
                  avatar: Icon(loanTypeIcon(product.type), size: 18),
                  label: Text(context.tr(product.name)),
                  selected: product.name == p.name,
                  onSelected: (_) => setState(() => _applyProduct(product)),
                ),
            ],
          ),
          const SizedBox(height: 20),
          _SliderField(
            label: context.tr('order.amount'),
            valueText: formatMoney(_amount),
            minText: formatMoney(p.minAmount),
            maxText: formatMoney(p.maxAmount),
            slider: Slider(
              value: _amount,
              min: p.minAmount,
              max: p.maxAmount,
              divisions: p.amountDivisions,
              onChanged: (v) => setState(
                () => _amount = (v / p.step).round() * p.step,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _SliderField(
            label: context.tr('order.term'),
            valueText: formatTerm(_term),
            minText: context.tr('term.short', {'n': p.minTerm}),
            maxText: context.tr('term.short', {'n': p.maxTerm}),
            slider: Slider(
              value: _term.toDouble(),
              min: p.minTerm.toDouble(),
              max: p.maxTerm.toDouble(),
              divisions: p.maxTerm - p.minTerm,
              onChanged: (v) => setState(() => _term = v.round()),
            ),
          ),
          const SizedBox(height: 20),
          _Label(context.tr('order.purpose')),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final purpose in _repo.purposes)
                ChoiceChip(
                  showCheckmark: false,
                  label: Text(context.tr(purpose)),
                  selected: purpose == _purpose,
                  onSelected: (_) => setState(() => _purpose = purpose),
                ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _incomeCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: context.tr('order.income'),
              suffixText: _repo.currency,
              prefixIcon: const Icon(Icons.payments_outlined),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('order.monthly'),
                  style: const TextStyle(color: AppColors.primary),
                ),
                const SizedBox(height: 4),
                Text(
                  formatMoney(monthly),
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                _calcRow(
                  context.tr('order.rate'),
                  context.tr('schedule.rate_value',
                      {'rate': p.annualRate.toStringAsFixed(1)}),
                ),
                _calcRow(context.tr('order.total'), formatMoney(total)),
                _calcRow(
                  context.tr('order.total_interest'),
                  formatMoney(total - _amount),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: _agreed,
            onChanged: (v) => setState(() => _agreed = v ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              context.tr('order.agree'),
              style: const TextStyle(fontSize: 14),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _agreed && !_busy ? _submit : null,
            icon: const Icon(Icons.lock_outline),
            label: Text(context.tr(_busy ? 'order.waiting' : 'order.submit')),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('order.biometric_note'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _calcRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: AppColors.ink)),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
      ),
    );
  }
}

class _SliderField extends StatelessWidget {
  final String label;
  final String valueText;
  final String minText;
  final String maxText;
  final Widget slider;

  const _SliderField({
    required this.label,
    required this.valueText,
    required this.minText,
    required this.maxText,
    required this.slider,
  });

  @override
  Widget build(BuildContext context) {
    const small = TextStyle(fontSize: 12, color: AppColors.muted);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(label, style: const TextStyle(color: AppColors.muted)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  valueText,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
          slider,
          Row(
            children: [
              Text(minText, style: small),
              const Spacer(),
              Text(maxText, style: small),
            ],
          ),
        ],
      ),
    );
  }
}
