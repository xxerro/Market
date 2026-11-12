import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/db/app_database.dart';
import 'labels_service.dart';

class LabelsPage extends StatefulWidget {
  const LabelsPage({super.key});

  @override
  State<LabelsPage> createState() => _LabelsPageState();
}

class _LabelsPageState extends State<LabelsPage> {
  List<Product>? _products;
  final Set<int> _selected = {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    Get.find<AppDatabase>().watchProducts().first.then((list) {
      if (!mounted) return;
      setState(() {
        _products = list;
        _selected.addAll(list.map((p) => p.id));
      });
    });
  }

  Future<void> _generate() async {
    final all = _products ?? const <Product>[];
    final chosen = all.where((p) => _selected.contains(p.id)).toList();
    if (chosen.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final path = await LabelSheetService.generate(chosen);
      await SharePlus.instance.share(ShareParams(
        files: [XFile(path)],
        text: 'ملصقات QR للمنتجات',
      ));
    } catch (e) {
      Get.snackbar('خطأ', 'تعذر إنشاء الملف: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _products;
    final pages = (_selected.length / 21).ceil();
    return Scaffold(
      appBar: AppBar(
        title: const Text('طباعة ملصقات QR'),
        actions: [
          if (list != null)
            TextButton(
              onPressed: () => setState(() {
                if (_selected.length == list.length) {
                  _selected.clear();
                } else {
                  _selected.addAll(list.map((p) => p.id));
                }
              }),
              child: Text(_selected.length == list.length ? 'إلغاء الكل' : 'تحديد الكل'),
            ),
        ],
      ),
      body: list == null
          ? const Center(child: CircularProgressIndicator())
          : list.isEmpty
              ? const Center(child: Text('ما في منتجات.'))
              : ListView(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'يُنشأ ملف PDF بمقاس A4 (21 ملصقًا بالصفحة، 3×7). اطبعه على ورق '
                        'ملصقات بمقاس 63.5×38.1 مم أو على ورق عادي وقصّه.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    for (final p in list)
                      CheckboxListTile(
                        value: _selected.contains(p.id),
                        title: Text(p.name),
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _selected.add(p.id);
                          } else {
                            _selected.remove(p.id);
                          }
                        }),
                      ),
                  ],
                ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            onPressed: _selected.isEmpty || _busy ? null : _generate,
            icon: _busy
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.picture_as_pdf),
            label: Text(_selected.isEmpty
                ? 'اختر منتجات'
                : 'إنشاء PDF (${_selected.length} ملصق، $pages صفحة)'),
          ),
        ),
      ),
    );
  }
}
