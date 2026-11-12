import 'dart:async';

import 'package:get/get.dart';

import '../../data/db/app_database.dart';

class CustomersController extends GetxController {
  final AppDatabase _db = Get.find<AppDatabase>();
  final balances = <CustomerBalance>[].obs;
  StreamSubscription<List<CustomerBalance>>? _sub;

  @override
  void onInit() {
    super.onInit();
    _sub = _db.watchCustomerBalances().listen(balances.assignAll);
  }

  Future<void> add(String name, String? phone) async {
    final n = name.trim();
    if (n.isEmpty) return;
    final ph = phone?.trim();
    await _db.addCustomer(n, phone: (ph == null || ph.isEmpty) ? null : ph);
  }

  Future<void> updateCustomer(
    int id, {
    required String name,
    String? phone,
    String? note,
  }) {
    return _db.updateCustomer(
      id,
      name: name.trim(),
      phone: phone?.trim().isEmpty ?? true ? null : phone!.trim(),
      note: note?.trim().isEmpty ?? true ? null : note!.trim(),
    );
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }
}
