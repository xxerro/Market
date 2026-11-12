/// يحوّل رقم محلي إلى صيغة دولية بدون + لاستخدامه في رابط واتساب.
/// الافتراض: الأرقام الفلسطينية (059 / 056 / الخطوط الأرضية) -> 970،
/// وبقية أرقام 05x (إسرائيلية) -> 972. عدّل هذه الدالة إذا لزم.
String? normalizePhone(String? raw) {
  if (raw == null) return null;
  final d = raw.replaceAll(RegExp(r'[^0-9+]'), '');
  if (d.isEmpty) return null;
  if (d.startsWith('+')) return d.substring(1);
  if (d.startsWith('00')) return d.substring(2);
  if (d.startsWith('0')) {
    final isPalestinian = d.startsWith('059') ||
        d.startsWith('056') ||
        (d.length > 1 && d[1] != '5');
    return (isPalestinian ? '970' : '972') + d.substring(1);
  }
  return d; // نفترض أنه دولي أصلًا
}
