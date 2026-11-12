import '../../core/money.dart';

const paymentMethodLabels = {
  'cash': 'نقدًا',
  'jawwal_pay': 'جوال باي',
  'palpay': 'بال باي',
  'bank_of_palestine': 'بنك فلسطين',
};

String paymentMethodLabel(String method) =>
    paymentMethodLabels[method] ?? method;

class ReceiptLine {
  final String name;
  final double quantity;
  final int unitPriceMinor;
  const ReceiptLine(this.name, this.quantity, this.unitPriceMinor);
  int get lineMinor => (quantity * unitPriceMinor).round();
}

String _date(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String buildReceipt({
  required List<ReceiptLine> lines,
  required int discountMinor,
  required int totalMinor,
  required String currency,
  required DateTime when,
  String? customerName, // إذا كان بيعًا على الحساب
  String? paymentMethod,
}) {
  final cur = currencyNames[currency] ?? currency;
  final b = StringBuffer();
  b.writeln('فاتورة');
  b.writeln(_date(when));
  if (customerName != null) {
    b.writeln('الزبون: $customerName (على الحساب)');
  } else if (paymentMethod != null) {
    b.writeln('طريقة الدفع: ${paymentMethodLabel(paymentMethod)}');
  }
  b.writeln();
  for (final l in lines) {
    b.writeln(
      '• ${l.name}  ${fmtQty(l.quantity)} × ${fmtMinor(l.unitPriceMinor)} = ${fmtMinor(l.lineMinor)}',
    );
  }
  b.writeln();
  if (discountMinor > 0) b.writeln('الخصم: ${fmtMinor(discountMinor)} $cur');
  b.writeln('الإجمالي: ${fmtMinor(totalMinor)} $cur');
  return b.toString().trim();
}
