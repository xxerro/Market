import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/money.dart';
import '../../data/db/app_database.dart';
import 'basket_controller.dart';

const _currencyNames = {'ILS': 'شيكل', 'JOD': 'دينار', 'USD': 'دولار'};

class BasketPage extends StatelessWidget {
  const BasketPage({super.key, required this.customerId});
  final int customerId;

  @override
  Widget build(BuildContext context) {
    final c = Get.put(BasketController(customerId), tag: 'basket_$customerId');
    return Scaffold(
      appBar: AppBar(title: const Text('دين بالمسح')),
      body: Obx(() {
        c.items.length; // لتتبع الإضافة والحذف
        if (c.items.isEmpty) {
          return const Center(
              child: Text('امسح منتجًا أو اخترْه من القائمة لإضافته.'));
        }
        return ListView.separated(
          itemCount: c.items.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (_, i) => _line(c, c.items[i]),
        );
      }),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Obx(() {
                c.items.length;
                return Row(
                  children: [
                    Text('الإجمالي: ${fmtMinor(c.totalMinor)}',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    DropdownButton<String>(
                      value: c.currency.value,
                      items: _currencyNames.entries
                          .map((e) => DropdownMenuItem(
                              value: e.key, child: Text(e.value)))
                          .toList(),
                      onChanged: (v) => c.currency.value = v ?? 'ILS',
                    ),
                  ],
                );
              }),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () async {
                        final err = await c.scanAdd();
                        if (err != null) Get.snackbar('تنبيه', err);
                      },
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('مسح'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () => _pick(c),
                      icon: const Icon(Icons.list),
                      label: const Text('من القائمة'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: Colors.red.shade700),
                  onPressed: () async {
                    final err = await c.confirm('');
                    if (err == null) {
                      Get.back();
                    } else {
                      Get.snackbar('تنبيه', err);
                    }
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('تسجيل الدين'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(BasketController c, BasketItem it) {
    return Obx(() {
      final q = it.qty.value;
      final short = q > it.product.quantity;
      return ListTile(
        title: Text(it.product.name),
        subtitle: Text(
          '${fmtMinor(it.product.sellPriceMinor)} × ${fmtQty(q)} = ${fmtMinor(it.lineMinor)}'
          '${short ? '\nالمتوفر ${fmtQty(it.product.quantity)} فقط' : ''}',
          style: TextStyle(color: short ? Colors.red.shade700 : null),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () => c.dec(it)),
            GestureDetector(
              onTap: () => _qtyDialog(it),
              child: Text(fmtQty(q),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => c.inc(it)),
          ],
        ),
      );
    });
  }

  void _qtyDialog(BasketItem it) {
    final t = TextEditingController(text: fmtQty(it.qty.value));
    Get.defaultDialog(
      title: it.product.name,
      content: TextField(
        controller: t,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'الكمية'),
      ),
      textConfirm: 'حفظ',
      textCancel: 'إلغاء',
      onConfirm: () {
        final q = parseQty(t.text);
        if (q == null || q <= 0) {
          Get.snackbar('خطأ', 'أدخل كمية أكبر من صفر');
          return;
        }
        it.qty.value = q;
        Get.back();
      },
    );
  }

  Future<void> _pick(BasketController c) async {
    final list = await Get.find<AppDatabase>().watchProducts().first;
    Get.bottomSheet(
      Container(
        color: Get.theme.colorScheme.surface,
        child: ListView(
          children: list
              .map((p) => ListTile(
                    title: Text(p.name),
                    subtitle: Text(
                        '${fmtMinor(p.sellPriceMinor)}  •  المتوفر ${fmtQty(p.quantity)}'),
                    onTap: () {
                      c.addProduct(p);
                      Get.back();
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }
}
