import 'dart:async';

import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/db/app_database.dart';
import 'statement_text.dart';
import 'whatsapp.dart';

class StatementRow {
  final LedgerEntry entry;
  final int runningMinor; // الرصيد بعد هذا القيد بنفس العملة
  const StatementRow(this.entry, this.runningMinor);
}

class CustomerDetailController extends GetxController {
  CustomerDetailController(this.customerId);

  final int customerId;
  final AppDatabase _db = Get.find<AppDatabase>();

  final rows = <StatementRow>[].obs; // الأحدث أولًا
  final totals = <String, int>{}.obs; // الرصيد الحالي لكل عملة
  StreamSubscription<List<LedgerEntry>>? _sub;
  final customer = Rxn<Customer>();
  StreamSubscription<Customer?>? _custSub;

  @override
  void onInit() {
    super.onInit();
    _sub = _db.watchEntries(customerId).listen(_rebuild);
    _custSub = _db.watchCustomer(customerId).listen((c) => customer.value = c);
  }

  void _rebuild(List<LedgerEntry> newestFirst) {
    final oldestFirst = newestFirst.reversed.toList();
    final running = <String, int>{};
    final out = <StatementRow>[];
    for (final e in oldestFirst) {
      if (e.voidedAt == null) {
        final delta = e.type == 'debt' ? e.amountMinor : -e.amountMinor;
        running[e.currency] = (running[e.currency] ?? 0) + delta;
      }
      out.add(StatementRow(e, running[e.currency] ?? 0));
    }
    totals.assignAll(running);
    rows.assignAll(out.reversed);
  }

  /// يرجع false إذا المبلغ غير صالح.
  Future<bool> add(
      String type, String amountText, String currency, String note) async {
    final value = double.tryParse(amountText.trim().replaceAll(',', '.'));
    if (value == null || value <= 0) return false;
    final n = note.trim();
    await _db.addEntry(
      customerId: customerId,
      type: type,
      amountMinor: (value * 100).round(),
      currency: currency,
      note: n.isEmpty ? null : n,
    );
    return true;
  }

  Future<void> void_(int entryId) => _db.voidEntry(entryId);

  Future<void> updateCustomer(String name, String phone, String note) {
    final ph = phone.trim();
    final nt = note.trim();
    return _db.updateCustomer(
      customerId,
      name: name.trim(),
      phone: ph.isEmpty ? null : ph,
      note: nt.isEmpty ? null : nt,
    );
  }

  /// false إذا عليه رصيد.
  Future<bool> archive() => _db.archiveCustomer(customerId);

  /// يرسل كشف الحساب أو التذكير. يرجع رسالة خطأ أو null عند النجاح.
  Future<String?> sendWhatsApp({required bool reminder}) async {
    final cust = await _db.getCustomer(customerId);
    if (cust == null) return 'الزبون غير موجود';
    final totalsCopy = Map<String, int>.of(totals);
    final text = reminder
        ? buildReminder(cust.name, totalsCopy)
        : buildStatement(
            name: cust.name,
            totals: totalsCopy,
            entriesNewestFirst: rows.map((r) => r.entry).toList(),
          );
    if (text == null) return 'لا يوجد مبلغ مستحق على هذا الزبون';
    final phone = normalizePhone(cust.phone);
    if (phone == null) {
      // ما في رقم محفوظ: افتح قائمة المشاركة ليختار المحادثة بنفسه
      await SharePlus.instance.share(ShareParams(text: text));
      return null;
    }
    final uri =
        Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(text)}');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    return ok ? null : 'تعذر فتح واتساب';
  }

  @override
  void onClose() {
    _sub?.cancel();
    _custSub?.cancel();
    super.onClose();
  }
}
