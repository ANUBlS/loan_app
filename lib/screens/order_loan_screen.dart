import 'package:flutter/material.dart';

import '../data/loan_repository.dart';
import '../data/mock_data.dart';
import '../services/auth_service.dart';
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
  final _auth = AuthService();
  final _incomeCtrl = TextEditingController();

  late LoanProduct _product;
  late double _amount;
  late int _term;
  String _purpose = MockData.purposes.first;
  bool _agreed = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _applyProduct(MockData.products.first, initial: true);
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
      _snack('Enter your monthly net income.');
      return;
    }
    if (monthly > income * 0.5) {
      _snack('The monthly payment is more than half of your income. '
          'Lower the amount or choose a longer term.');
      return;
    }

    setState(() => _busy = true);
    final result = await _auth.authenticate('Confirm your loan application');
    if (!mounted) return;
    setState(() => _busy = false);

    if (!result.success) {
      _snack(result.message ?? 'Confirmation failed.');
      return;
    }

    final app = LoanRepository.instance.submitApplication(
      product: _product,
      amount: _amount,
      termMonths: _term,
      purpose: _purpose,
    );

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: AppColors.paid, size: 48),
        title: const Text('Application sent'),
        content: Text(
          '${app.productName}: ${formatMoney(app.amount, app.currency)} '
          'for ${app.termMonths} months.\n'
          'Monthly payment: ${formatMoney(app.monthlyPayment, app.currency)}\n\n'
          'Application number: ${app.id}\n'
          'We will review it and notify you.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
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
  }

  @override
  Widget build(BuildContext context) {
    final p = _product;
    final monthly = annuityPayment(_amount, p.annualRate, _term);
    final total = monthly * _term;

    return Scaffold(
      appBar: AppBar(title: const Text('Order a loan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          const _Label('Loan type'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final product in MockData.products)
                ChoiceChip(
                  showCheckmark: false,
                  avatar: Icon(loanTypeIcon(product.type), size: 18),
                  label: Text(product.name),
                  selected: product == p,
                  onSelected: (_) => setState(() => _applyProduct(product)),
                ),
            ],
          ),
          const SizedBox(height: 20),
          _SliderField(
            label: 'Amount',
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
            label: 'Term',
            valueText: formatTerm(_term),
            minText: '${p.minTerm} mo',
            maxText: '${p.maxTerm} mo',
            slider: Slider(
              value: _term.toDouble(),
              min: p.minTerm.toDouble(),
              max: p.maxTerm.toDouble(),
              divisions: p.maxTerm - p.minTerm,
              onChanged: (v) => setState(() => _term = v.round()),
            ),
          ),
          const SizedBox(height: 20),
          const _Label('Purpose'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final purpose in MockData.purposes)
                ChoiceChip(
                  showCheckmark: false,
                  label: Text(purpose),
                  selected: purpose == _purpose,
                  onSelected: (_) => setState(() => _purpose = purpose),
                ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _incomeCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Monthly net income',
              suffixText: 'AZN',
              prefixIcon: Icon(Icons.payments_outlined),
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
                const Text(
                  'Monthly payment',
                  style: TextStyle(color: AppColors.primary),
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
                _calcRow('Interest rate',
                    '${p.annualRate.toStringAsFixed(1)}% per year'),
                _calcRow('Total repayment', formatMoney(total)),
                _calcRow('Total interest', formatMoney(total - _amount)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: _agreed,
            onChanged: (v) => setState(() => _agreed = v ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text(
              'I agree to a credit bureau check and to the loan terms.',
              style: TextStyle(fontSize: 14),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _agreed && !_busy ? _submit : null,
            icon: const Icon(Icons.fingerprint),
            label: Text(_busy ? 'Waiting for biometrics…' : 'Send application'),
          ),
          const SizedBox(height: 8),
          const Text(
            'You confirm the application with your fingerprint or face.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.muted),
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
          Text(label, style: const TextStyle(color: AppColors.ink)),
          const Spacer(),
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
              const Spacer(),
              Text(
                valueText,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
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
