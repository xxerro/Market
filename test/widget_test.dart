import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:market/data/db/app_database.dart';
import 'package:market/features/cashier/receipt_text.dart';
import 'package:market/features/products/csv_import.dart';

void main() {
  test('persists sale payment method and displays it on receipt', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    try {
      final productId = await db.addProduct(
        name: 'اختبار',
        sellMinor: 500,
        quantity: 4,
      );
      final saleId = await db.addCashSale(
        lines: [
          BasketLine(productId: productId, quantity: 1, unitPriceMinor: 500),
        ],
        currency: 'ILS',
        paymentMethod: 'jawwal_pay',
      );

      expect(await db.salePaymentMethod(saleId), 'jawwal_pay');
      final sales = await db.watchSalesSince(DateTime(2000)).first;
      expect(sales, hasLength(1));
      expect(sales.single.totalMinor, 500);

      final receipt = buildReceipt(
        lines: const [ReceiptLine('اختبار', 1, 500)],
        discountMinor: 0,
        totalMinor: 500,
        currency: 'ILS',
        when: DateTime(2026),
        paymentMethod: await db.salePaymentMethod(saleId),
      );
      expect(receipt, contains('طريقة الدفع: جوال باي'));
    } finally {
      await db.close();
    }
  });

  test('parses Arabic CSV product data', () {
    final csv = utf8.encode(
      'الاسم,الباركود,سعر الشراء,سعر البيع,الكمية,الحد الأدنى\n'
      'حليب,7290000000001,3.5,5,24,6\n',
    );

    final result = parseProductsCsv(csv);

    expect(result.fatalError, isNull);
    expect(result.rows, hasLength(1));
    expect(result.problems, isEmpty);
  });
}
