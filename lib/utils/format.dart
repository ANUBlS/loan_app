/// 12345.6 -> "12 345.60"
String formatAmount(double value) {
  final fixed = value.abs().toStringAsFixed(2);
  final parts = fixed.split('.');
  final intPart = parts[0];
  final buf = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(' ');
    buf.write(intPart[i]);
  }
  return '${value < 0 ? '-' : ''}$buf.${parts[1]}';
}

String formatMoney(double value, [String currency = 'AZN']) =>
    '${formatAmount(value)} $currency';

String formatDate(DateTime d) => '${_two(d.day)}.${_two(d.month)}.${d.year}';

String formatTerm(int months) {
  if (months >= 12 && months % 12 == 0) {
    final years = months ~/ 12;
    return '$months months ($years ${years == 1 ? 'year' : 'years'})';
  }
  return '$months months';
}

String _two(int n) => n.toString().padLeft(2, '0');
