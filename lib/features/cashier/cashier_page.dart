import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/empty_state.dart';
import '../../core/money.dart';
import '../../data/db/app_database.dart';
import '../ledger/basket_controller.dart' show BasketItem;
import '../products/product_form_page.dart';
import 'cashier_controller.dart';
import '../scan/scan_page.dart';
import 'sales_history_page.dart';

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        foregroundColor: colors.primary,
        side: BorderSide(color: colors.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}

class _PaymentMethodButton extends StatelessWidget {
  const _PaymentMethodButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected ? colors.secondaryContainer : colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? colors.primary : colors.outlineVariant,
          width: selected ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Icon(icon, size: 19, color: colors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 4),
                Icon(Icons.check_circle, size: 17, color: colors.primary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class CashierPage extends StatelessWidget {
  const CashierPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(CashierController());
    return Scaffold(
      appBar: AppBar(
        title: const Text('الكاشير'),
        actions: [
          IconButton(
            tooltip: 'مبيعات اليوم',
            icon: const Icon(Icons.receipt_long),
            onPressed: () => Get.to(() => const SalesHistoryPage()),
          ),
        ],
      ),
      body: Obx(() {
        c.items.length;
        if (c.items.isEmpty) {
          return EmptyState(
            icon: Icons.point_of_sale,
            title: 'جاهز لتسجيل أول عملية بيع؟',
            message:
                'امسح باركود المنتجات أو اخترها من القائمة لبدء فاتورة جديدة.',
            actionLabel: 'اختيار المنتجات',
            onAction: () => _pick(c),
          );
        }
        return ListView.separated(
          itemCount: c.items.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) => _line(context, c, c.items[i]),
        );
      }),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Card(
            elevation: 2,
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Obx(() {
                    c.items.length;
                    final disc = c.effectiveDiscount;
                    return Column(
                      children: [
                        Row(
                          children: [
                            Text(
                              'الإجمالي: ${fmtMinor(c.totalMinor)}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            DropdownButton<String>(
                              value: c.currency.value,
                              items: currencyNames.entries
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e.key,
                                      child: Text(e.value),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) => c.currency.value = v ?? 'ILS',
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: () => _discountDialog(c),
                              icon: const Icon(Icons.percent, size: 18),
                              label: Text(
                                disc > 0
                                    ? 'خصم: ${fmtMinor(disc)}'
                                    : 'إضافة خصم',
                              ),
                            ),
                            if (disc > 0)
                              IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () => c.discountMinor.value = 0,
                              ),
                            const Spacer(),
                            if (c.items.isNotEmpty)
                              TextButton(
                                onPressed: c.clear,
                                child: const Text('مسح السلة'),
                              ),
                          ],
                        ),
                      ],
                    );
                  }),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionTile(
                          icon: Icons.qr_code_scanner,
                          label: 'مسح باركود',
                          onTap: () => _scanForSale(c),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ActionTile(
                          icon: Icons.inventory_2_outlined,
                          label: 'اختيار منتج',
                          onTap: () => _pick(c),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: 4,
                        bottom: 6,
                      ),
                      child: Text(
                        'وسيلة الدفع',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  Obx(
                    () => GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 6,
                      childAspectRatio: 3.15,
                      children:
                          const [
                            ('cash', 'نقدًا', Icons.payments_outlined),
                            ('jawwal_pay', 'جوال باي', Icons.phone_android),
                            (
                              'palpay',
                              'بال باي',
                              Icons.account_balance_wallet_outlined,
                            ),
                            (
                              'bank_of_palestine',
                              'بنك فلسطين',
                              Icons.account_balance,
                            ),
                          ].map((option) {
                            final (value, label, icon) = option;
                            return _PaymentMethodButton(
                              label: label,
                              icon: icon,
                              selected: c.paymentMethod.value == value,
                              enabled: !c.processing.value,
                              onTap: () => c.paymentMethod.value = value,
                            );
                          }).toList(),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Obx(
                          () => FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .primary,
                              minimumSize: const Size.fromHeight(52),
                            ),
                            onPressed: c.items.isEmpty || c.processing.value
                                ? null
                                : () => _payCash(c),
                            icon: c.processing.value
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.check_circle_outline),
                            label: const Text('تأكيد الدفع'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.red.shade700,
                            minimumSize: const Size.fromHeight(52),
                          ),
                          onPressed: c.items.isEmpty
                              ? null
                              : () => _payCredit(c),
                          icon: const Icon(Icons.menu_book),
                          label: const Text('على الحساب'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _line(BuildContext context, CashierController c, BasketItem it) {
    return Obx(() {
      final q = it.qty.value;
      final short = q > it.product.quantity;
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: ListTile(
          title: Text(it.product.name),
          subtitle: Text(
            '${fmtMinor(it.product.sellPriceMinor)} × ${fmtQty(q)} = ${fmtMinor(it.lineMinor)}'
            '${short ? '\nالمتوفر ${fmtQty(it.product.quantity)} فقط' : ''}',
            style: TextStyle(color: short ? Colors.red.shade700 : null),
          ),
          trailing: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'تقليل الكمية',
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints.tightFor(
                    width: 40,
                    height: 40,
                  ),
                  icon: const Icon(Icons.remove, size: 19),
                  onPressed: () => c.dec(it),
                ),
                InkWell(
                  onTap: () => _qtyDialog(it),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      fmtQty(q),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'زيادة الكمية',
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints.tightFor(
                    width: 40,
                    height: 40,
                  ),
                  icon: const Icon(Icons.add, size: 19),
                  onPressed: () => c.inc(it),
                ),
              ],
            ),
          ),
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

  void _discountDialog(CashierController c) {
    final t = TextEditingController();
    Get.defaultDialog(
      title: 'خصم على الفاتورة',
      content: TextField(
        controller: t,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'مبلغ الخصم'),
      ),
      textConfirm: 'تطبيق',
      textCancel: 'إلغاء',
      onConfirm: () {
        final m = parseMinor(t.text);
        if (m == null) {
          Get.snackbar('خطأ', 'أدخل مبلغًا صحيحًا');
          return;
        }
        c.discountMinor.value = m;
        Get.back();
      },
    );
  }

  Future<void> _scanForSale(CashierController c) async {
    await scanContinuous((code) async {
      final db = Get.find<AppDatabase>();
      final product = await db.findProductByCode(code);
      if (product != null) {
        c.addProduct(product);
        return '${product.name} أُضيف للسلة';
      }
      if (code.startsWith('shop:')) return 'رمز المنتج غير موجود';

      final id = await Get.to<int>(() => ProductFormPage(initialBarcode: code));
      if (id == null) return 'تم إلغاء إضافة المنتج';
      final saved = await db.watchProduct(id).first;
      if (saved == null) return 'تعذر العثور على المنتج بعد الحفظ';
      c.addProduct(saved);
      return '${saved.name} أُضيف للسلة';
    });
  }

  Future<void> _pick(CashierController c) async {
    final list = await Get.find<AppDatabase>().watchProducts().first;
    Get.bottomSheet(
      Container(
        color: Get.theme.colorScheme.surface,
        child: ListView(
          children: list
              .map(
                (p) => ListTile(
                  title: Text(p.name),
                  subtitle: Text(
                    '${fmtMinor(p.sellPriceMinor)}  •  المتوفر ${fmtQty(p.quantity)}',
                  ),
                  onTap: () {
                    c.addProduct(p);
                    Get.back();
                  },
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Future<void> _payCash(CashierController c) async {
    final err = await c.payCash();
    if (err != null) {
      Get.snackbar('تنبيه', err);
      return;
    }
    _done(c, 'تم تسجيل البيع');
  }

  Future<void> _payCredit(CashierController c) async {
    if (c.items.isEmpty) {
      Get.snackbar('تنبيه', 'السلة فارغة');
      return;
    }
    final rows = await Get.find<AppDatabase>().watchCustomerBalances().first;
    final names = <int, String>{};
    for (final r in rows) {
      names.putIfAbsent(r.id, () => r.name);
    }
    if (names.isEmpty) {
      Get.snackbar('تنبيه', 'أضف زبونًا أولًا من تبويب الزبائن');
      return;
    }
    final id = await Get.bottomSheet<int>(
      Container(
        color: Get.theme.colorScheme.surface,
        child: ListView(
          children: names.entries
              .map(
                (e) => ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(e.value),
                  onTap: () => Get.back(result: e.key),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (id == null) return;
    final err = await c.payCredit(id, names[id]!);
    if (err != null) {
      Get.snackbar('تنبيه', err);
      return;
    }
    _done(c, 'تم تسجيل الدين على ${names[id]}');
  }

  void _done(CashierController c, String message) {
    Get.defaultDialog(
      title: 'تم تسجيل العملية',
      middleText: '$message\nتم إفراغ السلة وهي جاهزة للطلب التالي.',
      textConfirm: 'بدء طلب جديد',
      textCancel: 'مشاركة الفاتورة',
      onCancel: () =>
          SharePlus.instance.share(ShareParams(text: c.lastReceipt)),
    );
  }
}
