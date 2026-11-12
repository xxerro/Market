import 'dart:convert';
import 'dart:typed_data';

import '../../data/db/app_database.dart';

class ImportParseResult {
  final List<ImportRow> rows;
  final List<String> problems;
  final String? fatalError;
  const ImportParseResult({
    this.rows = const [],
    this.problems = const [],
    this.fatalError,
  });
}

/// قالب CSV جاهز (مع BOM ليفتح Excel العربية بشكل صحيح).
const templateCsv =
    '\uFEFFالاسم,الباركود,سعر الشراء,سعر البيع,الكمية,الحد الأدنى\r\n'
    'حليب 1 لتر,7290000000001,3.5,5,24,6\r\n'
    'خبز,,1,2,50,10\r\n';

String _n(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[\s_\-ـ]'), '')
    .replaceAll(RegExp('[أإآ]'), 'ا')
    .replaceAll('ة', 'ه');

final Map<String, List<String>> _synonyms = {
  'name': ['name', 'الاسم', 'اسم المنتج', 'المنتج', 'اسم', 'product'],
  'barcode': ['barcode', 'الباركود', 'باركود', 'code', 'الرمز'],
  'buy': ['buy', 'buy_price', 'cost', 'سعر الشراء', 'الشراء', 'التكلفة'],
  'sell': ['sell', 'sell_price', 'price', 'سعر البيع', 'البيع', 'السعر'],
  'qty': ['quantity', 'qty', 'الكمية', 'كمية', 'المخزون'],
  'min': ['min', 'min_quantity', 'الحد الأدنى', 'حد أدنى', 'الحد الادنى'],
};

String? _headerKey(String header) {
  final h = _n(header);
  for (final e in _synonyms.entries) {
    if (e.value.map(_n).contains(h)) return e.key;
  }
  return null;
}

String _latinDigits(String s) {
  const ar = '٠١٢٣٤٥٦٧٨٩';
  const fa = '۰۱۲۳۴۵۶۷۸۹';
  final b = StringBuffer();
  for (final r in s.runes) {
    final ch = String.fromCharCode(r);
    var i = ar.indexOf(ch);
    if (i < 0) i = fa.indexOf(ch);
    b.write(i >= 0 ? '$i' : ch);
  }
  return b.toString().replaceAll('٫', '.').replaceAll('٬', '');
}

/// يرجع 0 للخلية الفارغة، وnull إذا الرقم غير صالح.
double? _num(String raw) {
  var s = _latinDigits(raw).replaceAll(' ', '');
  if (s.isEmpty) return 0;
  if (s.contains(',') && !s.contains('.')) {
    s = s.replaceAll(',', '.');
  } else {
    s = s.replaceAll(',', '');
  }
  return double.tryParse(s);
}

String _detectDelimiter(String text) {
  final firstLine = text.split(RegExp(r'\r?\n')).firstWhere(
        (l) => l.trim().isNotEmpty,
        orElse: () => '',
      );
  final counts = {
    ',': ','.allMatches(firstLine).length,
    ';': ';'.allMatches(firstLine).length,
    '\t': '\t'.allMatches(firstLine).length,
  };
  var best = ',';
  counts.forEach((k, v) {
    if (v > counts[best]!) best = k;
  });
  return best;
}

List<List<String>> _parseCsv(String text, String delimiter) {
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    if (inQuotes) {
      if (ch == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        field.write(ch);
      }
    } else if (ch == '"') {
      inQuotes = true;
    } else if (ch == delimiter) {
      row.add(field.toString());
      field.clear();
    } else if (ch == '\n' || ch == '\r') {
      if (ch == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      row.add(field.toString());
      field.clear();
      rows.add(row);
      row = <String>[];
    } else {
      field.write(ch);
    }
  }
  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString());
    rows.add(row);
  }
  return rows;
}

ImportParseResult parseProductsCsv(Uint8List bytes) {
  if (bytes.length > 1 && bytes[0] == 0x50 && bytes[1] == 0x4B) {
    return const ImportParseResult(
      fatalError:
          'هذا ملف Excel (xlsx). افتحه في Excel واحفظه باسم: CSV UTF-8 (مفصول بفواصل).',
    );
  }
  String text;
  try {
    text = utf8.decode(bytes);
  } on FormatException {
    return const ImportParseResult(
      fatalError:
          'تعذرت قراءة الملف كنص UTF-8. في Excel: حفظ باسم > CSV UTF-8 (مفصول بفواصل).',
    );
  }
  if (text.startsWith('\uFEFF')) text = text.substring(1);

  final delim = _detectDelimiter(text);
  final table = _parseCsv(text, delim)
      .where((r) => r.any((c) => c.trim().isNotEmpty))
      .toList();
  if (table.isEmpty) {
    return const ImportParseResult(fatalError: 'الملف فارغ.');
  }

  var map = <String, int>{};
  for (var i = 0; i < table.first.length; i++) {
    final key = _headerKey(table.first[i]);
    if (key != null && !map.containsKey(key)) map[key] = i;
  }
  final hasHeader = map.containsKey('name');
  if (!hasHeader) {
    map = {'name': 0, 'barcode': 1, 'buy': 2, 'sell': 3, 'qty': 4, 'min': 5};
  }
  final data = hasHeader ? table.skip(1).toList() : table;
  var lineNo = hasHeader ? 2 : 1;

  final rows = <ImportRow>[];
  final problems = <String>[];
  final sci = RegExp(r'^\d(\.\d+)?e\+?\d+$', caseSensitive: false);

  for (final row in data) {
    final line = lineNo++;
    String cell(String key) {
      final i = map[key];
      if (i == null || i >= row.length) return '';
      return row[i].trim();
    }

    final name = cell('name');
    if (name.isEmpty) {
      problems.add('السطر $line: الاسم فارغ');
      continue;
    }

    var barcode = _latinDigits(cell('barcode')).replaceAll(' ', '');
    if (sci.hasMatch(barcode)) {
      problems.add(
          'السطر $line: الباركود بصيغة علمية ($barcode). نسّق عمود الباركود كنص في Excel.');
      continue;
    }
    barcode = barcode.replaceFirst(RegExp(r'\.0+$'), '');

    final buy = _num(cell('buy'));
    final sell = _num(cell('sell'));
    final qty = _num(cell('qty'));
    final min = _num(cell('min'));
    if (buy == null || sell == null || qty == null || min == null) {
      problems.add('السطر $line ($name): رقم غير صالح');
      continue;
    }
    if (buy < 0 || sell < 0 || qty < 0 || min < 0) {
      problems.add('السطر $line ($name): قيمة سالبة');
      continue;
    }
    rows.add(ImportRow(
      name: name,
      barcode: barcode.isEmpty ? null : barcode,
      buyMinor: (buy * 100).round(),
      sellMinor: (sell * 100).round(),
      quantity: qty,
      minQuantity: min,
    ));
  }
  return ImportParseResult(rows: rows, problems: problems);
}
