import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../lock/app_lock_controller.dart';
import 'backup_service.dart';
import 'backup_status_controller.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  // ---------- النسخ الاحتياطي ----------

  Future<void> _backup() async {
    try {
      await Get.find<BackupStatusController>().backupNow();
    } catch (e) {
      Get.snackbar('خطأ', 'تعذر إنشاء النسخة الاحتياطية: $e');
    }
  }

  void _confirmRestore() {
    Get.defaultDialog(
      title: 'استعادة نسخة؟',
      middleText: 'سيتم استبدال كل البيانات الحالية ببيانات النسخة المختارة. متابعة؟',
      textConfirm: 'متابعة',
      textCancel: 'إلغاء',
      onConfirm: () async {
        Get.back();
        await _restore();
      },
    );
  }

  Future<void> _restore() async {
    try {
      final r = await BackupService.restore();
      switch (r) {
        case RestoreOutcome.cancelled:
          break;
        case RestoreOutcome.invalidFile:
          Get.snackbar('خطأ', 'هذا الملف ليس نسخة احتياطية صالحة.');
          break;
        case RestoreOutcome.done:
          Get.defaultDialog(
            title: 'تمت الاستعادة',
            middleText: 'سيُغلق التطبيق الآن. افتحه من جديد لتظهر البيانات.',
            barrierDismissible: false,
            textConfirm: 'إغلاق',
            onConfirm: () => SystemNavigator.pop(),
          );
          break;
      }
    } catch (e) {
      Get.snackbar('خطأ', 'تعذرت الاستعادة: $e');
    }
  }

  // ---------- رمز القفل ----------

  Future<String?> _askPin(String title) async {
    final t = TextEditingController();
    String? result;
    await Get.defaultDialog(
      title: title,
      content: TextField(
        controller: t,
        autofocus: true,
        obscureText: true,
        keyboardType: TextInputType.number,
        maxLength: 6,
        decoration: const InputDecoration(counterText: ''),
      ),
      textConfirm: 'موافق',
      textCancel: 'إلغاء',
      onConfirm: () {
        result = t.text;
        Get.back();
      },
    );
    return result;
  }

  /// يسأل عن رمز جديد مرتين ويرجعه إذا تطابقا.
  Future<String?> _askNewPin() async {
    final a = await _askPin('رمز جديد (4 إلى 6 أرقام)');
    if (a == null) return null;
    final b = await _askPin('أعد كتابة الرمز');
    if (b == null) return null;
    if (a != b) {
      Get.snackbar('خطأ', 'الرمزان غير متطابقين');
      return null;
    }
    return a;
  }

  Future<void> _enableLock(AppLockController c) async {
    final pin = await _askNewPin();
    if (pin == null) return;
    final err = await c.enable(pin);
    Get.snackbar(err == null ? 'تم' : 'خطأ', err ?? 'تم تفعيل رمز القفل');
  }

  Future<void> _changeLock(AppLockController c) async {
    final old = await _askPin('الرمز الحالي');
    if (old == null) return;
    final pin = await _askNewPin();
    if (pin == null) return;
    final err = await c.change(old, pin);
    Get.snackbar(err == null ? 'تم' : 'خطأ', err ?? 'تم تغيير الرمز');
  }

  Future<void> _disableLock(AppLockController c) async {
    final pin = await _askPin('أدخل الرمز لإلغاء القفل');
    if (pin == null) return;
    final err = await c.disable(pin);
    Get.snackbar(err == null ? 'تم' : 'خطأ', err ?? 'تم إلغاء القفل');
  }

  void _lockOptions(AppLockController c) {
    Get.bottomSheet(
      Container(
        color: Get.theme.colorScheme.surface,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('تغيير الرمز'),
              onTap: () {
                Get.back();
                _changeLock(c);
              },
            ),
            ListTile(
              leading: const Icon(Icons.lock_open),
              title: const Text('إلغاء القفل'),
              onTap: () {
                Get.back();
                _disableLock(c);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _ago(DateTime d) {
    final days = DateTime.now().difference(d).inDays;
    return days == 0 ? 'اليوم' : 'قبل $days يوم';
  }

  @override
  Widget build(BuildContext context) {
    final lock = Get.find<AppLockController>();
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        children: [
          Obx(() => ListTile(
                leading: Icon(lock.hasPin.value ? Icons.lock : Icons.lock_open),
                title: const Text('رمز القفل'),
                subtitle: Text(lock.hasPin.value
                    ? 'مفعّل: يُطلب عند فتح التطبيق وبعد 30 ثانية في الخلفية'
                    : 'غير مفعّل: أي شخص يفتح الجوال يشوف الديون'),
                onTap: () => lock.hasPin.value
                    ? _lockOptions(lock)
                    : _enableLock(lock),
              )),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'بياناتك محفوظة على هذا الجوال فقط. إذا ضاع الجوال أو انمسح التطبيق '
              'تضيع الديون. خذ نسخة احتياطية كل أسبوع وأرسلها لنفسك على واتساب أو Drive.',
            ),
          ),
          Obx(() {
            final b = Get.find<BackupStatusController>();
            final lb = b.lastBackup.value;
            final overdue = b.overdue;
            return ListTile(
              leading: Icon(Icons.backup,
                  color: overdue ? Colors.red.shade700 : null),
              title: const Text('نسخة احتياطية ومشاركة'),
              subtitle: Text(
                  lb == null ? 'ما أخذت نسخة بعد' : 'آخر نسخة: ${_ago(lb)}'),
              onTap: _backup,
            );
          }),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('استعادة من ملف نسخة احتياطية'),
            onTap: _confirmRestore,
          ),
        ],
      ),
    );
  }
}
