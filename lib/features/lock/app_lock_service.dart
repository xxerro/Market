import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// يحفظ بصمة (hash) الرمز في ملف منفصل عن قاعدة البيانات، فلا يدخل في النسخ الاحتياطي.
/// هذا يعني أن استعادة نسخة على جوال جديد لا تعيد القفل القديم.
class AppLockService {
  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'lock.json'));
  }

  String _hash(String salt, String pin) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();

  Future<bool> hasPin() async => (await _file()).exists();

  Future<void> setPin(String pin) async {
    final rnd = Random.secure();
    final salt =
        base64UrlEncode(List<int>.generate(16, (_) => rnd.nextInt(256)));
    await (await _file()).writeAsString(
      jsonEncode({'salt': salt, 'hash': _hash(salt, pin)}),
      flush: true,
    );
  }

  Future<bool> verify(String pin) async {
    final f = await _file();
    if (!await f.exists()) return true;
    try {
      final m = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      return _hash(m['salt'] as String, pin) == m['hash'];
    } catch (_) {
      return false;
    }
  }

  Future<void> clearPin() async {
    final f = await _file();
    if (await f.exists()) await f.delete();
  }
}
