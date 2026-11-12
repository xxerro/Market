import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import 'app_lock_service.dart';

class AppLockController extends GetxController with WidgetsBindingObserver {
  final AppLockService _svc = AppLockService();

  final ready = false.obs; // انتهى تحميل حالة القفل
  final hasPin = false.obs;
  final locked = false.obs;

  static const _relockAfter = Duration(seconds: 30);
  static final _pinPattern = RegExp(r'^\d{4,6}$');

  int _failed = 0;
  DateTime? _lockedOutUntil;
  DateTime? _pausedAt;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  Future<void> _load() async {
    hasPin.value = await _svc.hasPin();
    locked.value = hasPin.value;
    ready.value = true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final at = _pausedAt;
      _pausedAt = null;
      if (hasPin.value && at != null &&
          DateTime.now().difference(at) > _relockAfter) {
        locked.value = true;
      }
    }
  }

  /// يرجع رسالة خطأ أو null عند النجاح.
  Future<String?> unlock(String pin) async {
    final until = _lockedOutUntil;
    final now = DateTime.now();
    if (until != null && now.isBefore(until)) {
      return 'محاولات كثيرة. انتظر ${until.difference(now).inSeconds + 1} ثانية';
    }
    if (await _svc.verify(pin)) {
      _failed = 0;
      locked.value = false;
      return null;
    }
    _failed++;
    if (_failed >= 5) {
      _failed = 0;
      _lockedOutUntil = DateTime.now().add(const Duration(seconds: 30));
      return 'رمز خاطئ. تم إيقاف المحاولات 30 ثانية';
    }
    return 'رمز خاطئ';
  }

  String? _validate(String pin) =>
      _pinPattern.hasMatch(pin) ? null : 'الرمز لازم يكون من 4 إلى 6 أرقام';

  Future<String?> enable(String pin) async {
    final err = _validate(pin);
    if (err != null) return err;
    await _svc.setPin(pin);
    hasPin.value = true;
    return null;
  }

  Future<String?> change(String oldPin, String newPin) async {
    if (!await _svc.verify(oldPin)) return 'الرمز الحالي غير صحيح';
    return enable(newPin);
  }

  Future<String?> disable(String pin) async {
    if (!await _svc.verify(pin)) return 'الرمز غير صحيح';
    await _svc.clearPin();
    hasPin.value = false;
    locked.value = false;
    return null;
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }
}
