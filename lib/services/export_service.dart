import 'dart:io';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/constants.dart';
import '../models/app_settings.dart';
import '../models/category.dart';
import '../models/item.dart';

enum ExportFormat { csv, excel, sqlite }

class ExportResult {
  final String filePath;
  final int itemCount;
  final ExportFormat format;
  final String? error;

  const ExportResult({
    required this.filePath,
    required this.itemCount,
    required this.format,
    this.error,
  });
  bool get success => error == null;
}

/// Handles exporting the inventory to CSV, Excel (.xlsx), and SQLite.
class ExportService {
  static final _dateFmt = DateFormat('yyyy-MM-dd HH:mm');
  static final _fileDate = DateFormat('yyyy-MM-dd');

  static const _headers = [
    'ID', 'Name', 'Category', 'Sub-Category', 'Room',
    'Identified As', 'Barcode', 'Voice Description', 'Notes',
    'Estimated Value', 'Packing Status',
    'Marketplace', 'Listing Type', 'Price', 'Shipping',
    'Photos', 'Created', 'Updated',
  ];

  Future<Directory> _exportDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, AppConstants.exportSubDir));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  List<dynamic> _itemToRow(Item item) => [
        item.id,
        item.displayName,
        item.category.displayName,
        item.subCategory ?? '',
        item.roomLocation ?? '',
        item.identifiedAs ?? '',
        item.barcodeValue ?? '',
        item.voiceDescription ?? '',
        item.notes ?? '',
        item.estimatedValue ?? '',
        item.packingStatus.displayName,
        item.sellDetails?.marketplace ?? '',
        item.sellDetails?.listingType.displayName ?? '',
        item.sellDetails?.price ?? '',
        item.sellDetails?.shippingOption.displayName ?? '',
        item.photoPaths.join('; '),
        _dateFmt.format(item.createdAt),
        _dateFmt.format(item.updatedAt),
      ];

  // ---- CSV ------------------------------------------------------------------

  Future<ExportResult> exportCsv(List<Item> items, {String? customDir}) async {
    try {
      final dir = customDir != null ? Directory(customDir) : await _exportDir();
      final fname = 'inventory_${_fileDate.format(DateTime.now())}.csv';
      final file = File(p.join(dir.path, fname));

      final rows = [_headers, ...items.map(_itemToRow)];
      final csv = const ListToCsvConverter().convert(rows);
      await file.writeAsString(csv);

      return ExportResult(
          filePath: file.path, itemCount: items.length, format: ExportFormat.csv);
    } catch (e) {
      return ExportResult(
          filePath: '', itemCount: 0, format: ExportFormat.csv, error: e.toString());
    }
  }

  // ---- Excel ----------------------------------------------------------------

  Future<ExportResult> exportExcel(List<Item> items,
      {bool embedPhotos = true, String? customDir}) async {
    try {
      final dir = customDir != null ? Directory(customDir) : await _exportDir();
      final fname = 'inventory_${_fileDate.format(DateTime.now())}.xlsx';
      final file = File(p.join(dir.path, fname));

      final excel = Excel.createExcel();

      // ── Summary sheet ──────────────────────────────────────────────────
      final summary = excel['Summary'];
      summary.appendRow([TextCellValue('Move Item Sorter — Inventory Export')]);
      summary.appendRow([TextCellValue('Generated: ${_dateFmt.format(DateTime.now())}')]);
      summary.appendRow([TextCellValue('Total items: ${items.length}')]);
      summary.appendRow([]);

      // Count by category
      for (final cat in Category.values) {
        final count = items.where((i) => i.category == cat).length;
        if (count > 0) {
          summary.appendRow([TextCellValue(cat.displayName), IntCellValue(count)]);
        }
      }

      // Total estimated value
      final totalValue = items
          .where((i) => i.estimatedValue != null)
          .fold(0.0, (sum, i) => sum + i.estimatedValue!);
      summary.appendRow([]);
      summary.appendRow([TextCellValue('Total estimated value'),
          DoubleCellValue(totalValue)]);

      // ── Items sheet ────────────────────────────────────────────────────
      final sheet = excel['Inventory'];
      // Header row (bold)
      sheet.appendRow(_headers.map(TextCellValue.new).toList());

      for (final item in items) {
        sheet.appendRow(_itemToRow(item).map((v) {
          if (v is double) return DoubleCellValue(v);
          if (v is int)    return IntCellValue(v);
          return TextCellValue(v.toString());
        }).toList());
      }

      // ── Sell sheet ─────────────────────────────────────────────────────
      final sellItems = items.where((i) => i.category == Category.sell).toList();
      if (sellItems.isNotEmpty) {
        final sellSheet = excel['For Sale'];
        sellSheet.appendRow([
          'Name', 'Marketplace', 'Type', 'Price', 'Shipping', 'Listed?',
          'Listing URL', 'Description',
        ].map(TextCellValue.new).toList());
        for (final item in sellItems) {
          final sd = item.sellDetails;
          sellSheet.appendRow([
            TextCellValue(item.displayName),
            TextCellValue(sd?.marketplace ?? ''),
            TextCellValue(sd?.listingType.displayName ?? ''),
            sd?.price != null ? DoubleCellValue(sd!.price!) : TextCellValue(''),
            TextCellValue(sd?.shippingOption.displayName ?? ''),
            TextCellValue(sd?.isListed == true ? 'Yes' : 'No'),
            TextCellValue(sd?.listingUrl ?? ''),
            TextCellValue(sd?.description ?? ''),
          ]);
        }
      }

      excel.delete('Sheet1');
      await file.writeAsBytes(excel.encode()!);

      return ExportResult(
          filePath: file.path, itemCount: items.length, format: ExportFormat.excel);
    } catch (e) {
      return ExportResult(
          filePath: '', itemCount: 0, format: ExportFormat.excel, error: e.toString());
    }
  }

  // ---- SQLite ---------------------------------------------------------------

  /// Copies the live database file to the export directory.
  Future<ExportResult> exportSqlite(
      Future<void> Function(String destPath) copyFn, List<Item> items,
      {String? customDir}) async {
    try {
      final dir = customDir != null ? Directory(customDir) : await _exportDir();
      final fname = 'inventory_${_fileDate.format(DateTime.now())}.db';
      final dest = p.join(dir.path, fname);
      await copyFn(dest);
      return ExportResult(
          filePath: dest, itemCount: items.length, format: ExportFormat.sqlite);
    } catch (e) {
      return ExportResult(
          filePath: '', itemCount: 0, format: ExportFormat.sqlite, error: e.toString());
    }
  }

  // ---- Donation receipt (plain-text; real PDF requires pdf package) ---------

  Future<String> generateDonationReceiptText(
      List<Item> items, AppSettings settings) async {
    final donated = items.where((i) => i.category == Category.donate).toList();
    final totalValue = donated
        .where((i) => i.estimatedValue != null)
        .fold(0.0, (s, i) => s + i.estimatedValue!);

    final buf = StringBuffer();
    buf.writeln('DONATION RECEIPT');
    buf.writeln('=' * 40);
    buf.writeln('Date: ${DateFormat('MMMM d, yyyy').format(DateTime.now())}');
    buf.writeln();
    buf.writeln('Donated items:');
    for (final item in donated) {
      final val = item.estimatedValue != null
          ? ' — \$${item.estimatedValue!.toStringAsFixed(2)} FMV'
          : '';
      buf.writeln('  • ${item.displayName}${val}');
    }
    buf.writeln();
    buf.writeln('Total fair-market value: \$${totalValue.toStringAsFixed(2)}');
    buf.writeln();
    buf.writeln('This receipt is for your tax records.');
    buf.writeln('Consult a tax professional for deduction eligibility.');
    return buf.toString();
  }

  // ---- Insurance valuation report ------------------------------------------

  Future<String> generateInsuranceReportText(
      List<Item> items, AppSettings settings) async {
    final buf = StringBuffer();
    buf.writeln('HOUSEHOLD INVENTORY VALUATION REPORT');
    buf.writeln('=' * 45);
    if (settings.insuranceCompany.isNotEmpty) {
      buf.writeln('Insurance company: ${settings.insuranceCompany}');
    }
    if (settings.insurancePolicyNumber.isNotEmpty) {
      buf.writeln('Policy number:     ${settings.insurancePolicyNumber}');
    }
    buf.writeln('Report date:       ${DateFormat('MMMM d, yyyy').format(DateTime.now())}');
    buf.writeln('Total items:       ${items.length}');
    buf.writeln();

    double grandTotal = 0;
    for (final cat in Category.values) {
      final catItems = items.where((i) => i.category == cat).toList();
      if (catItems.isEmpty) continue;
      final catTotal = catItems
          .where((i) => i.estimatedValue != null)
          .fold(0.0, (s, i) => s + i.estimatedValue!);
      grandTotal += catTotal;

      buf.writeln('${cat.displayName.toUpperCase()} (${catItems.length} items)');
      for (final item in catItems) {
        final val = item.estimatedValue != null
            ? '\$${item.estimatedValue!.toStringAsFixed(2)}'
            : 'N/A';
        buf.writeln('  ${item.displayName.padRight(40)} $val');
      }
      buf.writeln('  Sub-total: \$${catTotal.toStringAsFixed(2)}');
      buf.writeln();
    }
    buf.writeln('=' * 45);
    buf.writeln('GRAND TOTAL: \$${grandTotal.toStringAsFixed(2)}');
    return buf.toString();
  }
}
