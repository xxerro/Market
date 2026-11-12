import '../../core/money.dart';
import '../../data/db/app_database.dart';

String _date(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _cur(String c) => currencyNames[c] ?? c;

/// نص كشف الحساب (آخر 10 حركات غير ملغاة + الرصيد).
String buildStatement({
  required String name,
  required Map<String, int> totals,
  required List<LedgerEntry> entriesNewestFirst,
}) {
  final b = StringBuffer();
  b.writeln('كشف حساب: $name');
  b.writeln('التاريخ: ${_date(DateTime.now())}');
  b.writeln();
  final recent =
      entriesNewestFirst.where((e) => e.voidedAt == null).take(10).toList();
  if (recent.isEmpty) {
    b.writeln('لا توجد حركات.');
  } else {
    b.writeln('آخر الحركات:');
    for (final e in recent) {
      final kind = e.type == 'debt' ? 'دين' : 'دفعة';
      b.write(
          '• ${_date(e.createdAt)}  $kind ${fmtMinor(e.amountMinor)} ${_cur(e.currency)}');
      if (e.type == 'debt' && e.note != null) b.write(' (${e.note})');
      b.writeln();
    }
  }
  b.writeln();
  if (totals.isEmpty) {
    b.writeln('الرصيد: 0.00');
  } else {
    for (final t in totals.entries) {
      if (t.value > 0) {
        b.writeln('الرصيد المستحق: ${fmtMinor(t.value)} ${_cur(t.key)}');
      } else if (t.value < 0) {
        b.writeln('رصيد لصالحك: ${fmtMinor(-t.value)} ${_cur(t.key)}');
      } else {
        b.writeln('الرصيد: 0.00 ${_cur(t.key)}');
      }
    }
  }
  return b.toString().trim();
}

/// رسالة تذكير بالدفع. ترجع null إذا ما في مبلغ مستحق.
String? buildReminder(String name, Map<String, int> totals) {
  final due = totals.entries.where((t) => t.value > 0).toList();
  if (due.isEmpty) return null;
  final amounts =
      due.map((t) => '${fmtMinor(t.value)} ${_cur(t.key)}').join(' و ');
  return 'مرحبًا $name، تذكير ودي بأن عليك مبلغ $amounts. '
      'نرجو التسديد في أقرب فرصة، وشكرًا لك.';
}
