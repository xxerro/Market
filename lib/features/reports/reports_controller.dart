import 'dart:async';

import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:get/get.dart';

import '../../data/db/app_database.dart';

class ReportsController extends GetxController {
  final AppDatabase _db = Get.find<AppDatabase>();

  final totalDebts = <CurrencyTotal>[].obs;
  final paidToday = <CurrencyTotal>[].obs;
  final paidWeek = <CurrencyTotal>[].obs;
  final paidMonth = <CurrencyTotal>[].obs;
  final debtors = <DebtorRow>[].obs;
  final lowStock = <Product>[].obs;
  final cashSales = <CurrencyTotal>[].obs;
  final creditSales = <CurrencyTotal>[].obs;
  StreamSubscription<dynamic>? _sub;

  @override
  void onInit() {
    super.onInit();
    refreshAll();
    _sub = _db
        .tableUpdates(TableUpdateQuery.onAllTables(
            [_db.ledgerEntries, _db.customers, _db.products, _db.sales]))
        .listen((_) => refreshAll());
  }

  Future<void> refreshAll() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    totalDebts.assignAll(await _db.outstandingDebts());
    paidToday.assignAll(await _db.paymentsSince(startOfDay));
    paidWeek.assignAll(
        await _db.paymentsSince(startOfDay.subtract(const Duration(days: 6))));
    paidMonth.assignAll(
        await _db.paymentsSince(DateTime(now.year, now.month, 1)));
    debtors.assignAll(await _db.topDebtors());
    lowStock.assignAll(await _db.lowStockProducts());
    cashSales.assignAll(await _db.cashSalesSince(startOfDay));
    creditSales.assignAll(await _db.creditSalesSince(startOfDay));
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }
}
