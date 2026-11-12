import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as pth;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/db/app_database.dart';
import 'csv_import.dart';

class ImportProductsPage extends StatefulWidget {
  const ImportProductsPage({super.key});

  @override
  State<ImportProductsPage> createState() => _ImportProductsPageState();
}

class _ImportProductsPageState extends State<ImportProductsPage> {
  ImportParseResult? _result;
  String? _fileName;
  bool _busy = false;

  Future<void> _shareTemplate() async {
    try {
      final dir = await getTemporaryDirectory();
      final f = File(pth.join(dir.path, 'products_template.csv'));
      await f.writeAsBytes(utf8.encode(templateCsv), flush: true);
      await SharePlus.instance.share(
        ShareParams(files: [XFile(f.path)]),
      );
    } catch (e) {
      Get.snackbar('خطأ', 'تعذر إنشاء القالب: $e');
    }
  }

  Future<void> _pick() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      final file = files.isEmpty ? null : files.single;
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() {
        _fileName = file.name;
        _result = parseProductsCsv(bytes);
      });
    } catch (e) {
      Get.snackbar('خطأ', 'تعذرت قراءة الملف: $e');
    }
  }

  Future<void> _import() async {
    final r = _result;
    if (r == null || r.rows.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final counts = await Get.find<AppDatabase>().importProducts(r.rows);
      Get.back();
      Get.snackbar('تم الاستيراد',
          'أُضيف ${counts.added} منتج، وتم تخطي ${counts.skipped} (باركود مكرر)');
    } catch (e) {
      setState(() => _busy = false);
      Get.snackbar('خطأ', 'فشل الاستيراد: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return Scaffold(
      appBar: AppBar(title: const Text('استيراد منتجات من CSV')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'جهّز ملف Excel بالأعمدة: الاسم، الباركود، سعر الشراء، سعر البيع، الكمية، '
            'الحد الأدنى. ثم احفظه باسم CSV UTF-8. الاسم هو العمود الوحيد المطلوب. '
            'المنتجات اللي باركودها موجود مسبقًا بتتخطى ولا بتتعدل.',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _shareTemplate,
                  icon: const Icon(Icons.description),
                  label: const Text('تنزيل قالب'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _pick,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('اختيار ملف'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (r != null) ...[
            if (_fileName != null) Text('الملف: $_fileName'),
            const SizedBox(height: 8),
            if (r.fatalError != null)
              Text(r.fatalError!,
                  style: TextStyle(color: Colors.red.shade700))
            else ...[
              Text('جاهز للاستيراد: ${r.rows.length} منتج',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              if (r.problems.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('سطور فيها مشاكل (ستُتجاهل): ${r.problems.length}',
                    style: TextStyle(color: Colors.red.shade700)),
                for (final p in r.problems.take(20)) Text('• $p'),
                if (r.problems.length > 20)
                  Text('... و${r.problems.length - 20} سطر آخر'),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: r.rows.isEmpty || _busy ? null : _import,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('استيراد'),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
