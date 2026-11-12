/// يحوّل نص المبلغ إلى وحدات صغرى (أغورة/سنت). يرجع null إذا غير صالح.
int? parseMinor(String s) {
  final v = double.tryParse(s.trim().replaceAll(',', '.'));
  if (v == null || v < 0) return null;
  return (v * 100).round();
}

String fmtMinor(int minor) => (minor / 100).toStringAsFixed(2);

double? parseQty(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

String fmtQty(double q) =>
    q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(2);

const currencyNames = {'ILS': 'شيكل', 'JOD': 'دينار', 'USD': 'دولار'};
