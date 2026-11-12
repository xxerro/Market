import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/money.dart';
import '../../data/db/app_database.dart';
import '../ledger/customer_detail_page.dart';
import 'reports_controller.dart';

String _amounts(List<CurrencyTotal> list) {
  if (list.isEmpty) return '0.00';
  return list
      .map(
        (t) =>
            '${fmtMinor(t.minor)} ${currencyNames[t.currency] ?? t.currency}',
      )
      .join('  |  ');
}

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(ReportsController());
    return Scaffold(
      appBar: AppBar(title: const Text('التقارير')),
      body: Obx(() {
        // قراءة القوائم لتتبع التغييرات
        c.totalDebts.length;
        c.paidToday.length;
        c.paidWeek.length;
        c.paidMonth.length;
        c.debtors.length;
        c.lowStock.length;
        c.cashSales.length;
        c.creditSales.length;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _card('إجمالي الديون المستحقة', [
              if (c.totalDebts.isEmpty)
                const Text('لا ديون مستحقة.')
              else
                for (final t in c.totalDebts)
                  Text(
                    '${fmtMinor(t.minor)} ${currencyNames[t.currency] ?? t.currency}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                  ),
            ]),
            _card('مبيعات اليوم', [
              Text('نقدًا: ${_amounts(c.cashSales.toList())}'),
              Text('على الحساب: ${_amounts(c.creditSales.toList())}'),
            ]),
            _card('المقبوضات', [
              Text('اليوم: ${_amounts(c.paidToday.toList())}'),
              Text('آخر 7 أيام: ${_amounts(c.paidWeek.toList())}'),
              Text('هذا الشهر: ${_amounts(c.paidMonth.toList())}'),
            ]),
            _card('أكبر الديون', [
              if (c.debtors.isEmpty) const Text('لا ديون مستحقة.'),
              for (final d in c.debtors.toList())
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: () => Get.to(
                    () => CustomerDetailPage(
                      customerId: d.customerId,
                      name: d.name,
                    ),
                  ),
                  title: Text(d.name),
                  subtitle: Text(
                    d.lastPayment == null
                        ? 'ما في دفعات بعد'
                        : 'آخر دفعة قبل ${DateTime.now().difference(d.lastPayment!).inDays} يوم',
                  ),
                  trailing: Text(
                    '${fmtMinor(d.balanceMinor)} ${currencyNames[d.currency] ?? d.currency}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                  ),
                ),
            ]),
            _card('بضاعة قاربت على النفاد', [
              if (c.lowStock.isEmpty)
                const Text('كل المنتجات فوق الحد الأدنى.'),
              for (final p in c.lowStock.toList())
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(p.name),
                  trailing: Text(
                    '${fmtQty(p.quantity)} / ${fmtQty(p.minQuantity)}',
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                ),
            ]),
          ],
        );
      }),
    );
  }

  Widget _card(String title, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(Get.context!).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}
