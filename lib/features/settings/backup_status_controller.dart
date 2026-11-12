import 'package:get/get.dart';

import 'backup_service.dart';

class BackupStatusController extends GetxController {
  final lastBackup = Rxn<DateTime>();
  final installedAt = Rxn<DateTime>();
  final loaded = false.obs;
  final dismissed = false.obs; // إخفاء التنبيه حتى إعادة فتح التطبيق

  @override
  void onInit() {
    super.onInit();
    refreshStatus();
  }

  Future<void> refreshStatus() async {
    installedAt.value = await BackupMeta.installedAt();
    lastBackup.value = await BackupMeta.lastBackup();
    loaded.value = true;
  }

  /// يتأخر التنبيه: يومان بعد أول استخدام إذا ما في نسخة، أو أسبوع بعد آخر نسخة.
  bool get overdue {
    if (!loaded.value) return false;
    final now = DateTime.now();
    final lb = lastBackup.value;
    if (lb == null) {
      final inst = installedAt.value;
      return inst != null && now.difference(inst).inDays >= 2;
    }
    return now.difference(lb).inDays >= 7;
  }

  Future<void> backupNow() async {
    await BackupService.backupAndShare();
    await refreshStatus();
  }
}
