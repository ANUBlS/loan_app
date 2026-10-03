import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../data/loan_repository.dart';
import '../i18n/l10n.dart';
import '../theme.dart';

/// Dialog to set the Loan API address, with a connection check.
Future<void> showServerDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _ServerDialog(),
  );
}

class _ServerDialog extends StatefulWidget {
  const _ServerDialog();

  @override
  State<_ServerDialog> createState() => _ServerDialogState();
}

class _ServerDialogState extends State<_ServerDialog> {
  final _ctrl = TextEditingController(text: ApiClient.instance.baseUrl);
  bool _checking = false;
  String? _result;
  bool _ok = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _result = null;
    });
    var text = '';
    var ok = false;
    try {
      final version = await ApiClient.instance.ping(_ctrl.text);
      text = '${L10n.instance.t('server.ok')} ${version.isEmpty ? '' : '(v$version)'}';
      ok = true;
    } on ApiException catch (e) {
      text = e.userMessage;
      ok = false;
    }
    if (!mounted) return;
    setState(() {
      _checking = false;
      _result = text.trim();
      _ok = ok;
    });
  }

  Future<void> _save() async {
    final url = ApiClient.normalizeUrl(_ctrl.text);
    if (url.isEmpty) return;
    final changed = url != ApiClient.instance.baseUrl;
    await ApiClient.instance.setBaseUrl(url);
    if (!mounted) return;
    Navigator.pop(context);
    if (changed && await ApiClient.instance.hasSession()) {
      LoanRepository.instance.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr('server.title')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr('server.hint'),
            style: const TextStyle(fontSize: 13, color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: context.tr('server.address'),
              prefixIcon: const Icon(Icons.dns_outlined),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _checking ? null : _check,
              icon: _checking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.wifi_tethering),
              label: Text(context.tr('server.check')),
            ),
          ),
          if (_result != null)
            Text(
              _result!,
              style: TextStyle(
                fontSize: 13,
                color: _ok ? AppColors.paid : AppColors.overdue,
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.tr('common.cancel')),
        ),
        TextButton(
          onPressed: _save,
          child: Text(context.tr('server.save')),
        ),
      ],
    );
  }
}
