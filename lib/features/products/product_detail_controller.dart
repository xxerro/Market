import 'dart:async';

import 'package:get/get.dart';

import '../../data/db/app_database.dart';

class ProductDetailController extends GetxController {
  ProductDetailController(this.productId);

  final int productId;
  final AppDatabase _db = Get.find<AppDatabase>();
  final product = Rxn<Product>();
  final movements = <StockMovement>[].obs;
  StreamSubscription<Product?>? _s1;
  StreamSubscription<List<StockMovement>>? _s2;

  @override
  void onInit() {
    super.onInit();
    _s1 = _db.watchProduct(productId).listen((p) => product.value = p);
    _s2 = _db.watchMovements(productId).listen(movements.assignAll);
  }

  /// يرجع رسالة خطأ، أو null عند النجاح.
  Future<String?> adjust(
      double delta, String reason, String note) async {
    final p = product.value;
    if (p == null) return 'المنتج غير موجود';
    if (delta == 0) return 'أدخل كمية أكبر من صفر';
    if (p.quantity + delta < -1e-9) return 'الكمية المتوفرة غير كافية';
    final n = note.trim();
    await _db.adjustStock(productId, delta, reason,
        note: n.isEmpty ? null : n);
    return null;
  }

  @override
  void onClose() {
    _s1?.cancel();
    _s2?.cancel();
    super.onClose();
  }
}
