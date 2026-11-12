import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

class Customers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get phone => text().nullable()();
  TextColumn get note => text().nullable()();
  // بالوحدات الصغرى (أغورة/سنت) لتجنب أخطاء الكسور
  IntColumn get creditLimitMinor => integer().nullable()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class LedgerEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get customerId => integer().references(Customers, #id)();
  TextColumn get type => text()(); // 'debt' أو 'payment'
  IntColumn get amountMinor => integer()(); // دائمًا موجب
  TextColumn get currency => text().withDefault(const Constant('ILS'))();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  // الإلغاء يترك أثرًا ولا يحذف القيد
  DateTimeColumn get voidedAt => dateTime().nullable()();
}

class Products extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 150)();
  // باركود المصنع أو رمز التطبيق؛ فريد، ويسمح بعدة قيم null
  TextColumn get barcode => text().nullable().unique()();
  IntColumn get buyPriceMinor => integer().withDefault(const Constant(0))();
  IntColumn get sellPriceMinor => integer().withDefault(const Constant(0))();
  // real لدعم المواد بالوزن (كغ)
  RealColumn get quantity => real().withDefault(const Constant(0.0))();
  RealColumn get minQuantity => real().withDefault(const Constant(0.0))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class StockMovements extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get productId => integer().references(Products, #id)();
  RealColumn get delta => real()(); // موجب = دخول، سالب = خروج
  TextColumn get reason =>
      text()(); // initial | receive | damage | correction | sale
  TextColumn get note => text().nullable()();
  IntColumn get refEntryId => integer().nullable()(); // قيد دين مرتبط
  IntColumn get refSaleId => integer().nullable()(); // فاتورة نقدية مرتبطة
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class LedgerItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get entryId => integer().references(LedgerEntries, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  RealColumn get quantity => real()();
  IntColumn get unitPriceMinor => integer()();
}

/// سطر في سلة الدين قبل الحفظ.
class BasketLine {
  final int productId;
  final double quantity;
  final int unitPriceMinor;
  const BasketLine({
    required this.productId,
    required this.quantity,
    required this.unitPriceMinor,
  });
}

class CurrencyTotal {
  final String currency;
  final int minor;
  const CurrencyTotal(this.currency, this.minor);
}

class DebtorRow {
  final int customerId;
  final String name;
  final String currency;
  final int balanceMinor;
  final DateTime? lastPayment;
  const DebtorRow({
    required this.customerId,
    required this.name,
    required this.currency,
    required this.balanceMinor,
    this.lastPayment,
  });
}

class Sales extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get totalMinor => integer()(); // بعد الخصم
  IntColumn get discountMinor => integer().withDefault(const Constant(0))();
  TextColumn get currency => text().withDefault(const Constant('ILS'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get voidedAt => dateTime().nullable()();
}

class SalePaymentMethods extends Table {
  IntColumn get saleId => integer().references(Sales, #id)();
  TextColumn get paymentMethod => text()();

  @override
  Set<Column> get primaryKey => {saleId};
}

class SaleItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get saleId => integer().references(Sales, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  RealColumn get quantity => real()();
  IntColumn get unitPriceMinor => integer()();
}

class SaleLine {
  final String name;
  final double quantity;
  final int unitPriceMinor;
  const SaleLine(this.name, this.quantity, this.unitPriceMinor);
}

class ImportRow {
  final String name;
  final String? barcode;
  final int buyMinor;
  final int sellMinor;
  final double quantity;
  final double minQuantity;
  const ImportRow({
    required this.name,
    this.barcode,
    this.buyMinor = 0,
    this.sellMinor = 0,
    this.quantity = 0,
    this.minQuantity = 0,
  });
}

class ImportCounts {
  final int added;
  final int skipped;
  const ImportCounts(this.added, this.skipped);
}

/// صف واحد لكل (زبون، عملة). الزبون بدون قيود يظهر بعملة null ورصيد 0.
class CustomerBalance {
  final int id;
  final String name;
  final String? phone;
  final String? currency;
  final int balanceMinor;

  const CustomerBalance({
    required this.id,
    required this.name,
    this.phone,
    this.currency,
    required this.balanceMinor,
  });
}

@DriftDatabase(
  tables: [
    Customers,
    LedgerEntries,
    Products,
    StockMovements,
    LedgerItems,
    Sales,
    SaleItems,
    SalePaymentMethods,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_open());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(products);
        await m.createTable(stockMovements);
      }
      if (from < 3) {
        await m.createTable(ledgerItems);
      }
      if (from < 4) {
        await m.createTable(sales);
        await m.createTable(saleItems);
        await m.addColumn(stockMovements, stockMovements.refSaleId);
      }
      if (from < 5) {
        await m.createTable(salePaymentMethods);
      }
    },
  );

  Future<int> addCustomer(String name, {String? phone, String? note}) {
    return into(customers).insert(
      CustomersCompanion.insert(
        name: name,
        phone: Value(phone),
        note: Value(note),
      ),
    );
  }

  Future<int> addEntry({
    required int customerId,
    required String type, // 'debt' أو 'payment'
    required int amountMinor,
    String currency = 'ILS',
    String? note,
  }) {
    return into(ledgerEntries).insert(
      LedgerEntriesCompanion.insert(
        customerId: customerId,
        type: type,
        amountMinor: amountMinor,
        currency: Value(currency),
        note: Value(note),
      ),
    );
  }

  /// إلغاء قيد: يُحتفظ به في السجل مع وقت الإلغاء ولا يدخل في الرصيد.
  Future<void> voidEntry(int id) {
    return transaction(() async {
      final entry = await (select(
        ledgerEntries,
      )..where((e) => e.id.equals(id))).getSingleOrNull();
      if (entry == null || entry.voidedAt != null) return;
      await (update(ledgerEntries)..where((e) => e.id.equals(id))).write(
        LedgerEntriesCompanion(voidedAt: Value(DateTime.now())),
      );
      // إذا كان القيد دينًا بالمسح: أعد الكميات للمخزون
      final items = await (select(
        ledgerItems,
      )..where((i) => i.entryId.equals(id))).get();
      for (final i in items) {
        await into(stockMovements).insert(
          StockMovementsCompanion.insert(
            productId: i.productId,
            delta: i.quantity,
            reason: 'void_return',
            refEntryId: Value(id),
          ),
        );
        await customUpdate(
          'UPDATE products SET quantity = quantity + ? WHERE id = ?',
          variables: [
            Variable.withReal(i.quantity),
            Variable.withInt(i.productId),
          ],
          updates: {products},
        );
      }
    });
  }

  /// كل قيود الزبون من الأحدث للأقدم (بما فيها الملغاة).
  Stream<List<LedgerEntry>> watchEntries(int customerId) {
    return (select(ledgerEntries)
          ..where((e) => e.customerId.equals(customerId))
          ..orderBy([
            (e) => OrderingTerm.desc(e.createdAt),
            (e) => OrderingTerm.desc(e.id),
          ]))
        .watch();
  }

  // ---------- المنتجات والمخزون ----------

  Future<int> addProduct({
    required String name,
    String? barcode,
    int buyMinor = 0,
    int sellMinor = 0,
    double quantity = 0,
    double minQuantity = 0,
  }) {
    return transaction(() async {
      final id = await into(products).insert(
        ProductsCompanion.insert(
          name: name,
          barcode: Value(barcode),
          buyPriceMinor: Value(buyMinor),
          sellPriceMinor: Value(sellMinor),
          quantity: Value(quantity),
          minQuantity: Value(minQuantity),
        ),
      );
      if (quantity > 0) {
        await into(stockMovements).insert(
          StockMovementsCompanion.insert(
            productId: id,
            delta: quantity,
            reason: 'initial',
          ),
        );
      }
      return id;
    });
  }

  Future<void> updateProduct(
    int id, {
    required String name,
    String? barcode,
    int buyMinor = 0,
    int sellMinor = 0,
    double minQuantity = 0,
  }) {
    return (update(products)..where((p) => p.id.equals(id))).write(
      ProductsCompanion(
        name: Value(name),
        barcode: Value(barcode),
        buyPriceMinor: Value(buyMinor),
        sellPriceMinor: Value(sellMinor),
        minQuantity: Value(minQuantity),
      ),
    );
  }

  /// تعديل الكمية: يسجّل حركة ويحدّث الكمية في نفس العملية.
  Future<void> adjustStock(
    int productId,
    double delta,
    String reason, {
    String? note,
  }) {
    return transaction(() async {
      await into(stockMovements).insert(
        StockMovementsCompanion.insert(
          productId: productId,
          delta: delta,
          reason: reason,
          note: Value(note),
        ),
      );
      await customUpdate(
        'UPDATE products SET quantity = quantity + ? WHERE id = ?',
        variables: [Variable.withReal(delta), Variable.withInt(productId)],
        updates: {products},
      );
    });
  }

  Stream<List<Product>> watchProducts() {
    return (select(products)
          ..where((p) => p.archived.equals(false))
          ..orderBy([(p) => OrderingTerm.asc(p.name)]))
        .watch();
  }

  Stream<Product?> watchProduct(int id) {
    return (select(
      products,
    )..where((p) => p.id.equals(id))).watchSingleOrNull();
  }

  Stream<List<StockMovement>> watchMovements(int productId) {
    return (select(stockMovements)
          ..where((m) => m.productId.equals(productId))
          ..orderBy([
            (m) => OrderingTerm.desc(m.createdAt),
            (m) => OrderingTerm.desc(m.id),
          ]))
        .watch();
  }

  /// دين بعدة منتجات: قيد دين + بنوده + خصم المخزون، كله في عملية واحدة.
  Future<int> addDebtWithItems({
    required int customerId,
    required List<BasketLine> lines,
    String currency = 'ILS',
    String? note,
    int discountMinor = 0,
  }) {
    return transaction(() async {
      var total = 0;
      for (final l in lines) {
        total += (l.quantity * l.unitPriceMinor).round();
      }
      final entryId = await into(ledgerEntries).insert(
        LedgerEntriesCompanion.insert(
          customerId: customerId,
          type: 'debt',
          amountMinor: (total - discountMinor).clamp(0, total).toInt(),
          currency: Value(currency),
          note: Value(note),
        ),
      );
      for (final l in lines) {
        await into(ledgerItems).insert(
          LedgerItemsCompanion.insert(
            entryId: entryId,
            productId: l.productId,
            quantity: l.quantity,
            unitPriceMinor: l.unitPriceMinor,
          ),
        );
        await into(stockMovements).insert(
          StockMovementsCompanion.insert(
            productId: l.productId,
            delta: -l.quantity,
            reason: 'sale',
            refEntryId: Value(entryId),
          ),
        );
        await customUpdate(
          'UPDATE products SET quantity = quantity - ? WHERE id = ?',
          variables: [
            Variable.withReal(l.quantity),
            Variable.withInt(l.productId),
          ],
          updates: {products},
        );
      }
      return entryId;
    });
  }

  /// يقبل رمز التطبيق (`shop:p:<id>`) أو باركود المصنع المخزّن بالمنتج.
  Future<Product?> findProductByCode(String code) {
    final c = code.trim();
    final id = c.startsWith('shop:p:') ? int.tryParse(c.substring(7)) : null;
    return (select(products)..where(
          (p) =>
              (id != null ? p.id.equals(id) : p.barcode.equals(c)) &
              p.archived.equals(false),
        ))
        .getSingleOrNull();
  }

  // ---------- التقارير ----------

  Future<Customer?> getCustomer(int id) {
    return (select(customers)..where((c) => c.id.equals(id))).getSingleOrNull();
  }

  /// إجمالي المستحق لكل عملة: مجموع الأرصدة الموجبة فقط (بدون رصيد لصالح الزبون).
  Future<List<CurrencyTotal>> outstandingDebts() async {
    final rows = await customSelect(
      '''
      SELECT currency, SUM(bal) AS total FROM (
        SELECT customer_id, currency,
               SUM(CASE WHEN type = 'debt' THEN amount_minor
                        ELSE -amount_minor END) AS bal
        FROM ledger_entries WHERE voided_at IS NULL
        GROUP BY customer_id, currency
      ) WHERE bal > 0 GROUP BY currency ORDER BY currency
      ''',
      readsFrom: {ledgerEntries},
    ).get();
    return rows
        .map(
          (r) =>
              CurrencyTotal(r.read<String>('currency'), r.read<int>('total')),
        )
        .toList();
  }

  Future<List<CurrencyTotal>> paymentsSince(DateTime since) async {
    final rows = await customSelect(
      '''
      SELECT currency, SUM(amount_minor) AS total FROM ledger_entries
      WHERE type = 'payment' AND voided_at IS NULL AND created_at >= ?
      GROUP BY currency ORDER BY currency
      ''',
      variables: [Variable.withInt(since.millisecondsSinceEpoch ~/ 1000)],
      readsFrom: {ledgerEntries},
    ).get();
    return rows
        .map(
          (r) =>
              CurrencyTotal(r.read<String>('currency'), r.read<int>('total')),
        )
        .toList();
  }

  /// أكبر الديون لكل عملة، مع تاريخ آخر دفعة.
  Future<List<DebtorRow>> topDebtors({int limit = 20}) async {
    final rows = await customSelect(
      '''
      SELECT c.id AS id, c.name AS name, b.currency AS currency, b.bal AS bal,
        (SELECT MAX(p.created_at) FROM ledger_entries p
          WHERE p.customer_id = c.id AND p.currency = b.currency
            AND p.type = 'payment' AND p.voided_at IS NULL) AS last_payment
      FROM (
        SELECT customer_id, currency,
               SUM(CASE WHEN type = 'debt' THEN amount_minor
                        ELSE -amount_minor END) AS bal
        FROM ledger_entries WHERE voided_at IS NULL
        GROUP BY customer_id, currency HAVING bal > 0
      ) b
      JOIN customers c ON c.id = b.customer_id
      WHERE c.archived = 0
      ORDER BY b.currency, b.bal DESC
      LIMIT ?
      ''',
      variables: [Variable.withInt(limit)],
      readsFrom: {ledgerEntries, customers},
    ).get();
    return rows.map((r) {
      final lp = r.read<int?>('last_payment');
      return DebtorRow(
        customerId: r.read<int>('id'),
        name: r.read<String>('name'),
        currency: r.read<String>('currency'),
        balanceMinor: r.read<int>('bal'),
        lastPayment: lp == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(lp * 1000),
      );
    }).toList();
  }

  Future<List<Product>> lowStockProducts() {
    return (select(products)
          ..where(
            (p) =>
                p.archived.equals(false) &
                p.minQuantity.isBiggerThanValue(0.0) &
                p.quantity.isSmallerOrEqual(p.minQuantity),
          )
          ..orderBy([(p) => OrderingTerm.asc(p.name)]))
        .get();
  }

  // ---------- الكاشير (مبيعات نقدية) ----------

  /// بيع نقدي: فاتورة + بنودها + خصم المخزون في عملية واحدة. يرجع رقم الفاتورة.
  Future<int> addCashSale({
    required List<BasketLine> lines,
    int discountMinor = 0,
    String currency = 'ILS',
    String paymentMethod = 'cash',
  }) {
    return transaction(() async {
      var subtotal = 0;
      for (final l in lines) {
        subtotal += (l.quantity * l.unitPriceMinor).round();
      }
      final discount = discountMinor.clamp(0, subtotal).toInt();
      final saleId = await into(sales).insert(
        SalesCompanion.insert(
          totalMinor: subtotal - discount,
          discountMinor: Value(discount),
          currency: Value(currency),
        ),
      );
      await into(salePaymentMethods).insert(
        SalePaymentMethodsCompanion.insert(
          saleId: Value(saleId),
          paymentMethod: paymentMethod,
        ),
      );
      for (final l in lines) {
        await into(saleItems).insert(
          SaleItemsCompanion.insert(
            saleId: saleId,
            productId: l.productId,
            quantity: l.quantity,
            unitPriceMinor: l.unitPriceMinor,
          ),
        );
        await into(stockMovements).insert(
          StockMovementsCompanion.insert(
            productId: l.productId,
            delta: -l.quantity,
            reason: 'sale',
            refSaleId: Value(saleId),
          ),
        );
        await customUpdate(
          'UPDATE products SET quantity = quantity - ? WHERE id = ?',
          variables: [
            Variable.withReal(l.quantity),
            Variable.withInt(l.productId),
          ],
          updates: {products},
        );
      }
      return saleId;
    });
  }

  /// إلغاء فاتورة نقدية: تبقى في السجل مشطوبة وتُرجَع الكميات للمخزون.
  Future<void> voidSale(int id) {
    return transaction(() async {
      final sale = await (select(
        sales,
      )..where((s) => s.id.equals(id))).getSingleOrNull();
      if (sale == null || sale.voidedAt != null) return;
      await (update(sales)..where((s) => s.id.equals(id))).write(
        SalesCompanion(voidedAt: Value(DateTime.now())),
      );
      final items = await (select(
        saleItems,
      )..where((i) => i.saleId.equals(id))).get();
      for (final i in items) {
        await into(stockMovements).insert(
          StockMovementsCompanion.insert(
            productId: i.productId,
            delta: i.quantity,
            reason: 'void_return',
            refSaleId: Value(id),
          ),
        );
        await customUpdate(
          'UPDATE products SET quantity = quantity + ? WHERE id = ?',
          variables: [
            Variable.withReal(i.quantity),
            Variable.withInt(i.productId),
          ],
          updates: {products},
        );
      }
    });
  }

  Stream<List<Sale>> watchSalesSince(DateTime since) {
    return (select(sales)
          ..where((s) => s.createdAt.isBiggerOrEqualValue(since))
          ..orderBy([
            (s) => OrderingTerm.desc(s.createdAt),
            (s) => OrderingTerm.desc(s.id),
          ]))
        .watch();
  }

  Future<String> salePaymentMethod(int saleId) async {
    final row = await (select(
      salePaymentMethods,
    )..where((method) => method.saleId.equals(saleId))).getSingleOrNull();
    return row?.paymentMethod ?? 'cash';
  }

  Future<List<SaleLine>> saleLines(int saleId) async {
    final rows = await customSelect(
      '''
      SELECT p.name AS name, i.quantity AS qty, i.unit_price_minor AS price
      FROM sale_items i JOIN products p ON p.id = i.product_id
      WHERE i.sale_id = ? ORDER BY i.id
      ''',
      variables: [Variable.withInt(saleId)],
      readsFrom: {saleItems, products},
    ).get();
    return rows
        .map(
          (r) => SaleLine(
            r.read<String>('name'),
            r.read<double>('qty'),
            r.read<int>('price'),
          ),
        )
        .toList();
  }

  Future<List<CurrencyTotal>> cashSalesSince(DateTime since) async {
    final rows = await customSelect(
      '''
      SELECT currency, SUM(total_minor) AS total FROM sales
      WHERE voided_at IS NULL AND created_at >= ?
      GROUP BY currency ORDER BY currency
      ''',
      variables: [Variable.withInt(since.millisecondsSinceEpoch ~/ 1000)],
      readsFrom: {sales},
    ).get();
    return rows
        .map(
          (r) =>
              CurrencyTotal(r.read<String>('currency'), r.read<int>('total')),
        )
        .toList();
  }

  /// مبيعات الدين بالمسح (قيود دين لها بنود).
  Future<List<CurrencyTotal>> creditSalesSince(DateTime since) async {
    final rows = await customSelect(
      '''
      SELECT e.currency AS currency, SUM(e.amount_minor) AS total
      FROM ledger_entries e
      WHERE e.type = 'debt' AND e.voided_at IS NULL AND e.created_at >= ?
        AND EXISTS (SELECT 1 FROM ledger_items i WHERE i.entry_id = e.id)
      GROUP BY e.currency ORDER BY e.currency
      ''',
      variables: [Variable.withInt(since.millisecondsSinceEpoch ~/ 1000)],
      readsFrom: {ledgerEntries, ledgerItems},
    ).get();
    return rows
        .map(
          (r) =>
              CurrencyTotal(r.read<String>('currency'), r.read<int>('total')),
        )
        .toList();
  }

  // ---------- تعديل وأرشفة واستيراد ----------

  Stream<Customer?> watchCustomer(int id) {
    return (select(
      customers,
    )..where((c) => c.id.equals(id))).watchSingleOrNull();
  }

  Future<void> updateCustomer(
    int id, {
    required String name,
    String? phone,
    String? note,
  }) {
    return (update(customers)..where((c) => c.id.equals(id))).write(
      CustomersCompanion(
        name: Value(name),
        phone: Value(phone),
        note: Value(note),
      ),
    );
  }

  /// يرجع false إذا على الزبون رصيد غير صفر (لا يُسمح بأرشفته).
  Future<bool> archiveCustomer(int id) async {
    final rows = await customSelect(
      '''
      SELECT SUM(CASE WHEN type = 'debt' THEN amount_minor
                      ELSE -amount_minor END) AS bal
      FROM ledger_entries
      WHERE customer_id = ? AND voided_at IS NULL
      GROUP BY currency
      ''',
      variables: [Variable.withInt(id)],
      readsFrom: {ledgerEntries},
    ).get();
    if (rows.any((r) => r.read<int>('bal') != 0)) return false;
    await (update(customers)..where((c) => c.id.equals(id))).write(
      const CustomersCompanion(archived: Value(true)),
    );
    return true;
  }

  Future<void> archiveProduct(int id) {
    return (update(products)..where((p) => p.id.equals(id))).write(
      const ProductsCompanion(archived: Value(true)),
    );
  }

  /// يستورد منتجات؛ يتخطى أي باركود موجود مسبقًا (أو مكرر داخل الملف).
  Future<ImportCounts> importProducts(List<ImportRow> rows) {
    return transaction(() async {
      final existing = (await select(
        products,
      ).get()).map((p) => p.barcode).whereType<String>().toSet();
      var added = 0;
      var skipped = 0;
      for (final r in rows) {
        final bc = r.barcode;
        if (bc != null) {
          if (existing.contains(bc)) {
            skipped++;
            continue;
          }
          existing.add(bc);
        }
        final id = await into(products).insert(
          ProductsCompanion.insert(
            name: r.name,
            barcode: Value(bc),
            buyPriceMinor: Value(r.buyMinor),
            sellPriceMinor: Value(r.sellMinor),
            quantity: Value(r.quantity),
            minQuantity: Value(r.minQuantity),
          ),
        );
        if (r.quantity > 0) {
          await into(stockMovements).insert(
            StockMovementsCompanion.insert(
              productId: id,
              delta: r.quantity,
              reason: 'initial',
            ),
          );
        }
        added++;
      }
      return ImportCounts(added, skipped);
    });
  }

  /// الرصيد = مجموع الديون - مجموع الدفعات (غير الملغاة)، ولا يُخزَّن كحقل.
  Stream<List<CustomerBalance>> watchCustomerBalances() {
    return customSelect(
      '''
      SELECT c.id AS id, c.name AS name, c.phone AS phone, e.currency AS currency,
             COALESCE(SUM(CASE WHEN e.type = 'debt' THEN e.amount_minor
                               ELSE -e.amount_minor END), 0) AS balance
      FROM customers c
      LEFT JOIN ledger_entries e
        ON e.customer_id = c.id AND e.voided_at IS NULL
      WHERE c.archived = 0
      GROUP BY c.id, e.currency
      ORDER BY c.name
      ''',
      readsFrom: {customers, ledgerEntries},
    ).watch().map(
      (rows) => rows
          .map(
            (r) => CustomerBalance(
              id: r.read<int>('id'),
              name: r.read<String>('name'),
              phone: r.read<String?>('phone'),
              currency: r.read<String?>('currency'),
              balanceMinor: r.read<int>('balance'),
            ),
          )
          .toList(),
    );
  }
}

/// مسار ملف قاعدة البيانات (يُستخدم للنسخ الاحتياطي والاستعادة).
Future<File> databaseFile() async {
  final dir = await getApplicationDocumentsDirectory();
  return File(p.join(dir.path, 'shop_debt.sqlite'));
}

LazyDatabase _open() {
  return LazyDatabase(() async {
    return NativeDatabase.createInBackground(await databaseFile());
  });
}
