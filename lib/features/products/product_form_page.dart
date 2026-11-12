import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/money.dart';
import '../../data/db/app_database.dart';

/// إضافة منتج جديد، أو تعديل منتج موجود إذا مُرِّر [product].
class ProductFormPage extends StatefulWidget {
  const ProductFormPage({super.key, this.product, this.initialBarcode});
  final Product? product;
  final String? initialBarcode;

  @override
  State<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends State<ProductFormPage> {
  late final TextEditingController name;
  late final TextEditingController barcode;
  late final TextEditingController buy;
  late final TextEditingController sell;
  late final TextEditingController qty;
  late final TextEditingController minQty;

  bool get _editing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    name = TextEditingController(text: p?.name ?? '');
    barcode = TextEditingController(
      text: p?.barcode ?? widget.initialBarcode ?? '',
    );
    buy = TextEditingController(
      text: p == null ? '' : fmtMinor(p.buyPriceMinor),
    );
    sell = TextEditingController(
      text: p == null ? '' : fmtMinor(p.sellPriceMinor),
    );
    qty = TextEditingController();
    minQty = TextEditingController(
      text: p == null || p.minQuantity == 0 ? '' : fmtQty(p.minQuantity),
    );
  }

  @override
  void dispose() {
    for (final c in [name, barcode, buy, sell, qty, minQty]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final n = name.text.trim();
    if (n.isEmpty) {
      Get.snackbar('خطأ', 'اكتب اسم المنتج');
      return;
    }
    final buyM = buy.text.trim().isEmpty ? 0 : parseMinor(buy.text);
    final sellM = sell.text.trim().isEmpty ? 0 : parseMinor(sell.text);
    final q = qty.text.trim().isEmpty ? 0.0 : parseQty(qty.text);
    final mq = minQty.text.trim().isEmpty ? 0.0 : parseQty(minQty.text);
    if (buyM == null ||
        sellM == null ||
        q == null ||
        mq == null ||
        q < 0 ||
        mq < 0) {
      Get.snackbar('خطأ', 'تأكد من الأرقام المدخلة');
      return;
    }
    final bc = barcode.text.trim().isEmpty ? null : barcode.text.trim();
    final db = Get.find<AppDatabase>();
    try {
      final productId = _editing
          ? widget.product!.id
          : await db.addProduct(
              name: n,
              barcode: bc,
              buyMinor: buyM,
              sellMinor: sellM,
              quantity: q,
              minQuantity: mq,
            );
      if (_editing) {
        await db.updateProduct(
          productId,
          name: n,
          barcode: bc,
          buyMinor: buyM,
          sellMinor: sellM,
          minQuantity: mq,
        );
      }
      Get.back<int>(result: productId);
    } catch (_) {
      Get.snackbar('خطأ', 'تعذر الحفظ. قد يكون الباركود مستخدمًا لمنتج آخر.');
    }
  }

  Widget _field(
    TextEditingController c,
    String label, {
    bool number = false,
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        enabled: enabled,
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'تعديل منتج' : 'منتج جديد')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _field(name, 'اسم المنتج'),
          _field(barcode, 'الباركود (اختياري)'),
          _field(buy, 'سعر الشراء', number: true),
          _field(sell, 'سعر البيع', number: true),
          if (!_editing)
            _field(qty, 'الكمية الحالية', number: true)
          else ...[
            Card(
              child: ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('تعديل المخزون'),
                subtitle: const Text(
                  'غيّر الكمية من سجل الحركات في صفحة المنتج للحفاظ على سجل الجرد.',
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          _field(minQty, 'الحد الأدنى للتنبيه', number: true),
          const SizedBox(height: 8),
          FilledButton(onPressed: _save, child: const Text('حفظ')),
        ],
      ),
    );
  }
}
