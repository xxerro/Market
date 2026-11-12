import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/money.dart';
import '../../data/db/app_database.dart';

import 'package:qr_flutter/qr_flutter.dart';

import 'product_detail_controller.dart';
import 'product_form_page.dart';

const _reasonNames = {
  'initial': 'رصيد افتتاحي',
  'receive': 'استلام بضاعة',
  'damage': 'تالف',
  'correction': 'تصحيح جرد',
  'sale': 'بيع',
  'void_return': 'إلغاء قيد دين',
};

String _date(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class ProductDetailPage extends StatelessWidget {
  const ProductDetailPage({super.key, required this.productId});
  final int productId;

  @override
  Widget build(BuildContext context) {
    final c = Get.put(
      ProductDetailController(productId),
      tag: 'product_$productId',
    );
    return Obx(() {
      final p = c.product.value;
      if (p == null) {
        return Scaffold(
          appBar: AppBar(),
          body: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inventory_2_outlined, size: 48),
                SizedBox(height: 12),
                Text('تعذر العثور على المنتج أو تم نقله للأرشيف.'),
              ],
            ),
          ),
        );
      }
      final low = p.minQuantity > 0 && p.quantity <= p.minQuantity;
      return Scaffold(
        appBar: AppBar(
          title: Text(p.name),
          actions: [
            IconButton(
              tooltip: 'عرض QR',
              icon: const Icon(Icons.qr_code),
              onPressed: () => Get.defaultDialog(
                title: p.name,
                content: Column(
                  children: [
                    QrImageView(
                      data: 'shop:p:${p.id}',
                      size: 220,
                      backgroundColor: Colors.white,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'ألصق هذا الرمز على الرف أو العبوة',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: 'أرشفة المنتج',
              icon: const Icon(Icons.archive_outlined),
              onPressed: () => Get.defaultDialog(
                title: 'أرشفة المنتج؟',
                middleText: p.quantity != 0
                    ? 'الكمية المتبقية ${fmtQty(p.quantity)}. سيختفي المنتج من القوائم والمسح والكاشير.'
                    : 'سيختفي المنتج من القوائم والمسح والكاشير.',
                textConfirm: 'أرشفة',
                textCancel: 'إلغاء',
                onConfirm: () async {
                  await Get.find<AppDatabase>().archiveProduct(p.id);
                  Get.back();
                  Get.back();
                },
              ),
            ),
            IconButton(
              tooltip: 'تعديل بيانات المنتج',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => Get.to(() => ProductFormPage(product: p)),
            ),
          ],
        ),
        body: Column(
          children: [
            Card(
              margin: const EdgeInsets.all(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('الكمية المتوفرة'),
                    Text(
                      fmtQty(p.quantity),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: low ? Colors.red.shade700 : null,
                      ),
                    ),
                    if (low)
                      Text(
                        'قارب على النفاد (الحد الأدنى ${fmtQty(p.minQuantity)})',
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      'سعر الشراء: ${fmtMinor(p.buyPriceMinor)}   |   سعر البيع: ${fmtMinor(p.sellPriceMinor)}',
                    ),
                    if (p.barcode != null) Text('الباركود: ${p.barcode}'),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                      ),
                      onPressed: () => _dialog(c, true),
                      icon: const Icon(Icons.add),
                      label: const Text('إضافة كمية'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                      ),
                      onPressed: () => _dialog(c, false),
                      icon: const Icon(Icons.remove),
                      label: const Text('نقص كمية'),
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(12),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  'سجل الحركات',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Obx(() {
                if (c.movements.isEmpty) {
                  return const Center(child: Text('ما في حركات بعد.'));
                }
                return ListView.separated(
                  itemCount: c.movements.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final m = c.movements[i];
                    final inn = m.delta > 0;
                    return ListTile(
                      leading: Icon(
                        inn ? Icons.arrow_downward : Icons.arrow_upward,
                        color: inn
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                      ),
                      title: Text(
                        '${inn ? '+' : ''}${fmtQty(m.delta)}  ${_reasonNames[m.reason] ?? m.reason}',
                      ),
                      subtitle: Text(
                        [
                          _date(m.createdAt),
                          if (m.note != null) m.note!,
                        ].join(' • '),
                      ),
                    );
                  },
                );
              }),
            ),
          ],
        ),
      );
    });
  }

  void _dialog(ProductDetailController c, bool add) {
    final amount = TextEditingController();
    final note = TextEditingController();
    final reason = (add ? 'receive' : 'damage').obs;
    Get.defaultDialog(
      title: add ? 'إضافة كمية' : 'نقص كمية',
      content: Column(
        children: [
          TextField(
            controller: amount,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'الكمية'),
          ),
          if (!add)
            Obx(
              () => DropdownButton<String>(
                value: reason.value,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'damage', child: Text('تالف')),
                  DropdownMenuItem(
                    value: 'correction',
                    child: Text('تصحيح جرد'),
                  ),
                ],
                onChanged: (v) => reason.value = v ?? 'damage',
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
        final q = parseQty(amount.text);
        if (q == null || q <= 0) {
          Get.snackbar('خطأ', 'أدخل كمية صحيحة أكبر من صفر');
          return;
        }
        final err = await c.adjust(add ? q : -q, reason.value, note.text);
        if (err == null) {
          Get.back();
        } else {
          Get.snackbar('خطأ', err);
        }
      },
    );
  }
}
