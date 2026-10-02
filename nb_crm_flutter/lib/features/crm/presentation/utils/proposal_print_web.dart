import 'dart:js_interop';

import 'package:web/web.dart';

void printQuotationWeb({
  required String title,
  required String htmlContent,
  void Function(String message)? onMessage,
}) {
  final safeTitle = title
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  final w = window.open('', '_blank');
  if (w == null) {
    onMessage?.call('Please allow pop-ups to print the quotation.');
    return;
  }

  final fullHtml = '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>$safeTitle</title>
  <style>
    @page {
      size: A4 portrait;
      margin: 10mm 14mm 10mm 14mm;
    }
    * {
      box-sizing: border-box;
      -webkit-print-color-adjust: exact !important;
      print-color-adjust: exact !important;
    }
    body {
      margin: 0;
      padding: 0;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
      font-size: 12px;
      line-height: 1.45;
      color: #1e293b;
      background: #f1f5f9;
    }
    .print-actions {
      position: fixed;
      top: 16px;
      right: 16px;
      display: flex;
      gap: 10px;
      background: white;
      padding: 10px 16px;
      border-radius: 8px;
      box-shadow: 0 4px 14px rgba(0,0,0,0.15);
      z-index: 1000;
    }
    .print-btn {
      background: #c5a059;
      color: #0f172a;
      border: none;
      padding: 8px 18px;
      font-weight: 700;
      font-size: 13px;
      border-radius: 6px;
      cursor: pointer;
    }
    .print-btn:hover {
      background: #b58d40;
    }
    .close-btn {
      background: #e2e8f0;
      color: #334155;
      border: none;
      padding: 8px 16px;
      font-weight: 600;
      font-size: 13px;
      border-radius: 6px;
      cursor: pointer;
    }
    .page-container {
      max-width: 210mm;
      min-height: 297mm;
      margin: 20px auto;
      background: #ffffff;
      padding: 12mm 15mm;
      box-shadow: 0 4px 20px rgba(0,0,0,0.08);
      border-radius: 4px;
    }
    @media print {
      body {
        background: #ffffff;
      }
      .print-actions {
        display: none !important;
      }
      .page-container {
        margin: 0;
        padding: 0;
        box-shadow: none;
        border-radius: 0;
        max-width: 100%;
        min-height: auto;
      }
    }
  </style>
</head>
<body>
  <div class="print-actions">
    <button class="print-btn" onclick="window.print()">
      🖨️ Print to Paper / Save PDF
    </button>
    <button class="close-btn" onclick="window.close()">Close</button>
  </div>
  <div class="page-container">
    $htmlContent
  </div>
  <script>
    window.addEventListener('DOMContentLoaded', () => {
      setTimeout(() => {
        window.print();
      }, 400);
    });
  </script>
</body>
</html>''';

  w.document.open();
  w.document.write(fullHtml.toJS);
  w.document.close();
}
