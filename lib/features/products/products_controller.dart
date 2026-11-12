import 'dart:async';

import 'package:get/get.dart';

import '../../data/db/app_database.dart';

class ProductsController extends GetxController {
  final AppDatabase _db = Get.find<AppDatabase>();
  final all = <Product>[].obs;
  final query = ''.obs;
  StreamSubscription<List<Product>>? _sub;

  @override
  void onInit() {
    super.onInit();
    _sub = _db.watchProducts().listen(all.assignAll);
  }

  List<Product> filtered() {
    final q = query.value.trim().toLowerCase();
    if (q.isEmpty) return all.toList();
    return all
        .where((p) =>
            p.name.toLowerCase().contains(q) || (p.barcode ?? '').contains(q))
        .toList();
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }
}
