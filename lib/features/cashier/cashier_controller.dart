import 'package:get/get.dart';

import '../../core/money.dart';
import '../../data/db/app_database.dart';
import '../ledger/basket_controller.dart' show BasketItem;
import '../scan/scan_page.dart';
import 'receipt_text.dart';

class CashierController extends GetxController {
  final AppDatabase _db = Get.find<AppDatabase>();

  final items = <BasketItem>[].obs;
  final currency = 'ILS'.obs;
  final discountMinor = 0.obs;
  final paymentMethod = 'cash'.obs;
  final processing = false.obs;

  /// نص آخر فاتورة تمت (للمشاركة).
  String lastReceipt = '';

  int get subtotalMinor => items.fold(0, (s, i) => s + i.lineMinor);

  int get effectiveDiscount {
    final sub = subtotalMinor;
    return discountMinor.value > sub ? sub : discountMinor.value;
  }

  int get totalMinor => subtotalMinor - effectiveDiscount;

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

  void clear() {
    items.clear();
    discountMinor.value = 0;
  }

  /// مسح متتابع: كل رمز يُضاف للسلة والشاشة تبقى مفتوحة.
  Future<void> scanBatch() {
    return scanContinuous((code) async {
      final p = await _db.findProductByCode(code);
      if (p == null) return 'غير معروف: $code';
      addProduct(p);
      return '${p.name} ✓';
    });
  }

  String? _validate() {
    if (items.isEmpty) return 'السلة فارغة';
    if (subtotalMinor <= 0) return 'حدد سعر البيع للمنتجات أولًا';
    if (totalMinor <= 0) return 'الإجمالي بعد الخصم صفر';
    return null;
  }

  List<BasketLine> _lines() => items
      .map(
        (i) => BasketLine(
          productId: i.product.id,
          quantity: i.qty.value,
          unitPriceMinor: i.product.sellPriceMinor,
        ),
      )
      .toList();

  String _buildReceipt(String? customerName) => buildReceipt(
    lines: items
        .map(
          (i) => ReceiptLine(
            i.product.name,
            i.qty.value,
            i.product.sellPriceMinor,
          ),
        )
        .toList(),
    discountMinor: effectiveDiscount,
    totalMinor: totalMinor,
    currency: currency.value,
    when: DateTime.now(),
    customerName: customerName,
  );

  /// بيع نقدي. يرجع رسالة خطأ أو null عند النجاح.
  Future<String?> payCash() async {
    final err = _validate();
    if (err != null) return err;
    if (processing.value) return 'العملية قيد التسجيل';
    processing.value = true;
    try {
      final receipt = buildReceipt(
        lines: items
            .map(
              (i) => ReceiptLine(
                i.product.name,
                i.qty.value,
                i.product.sellPriceMinor,
              ),
            )
            .toList(),
        discountMinor: effectiveDiscount,
        totalMinor: totalMinor,
        currency: currency.value,
        when: DateTime.now(),
        paymentMethod: paymentMethod.value,
      );
      await _db.addCashSale(
        lines: _lines(),
        discountMinor: effectiveDiscount,
        currency: currency.value,
        paymentMethod: paymentMethod.value,
      );
      lastReceipt = receipt;
      clear();
      paymentMethod.value = 'cash';
      return null;
    } catch (e) {
      return 'تعذر تسجيل البيع: $e';
    } finally {
      processing.value = false;
    }
  }

  /// بيع على حساب زبون (يُسجَّل كدين ويُخصم من المخزون).
  Future<String?> payCredit(int customerId, String customerName) async {
    if (processing.value) return 'العملية قيد التسجيل';
    final err = _validate();
    if (err != null) return err;
    processing.value = true;
    final receipt = _buildReceipt(customerName);
    var note = items
        .map((i) => '${i.product.name} ×${fmtQty(i.qty.value)}')
        .join('، ');
    if (effectiveDiscount > 0) {
      note = '$note | خصم ${fmtMinor(effectiveDiscount)}';
    }
    if (note.length > 140) note = '${note.substring(0, 137)}...';
    try {
      await _db.addDebtWithItems(
        customerId: customerId,
        lines: _lines(),
        currency: currency.value,
        note: note,
        discountMinor: effectiveDiscount,
      );
      lastReceipt = receipt;
      clear();
      return null;
    } catch (e) {
      return 'تعذر تسجيل الدين: $e';
    } finally {
      processing.value = false;
    }
  }
}
