import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// مسح مرة واحدة: يرجع النص الممسوح، أو null إذا رجع المستخدم.
Future<String?> scanCode() async {
  final result = await Get.to<String>(() => const ScanPage());
  return result;
}

/// مسح متتابع (للكاشير): الشاشة تبقى مفتوحة، ولكل رمز تُستدعى [onCode]
/// وتعرض نصها القصير كتأكيد. تنتهي عندما يضغط المستخدم "تم".
Future<void> scanContinuous(Future<String> Function(String code) onCode) async {
  await Get.to<void>(() => ScanPage(onCode: onCode));
}

class ScanPage extends StatefulWidget {
  const ScanPage({super.key, this.onCode});
  final Future<String> Function(String code)? onCode;

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final MobileScannerController _controller = MobileScannerController();
  final TextEditingController _manual = TextEditingController();
  bool _done = false;
  String? _toast;
  String? _lastCode;
  DateTime? _lastAt;

  bool get _batch => widget.onCode != null;

  Future<void> _deliver(String raw) async {
    final code = raw.trim();
    if (code.isEmpty) return;
    if (!_batch) {
      if (_done) return;
      _done = true;
      Get.back(result: code);
      return;
    }
    // منع تكرار نفس الرمز بسرعة (الكاميرا تلتقطه عدة مرات)
    final now = DateTime.now();
    if (code == _lastCode &&
        _lastAt != null &&
        now.difference(_lastAt!) < const Duration(milliseconds: 1500)) {
      return;
    }
    _lastCode = code;
    _lastAt = now;
    final msg = await widget.onCode!(code);
    HapticFeedback.mediumImpact();
    if (!mounted) return;
    setState(() => _toast = msg);
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted && _toast == msg) setState(() => _toast = null);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _manual.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_batch ? 'مسح متتابع' : 'مسح'),
        actions: [
          IconButton(
            tooltip: 'الفلاش',
            icon: const Icon(Icons.flashlight_on),
            onPressed: () => _controller.toggleTorch(),
          ),
          if (_batch)
            TextButton(onPressed: () => Get.back(), child: const Text('تم')),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: (capture) {
                    if (capture.barcodes.isEmpty) return;
                    final v = capture.barcodes.first.rawValue;
                    if (v != null) _deliver(v);
                  },
                ),
                if (_toast != null)
                  Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      margin: const EdgeInsets.all(12),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_toast!,
                          style: const TextStyle(color: Colors.white)),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _manual,
                    decoration: const InputDecoration(
                      labelText: 'أو اكتب الرمز يدويًا',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (v) {
                      _deliver(v);
                      _manual.clear();
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.check),
                  onPressed: () {
                    _deliver(_manual.text);
                    _manual.clear();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
