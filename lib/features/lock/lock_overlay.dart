import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app_lock_controller.dart';

/// يُوضع في builder تبع MaterialApp ليغطي كل الشاشات، بما فيها الشاشات المفتوحة فوق الرئيسية.
class LockOverlay extends StatelessWidget {
  const LockOverlay({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = Get.find<AppLockController>();
    return Obx(() {
      if (!c.ready.value) {
        return const Material(child: SizedBox.expand());
      }
      return Stack(
        children: [
          child,
          if (c.locked.value) const Positioned.fill(child: _LockPage()),
        ],
      );
    });
  }
}

class _LockPage extends StatefulWidget {
  const _LockPage();

  @override
  State<_LockPage> createState() => _LockPageState();
}

class _LockPageState extends State<_LockPage> {
  final AppLockController _c = Get.find<AppLockController>();
  String _pin = '';
  String? _error;
  bool _forgot = false;
  bool _busy = false;

  void _press(String d) {
    if (_pin.length >= 6 || _busy) return;
    setState(() {
      _pin += d;
      _error = null;
    });
  }

  void _back() {
    if (_pin.isEmpty || _busy) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submit() async {
    if (_pin.isEmpty || _busy) return;
    setState(() => _busy = true);
    final err = await _c.unlock(_pin);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _pin = '';
      _error = err;
    });
  }

  Widget _key(Widget child, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 72,
          height: 72,
          child: Center(child: child),
        ),
      ),
    );
  }

  Widget _digit(String d) => _key(
        Text(d, style: const TextStyle(fontSize: 28)),
        () => _press(d),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock, size: 48),
                const SizedBox(height: 12),
                const Text('أدخل رمز القفل', style: TextStyle(fontSize: 20)),
                const SizedBox(height: 16),
                SizedBox(
                  height: 20,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < _pin.length; i++)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(Icons.circle, size: 14),
                        ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 28,
                  child: Text(_error ?? '',
                      style: TextStyle(color: Colors.red.shade700)),
                ),
                for (final row in const [
                  ['1', '2', '3'],
                  ['4', '5', '6'],
                  ['7', '8', '9'],
                ])
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [for (final d in row) _digit(d)],
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _key(const Icon(Icons.backspace_outlined), _back),
                    _digit('0'),
                    _key(const Icon(Icons.check_circle, size: 32), _submit),
                  ],
                ),
                TextButton(
                  onPressed: () => setState(() => _forgot = !_forgot),
                  child: const Text('نسيت الرمز؟'),
                ),
                if (_forgot)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'ما في طريقة لتجاوز الرمز. الحل الوحيد: امسح بيانات التطبيق من '
                      'إعدادات الأندرويد، ثم افتحه واستعد آخر نسخة احتياطية. '
                      'بدون نسخة احتياطية، البيانات القديمة تضيع.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
