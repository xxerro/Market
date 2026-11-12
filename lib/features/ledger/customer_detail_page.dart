import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'basket_page.dart';
import 'customer_detail_controller.dart';

const _currencyNames = {'ILS': 'شيكل', 'JOD': 'دينار', 'USD': 'دولار'};

String _money(int minor) => (minor / 100).toStringAsFixed(2);

String _date(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class CustomerDetailPage extends StatelessWidget {
  const CustomerDetailPage({
    super.key,
    required this.customerId,
    required this.name,
  });

  final int customerId;
  final String name;

  @override
  Widget build(BuildContext context) {
    final c = Get.put(
      CustomerDetailController(customerId),
      tag: 'customer_$customerId',
    );
    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text(c.customer.value?.name ?? name)),
        actions: [
          IconButton(
            tooltip: 'تعديل بيانات الزبون',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _editDialog(c),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'خيارات',
            onSelected: (v) {
              switch (v) {
                case 'archive':
                  _archive(c);
                  break;
                default:
                  _send(c, v == 'reminder');
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'statement',
                child: Text('إرسال كشف الحساب'),
              ),
              PopupMenuItem(
                value: 'reminder',
                child: Text('إرسال تذكير بالدفع'),
              ),
              PopupMenuDivider(),
              PopupMenuItem(value: 'archive', child: Text('أرشفة الزبون')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Obx(() => _TotalsCard(totals: Map.of(c.totals))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () =>
                    Get.to(() => BasketPage(customerId: customerId)),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('دين بالمسح (باركود / QR)'),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'اضغط مطولًا على قيد لإلغائه',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Obx(() {
              if (c.rows.isEmpty) {
                return const Center(child: Text('ما في قيود بعد.'));
              }
              return ListView.separated(
                itemCount: c.rows.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) => _EntryTile(row: c.rows[i], c: c),
              );
            }),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                  ),
                  onPressed: () => _entryDialog(c, 'debt'),
                  icon: const Icon(Icons.add),
                  label: const Text('دين جديد'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                  ),
                  onPressed: () => _entryDialog(c, 'payment'),
                  icon: const Icon(Icons.payments),
                  label: const Text('دفعة'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _editDialog(CustomerDetailController c) {
    final cu = c.customer.value;
    if (cu == null) return;
    final n = TextEditingController(text: cu.name);
    final ph = TextEditingController(text: cu.phone ?? '');
    final nt = TextEditingController(text: cu.note ?? '');
    Get.defaultDialog(
      title: 'تعديل الزبون',
      content: Column(
        children: [
          TextField(
            controller: n,
            decoration: const InputDecoration(labelText: 'الاسم'),
          ),
          TextField(
            controller: ph,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'الهاتف'),
          ),
          TextField(
            controller: nt,
            decoration: const InputDecoration(labelText: 'ملاحظة'),
          ),
        ],
      ),
      textConfirm: 'حفظ',
      textCancel: 'إلغاء',
      onConfirm: () async {
        if (n.text.trim().isEmpty) {
          Get.snackbar('خطأ', 'الاسم مطلوب');
          return;
        }
        await c.updateCustomer(n.text, ph.text, nt.text);
        Get.back();
      },
    );
  }

  void _archive(CustomerDetailController c) {
    Get.defaultDialog(
      title: 'أرشفة الزبون؟',
      middleText:
          'سيختفي من قائمة الزبائن. مسموح فقط إذا رصيده صفر في كل العملات.',
      textConfirm: 'أرشفة',
      textCancel: 'إلغاء',
      onConfirm: () async {
        final ok = await c.archive();
        Get.back();
        if (ok) {
          Get.back();
        } else {
          Get.snackbar(
            'تعذرت الأرشفة',
            'عليه رصيد غير صفر. سدّد أو صفّر الرصيد أولًا.',
          );
        }
      },
    );
  }

  Future<void> _send(CustomerDetailController c, bool reminder) async {
    final err = await c.sendWhatsApp(reminder: reminder);
    if (err != null) Get.snackbar('تنبيه', err);
  }

  void _entryDialog(CustomerDetailController c, String type) {
    final amount = TextEditingController();
    final note = TextEditingController();
    final currency = 'ILS'.obs;
    Get.defaultDialog(
      title: type == 'debt' ? 'دين جديد' : 'دفعة',
      content: Column(
        children: [
          TextField(
            controller: amount,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'المبلغ'),
          ),
          Obx(
            () => DropdownButton<String>(
              value: currency.value,
              isExpanded: true,
              items: _currencyNames.entries
                  .map(
                    (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                  )
                  .toList(),
              onChanged: (v) => currency.value = v ?? 'ILS',
            ),
          ),
          TextField(
            controller: note,
            decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)'),
          ),
        ],
      ),
      textConfirm: 'حفظ',
      textCancel: 'إلغاء',
      onConfirm: () async {
        final ok = await c.add(type, amount.text, currency.value, note.text);
        if (ok) {
          Get.back();
        } else {
          Get.snackbar('خطأ', 'أدخل مبلغًا صحيحًا أكبر من صفر');
        }
      },
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.totals});
  final Map<String, int> totals;

  @override
  Widget build(BuildContext context) {
    final entries = totals.entries.toList();
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('الرصيد الحالي'),
            const SizedBox(height: 8),
            if (entries.isEmpty)
              const Text('0.00', style: TextStyle(fontSize: 24)),
            for (final e in entries)
              Text(
                '${_money(e.value)} ${_currencyNames[e.key] ?? e.key}',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: e.value > 0
                      ? Colors.red.shade700
                      : Colors.green.shade700,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.row, required this.c});
  final StatementRow row;
  final CustomerDetailController c;

  @override
  Widget build(BuildContext context) {
    final e = row.entry;
    final isDebt = e.type == 'debt';
    final voided = e.voidedAt != null;
    final color = voided
        ? Colors.grey
        : (isDebt ? Colors.red.shade700 : Colors.green.shade700);
    final cur = _currencyNames[e.currency] ?? e.currency;
    return ListTile(
      onLongPress: voided ? null : () => _confirmVoid(e.id),
      leading: Icon(
        isDebt ? Icons.arrow_upward : Icons.arrow_downward,
        color: color,
      ),
      title: Text(
        '${isDebt ? 'دين' : 'دفعة'}: ${_money(e.amountMinor)} $cur',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          decoration: voided ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: Text(
        [
          _date(e.createdAt),
          if (e.note != null) e.note!,
          if (voided) 'ملغى',
        ].join(' • '),
      ),
      trailing: voided
          ? null
          : Text(
              '${_money(row.runningMinor)}\n$cur',
              textAlign: TextAlign.center,
            ),
    );
  }

  void _confirmVoid(int id) {
    Get.defaultDialog(
      title: 'إلغاء القيد؟',
      middleText: 'سيبقى القيد في السجل مشطوبًا ولن يدخل في الرصيد.',
      textConfirm: 'إلغاء القيد',
      textCancel: 'رجوع',
      onConfirm: () async {
        await c.void_(id);
        Get.back();
      },
    );
  }
}
