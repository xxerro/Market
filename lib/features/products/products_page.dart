import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../cashier/cashier_controller.dart';

import '../../core/empty_state.dart';
import '../../core/money.dart';
import '../../data/db/app_database.dart';
import '../scan/scan_page.dart';
import 'product_detail_page.dart';
import 'import_products_page.dart';
import 'labels_page.dart';
import 'product_form_page.dart';
import 'products_controller.dart';

class ProductsPage extends StatelessWidget {
  const ProductsPage({super.key});

  Future<void> _scan() async {
    final code = await scanCode();
    if (code == null || code.isEmpty) return;
    final p = await Get.find<AppDatabase>().findProductByCode(code);
    if (p != null) {
      Get.to(() => ProductDetailPage(productId: p.id));
      return;
    }
    if (code.startsWith('shop:')) {
      Get.snackbar(
        'رمز غير معروف',
        'ما في منتج بهذا الرمز؛ تحقق من الرمز الممسوح.',
      );
      return;
    }
    Get.defaultDialog(
      title: 'إضافة منتج بالباركود؟',
      middleText: 'الباركود $code غير مسجل. أضف المنتج الآن؟',
      textConfirm: 'إضافة المنتج',
      textCancel: 'إلغاء',
      onConfirm: () async {
        Get.back();
        final id = await Get.to<int>(
          () => ProductFormPage(initialBarcode: code),
        );
        if (id == null) return;
        final saved = await Get.find<AppDatabase>().watchProduct(id).first;
        if (saved == null) return;
        if (Get.isRegistered<CashierController>()) {
          Get.find<CashierController>().addProduct(saved);
        }
        Get.snackbar('تمت إضافة المنتج', 'أصبح المنتج متاحًا في الكاشير.');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = Get.put(ProductsController());
    return Scaffold(
      appBar: AppBar(
        title: const Text('المنتجات'),
        actions: [
          IconButton(
            tooltip: 'مسح باركود / QR',
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _scan,
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'labels') {
                Get.to(() => const LabelsPage());
              } else {
                Get.to(() => const ImportProductsPage());
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'labels', child: Text('طباعة ملصقات QR')),
              PopupMenuItem(value: 'import', child: Text('استيراد من ملف CSV')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Get.to(() => const ProductFormPage()),
        icon: const Icon(Icons.add),
        label: const Text('منتج جديد'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              onChanged: (v) => c.query.value = v,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'ابحث بالاسم أو الباركود',
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: Obx(() {
              c.all.length; // لتتبع التغييرات
              final list = c.filtered();
              if (list.isEmpty) {
                return EmptyState(
                  icon: c.query.value.trim().isEmpty
                      ? Icons.inventory_2_outlined
                      : Icons.search_off,
                  title: c.query.value.trim().isEmpty
                      ? 'ابدأ بإضافة منتجاتك'
                      : 'ما لقينا نتائج',
                  message: c.query.value.trim().isEmpty
                      ? 'أضف المنتجات لتبدأ البيع وتتبع المخزون بسهولة.'
                      : 'جرّب اسمًا أو باركودًا مختلفًا.',
                  actionLabel: c.query.value.trim().isEmpty
                      ? 'إضافة منتج'
                      : null,
                  onAction: c.query.value.trim().isEmpty
                      ? () => Get.to(() => const ProductFormPage())
                      : null,
                );
              }
              return ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final p = list[i];
                  final low = p.minQuantity > 0 && p.quantity <= p.minQuantity;
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: ListTile(
                      onTap: () =>
                          Get.to(() => ProductDetailPage(productId: p.id)),
                      title: Text(p.name),
                      subtitle: Text(
                        'سعر البيع: ${fmtMinor(p.sellPriceMinor)}',
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            fmtQty(p.quantity),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: low ? Colors.red.shade700 : null,
                            ),
                          ),
                          if (low)
                            Text(
                              'قارب على النفاد',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.red.shade700,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}
