import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/db/app_database.dart';

enum RestoreOutcome { cancelled, invalidFile, done }

class BackupService {
  static String _two(int n) => n.toString().padLeft(2, '0');

  /// ينشئ نسخة متسقة من قاعدة البيانات ويفتح قائمة المشاركة (واتساب، Drive...).
  static Future<void> backupAndShare() async {
    final db = Get.find<AppDatabase>();
    final tmp = await getTemporaryDirectory();
    final now = DateTime.now();
    final name =
        'shop_debt_backup_${now.year}-${_two(now.month)}-${_two(now.day)}.sqlite';
    final path = p.join(tmp.path, name);
    final out = File(path);
    if (await out.exists()) await out.delete();
    try {
      await db.customStatement('VACUUM INTO ?', [path]);
    } catch (_) {
      // بديل: نسخ الملف مباشرة
      final src = await databaseFile();
      await src.copy(path);
    }
    final result = await SharePlus.instance.share(ShareParams(
      files: [XFile(path)],
      text: 'نسخة احتياطية من دفتر الدين',
    ));
    // نسجّل النسخة إلا إذا أغلق المستخدم قائمة المشاركة بدون اختيار
    if (result.status != ShareResultStatus.dismissed) {
      await BackupMeta.markBackup();
    }
  }

  /// يستبدل قاعدة البيانات الحالية بملف نسخة احتياطية. بعده لازم يُعاد تشغيل التطبيق.
  static Future<RestoreOutcome> restore() async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['sqlite', 'db'],
    );
    if (picked == null) return RestoreOutcome.cancelled;
    final bytes = await picked.readAsBytes();
    if (bytes.length < 100 ||
        String.fromCharCodes(bytes.sublist(0, 15)) != 'SQLite format 3') {
      return RestoreOutcome.invalidFile;
    }
    final db = Get.find<AppDatabase>();
    final target = await databaseFile();
    await db.close();
    if (await target.exists()) {
      // نسخة أمان من البيانات الحالية قبل الاستبدال
      await target.copy('${target.path}.before_restore');
    }
    for (final suffix in ['-wal', '-shm', '-journal']) {
      final f = File('${target.path}$suffix');
      if (await f.exists()) await f.delete();
    }
    await target.writeAsBytes(bytes, flush: true);
    return RestoreOutcome.done;
  }
}

/// يحفظ تاريخ أول استخدام وآخر نسخة احتياطية في ملف منفصل عن قاعدة البيانات.
class BackupMeta {
  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'backup_meta.json'));
  }

  static Future<Map<String, dynamic>> _read() async {
    try {
      final f = await _file();
      if (!await f.exists()) return {};
      return jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  static Future<void> _write(Map<String, dynamic> m) async {
    await (await _file()).writeAsString(jsonEncode(m), flush: true);
  }

  static Future<DateTime> installedAt() async {
    final m = await _read();
    final d = DateTime.tryParse(m['installedAt'] as String? ?? '');
    if (d != null) return d;
    final now = DateTime.now();
    m['installedAt'] = now.toIso8601String();
    await _write(m);
    return now;
  }

  static Future<DateTime?> lastBackup() async {
    final m = await _read();
    return DateTime.tryParse(m['lastBackup'] as String? ?? '');
  }

  static Future<void> markBackup() async {
    final m = await _read();
    m['lastBackup'] = DateTime.now().toIso8601String();
    await _write(m);
  }
}
