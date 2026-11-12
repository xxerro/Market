import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as pth;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' show PdfPageFormat;
import 'package:pdf/widgets.dart' as pw;
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/money.dart';
import '../../data/db/app_database.dart';

/// يولّد ملف PDF بملصقات QR على ورق A4 بمقاس ملصقات شائعة (3 × 7، مقاس 63.5×38.1 مم).
/// كل صفحة تُرسم كصورة بواسطة Flutter نفسه، فتظهر الحروف العربية بشكل صحيح بدون خطوط إضافية.
class LabelSheetService {
  static const double _dpi = 200;
  static double _mm(double v) => v / 25.4 * _dpi;
  static double _pt(double v) => v / 72 * _dpi;
  static const int _cols = 3;
  static const int _rows = 7;

  /// يرجع مسار ملف الـPDF.
  static Future<String> generate(List<Product> products) async {
    final pageW = _mm(210), pageH = _mm(297);
    final labelW = _mm(63.5), labelH = _mm(38.1);
    final left = _mm(7.2), top = _mm(15.1), colPitch = _mm(66.0);
    const perPage = _cols * _rows;

    final doc = pw.Document();
    for (var start = 0; start < products.length; start += perPage) {
      final chunk = products.skip(start).take(perPage).toList();
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec, Rect.fromLTWH(0, 0, pageW, pageH));
      canvas.drawRect(Rect.fromLTWH(0, 0, pageW, pageH),
          Paint()..color = const Color(0xFFFFFFFF));
      for (var i = 0; i < chunk.length; i++) {
        final r = i ~/ _cols, c = i % _cols;
        _drawLabel(
          canvas,
          Rect.fromLTWH(left + c * colPitch, top + r * labelH, labelW, labelH),
          chunk[i],
        );
      }
      final img = await rec.endRecording().toImage(pageW.round(), pageH.round());
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      final bytes = data!.buffer.asUint8List();
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.fill),
      ));
    }

    final dir = await getTemporaryDirectory();
    final now = DateTime.now();
    final name =
        'qr_labels_${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}.pdf';
    final file = File(pth.join(dir.path, name));
    await file.writeAsBytes(await doc.save(), flush: true);
    return file.path;
  }

  static void _drawLabel(Canvas canvas, Rect r, Product p) {
    // حدود رفيعة تساعد على القص إذا طُبعت على ورق عادي
    canvas.drawRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFFBDBDBD),
    );
    final pad = _mm(3.5);
    final side = r.height - pad * 2;

    canvas.save();
    canvas.translate(r.left + pad, r.top + pad);
    QrPainter(
      data: 'shop:p:${p.id}',
      version: QrVersions.auto,
      gapless: true,
    ).paint(canvas, Size(side, side));
    canvas.restore();

    final textLeft = r.left + pad * 2 + side;
    final textW = r.right - pad - textLeft;

    final name = TextPainter(
      text: TextSpan(
        text: p.name,
        style: TextStyle(
          color: const Color(0xFF000000),
          fontSize: _pt(12),
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.right,
      maxLines: 3,
      ellipsis: '…',
    )..layout(minWidth: textW, maxWidth: textW);
    name.paint(canvas, Offset(textLeft, r.top + pad));

    final price = TextPainter(
      text: TextSpan(
        text: fmtMinor(p.sellPriceMinor),
        style: TextStyle(
          color: const Color(0xFF000000),
          fontSize: _pt(16),
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.right,
    )..layout(minWidth: textW, maxWidth: textW);
    price.paint(canvas, Offset(textLeft, r.bottom - pad - price.height));
  }
}
