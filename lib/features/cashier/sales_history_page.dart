import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/money.dart';
import '../../data/db/app_database.dart';
import 'receipt_text.dart';

class SalesHistoryPage extends StatelessWidget {
  const SalesHistoryPage({super.key});

  String _time(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final db = Get.find<AppDatabase>();
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    return Scaffold(
      appBar: AppBar(title: const Text('كشف المبيعات اليوم')),
      body: StreamBuilder<List<Sale>>(
        stream: db.watchSalesSince(startOfDay),
        builder: (context, snap) {
          final list = snap.data ?? const <Sale>[];
          if (list.isEmpty) {
            return const Center(child: Text('ما في مبيعات نقدية اليوم.'));
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final s = list[i];
              final voided = s.voidedAt != null;
              final cur = currencyNames[s.currency] ?? s.currency;
              return FutureBuilder<String>(
                future: db.salePaymentMethod(s.id),
                builder: (context, methodSnapshot) {
                  final method = methodSnapshot.data ?? 'cash';
                  return ListTile(
                    onTap: () => _details(db, s),
                    leading: Icon(
                      Icons.receipt,
                      color: voided ? Colors.grey : Colors.green.shade700,
                    ),
                    title: Text(
                      '${fmtMinor(s.totalMinor)} $cur',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        decoration: voided ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    subtitle: Text(
                      '${paymentMethodLabel(method)} • ${_time(s.createdAt)}'
                      '${voided ? ' • ملغاة' : ''}'
                      '${s.discountMinor > 0 ? ' • خصم ${fmtMinor(s.discountMinor)}' : ''}',
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _details(AppDatabase db, Sale s) async {
    final lines = await db.saleLines(s.id);
    final paymentMethod = await db.salePaymentMethod(s.id);
    final receipt = buildReceipt(
      lines: lines
          .map((l) => ReceiptLine(l.name, l.quantity, l.unitPriceMinor))
          .toList(),
      discountMinor: s.discountMinor,
      totalMinor: s.totalMinor,
      currency: s.currency,
      when: s.createdAt,
      paymentMethod: paymentMethod,
    );
    final voided = s.voidedAt != null;
    Get.defaultDialog(
      title: voided ? 'فاتورة ملغاة' : 'تفاصيل الفاتورة',
      content: Column(
        children: [
          Text(receipt, style: const TextStyle(fontSize: 13)),
          TextButton.icon(
            onPressed: () =>
                SharePlus.instance.share(ShareParams(text: receipt)),
            icon: const Icon(Icons.share),
            label: const Text('مشاركة'),
          ),
        ],
      ),
      textConfirm: voided ? null : 'إلغاء الفاتورة',
      textCancel: 'إغلاق',
      onConfirm: voided
          ? null
          : () async {
              await db.voidSale(s.id);
              Get.back();
              Get.snackbar('تم', 'أُلغيت الفاتورة وأُرجعت الكميات للمخزون');
            },
    );
  }
}
