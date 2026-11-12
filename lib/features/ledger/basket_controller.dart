import 'package:get/get.dart';

import '../../core/money.dart';
import '../../data/db/app_database.dart';
import '../scan/scan_page.dart';

class BasketItem {
  BasketItem(this.product, double qty) : qty = qty.obs;
  final Product product;
  final RxDouble qty;
  int get lineMinor => (qty.value * product.sellPriceMinor).round();
}

class BasketController extends GetxController {
  BasketController(this.customerId);

  final int customerId;
  final AppDatabase _db = Get.find<AppDatabase>();
  final items = <BasketItem>[].obs;
  final currency = 'ILS'.obs;

  int get totalMinor => items.fold(0, (s, i) => s + i.lineMinor);

  void addProduct(Product p) {
    final i = items.indexWhere((x) => x.product.id == p.id);
    if (i >= 0) {
      items[i].qty.value += 1;
    } else {
      items.add(BasketItem(p, 1));
    }
  }

  void inc(BasketItem it) => it.qty.value += 1;

  void dec(BasketItem it) {
    if (it.qty.value <= 1) {
      items.remove(it);
    } else {
      it.qty.value -= 1;
    }
  }

  /// يرجع رسالة خطأ أو null عند النجاح.
  Future<String?> scanAdd() async {
    final code = await scanCode();
    if (code == null || code.isEmpty) return null;
    final p = await _db.findProductByCode(code);
    if (p == null) return 'ما في منتج بهذا الرمز: $code';
    addProduct(p);
    return null;
  }

  Future<String?> confirm(String note) async {
    if (items.isEmpty) return 'أضف منتجًا واحدًا على الأقل';
    final total = totalMinor;
    if (total <= 0) return 'حدد سعر البيع للمنتجات أولًا';
    final lines = items
        .map((i) => BasketLine(
              productId: i.product.id,
              quantity: i.qty.value,
              unitPriceMinor: i.product.sellPriceMinor,
            ))
        .toList();
    var n = note.trim();
    if (n.isEmpty) {
      n = items
          .map((i) => '${i.product.name} ×${fmtQty(i.qty.value)}')
          .join('، ');
      if (n.length > 120) n = '${n.substring(0, 117)}...';
    }
    await _db.addDebtWithItems(
      customerId: customerId,
      lines: lines,
      currency: currency.value,
      note: n,
    );
    return null;
  }
}
