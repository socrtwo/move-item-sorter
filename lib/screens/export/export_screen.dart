import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../../providers/app_providers.dart';
import '../../services/export_service.dart';

class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  bool _includePhotos = true;
  bool _loading = false;
  String? _lastExportPath;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _includePhotos = ref.read(settingsProvider).includePhotosInExport;
  }

  Future<void> _export(ExportFormat format) async {
    setState(() { _loading = true; _statusMessage = null; });
    final items = ref.read(itemsProvider).valueOrNull ?? [];
    final exportService = ref.read(exportServiceProvider);

    ExportResult result;
    switch (format) {
      case ExportFormat.csv:
        result = await exportService.exportCsv(items);
        break;
      case ExportFormat.excel:
        result = await exportService.exportExcel(items, embedPhotos: _includePhotos);
        break;
      case ExportFormat.sqlite:
        result = await exportService.exportSqlite(
          (dest) => ref.read(databaseServiceProvider).copyDatabaseTo(dest),
          items,
        );
        break;
    }

    setState(() {
      _loading = false;
      if (result.success) {
        _lastExportPath = result.filePath;
        _statusMessage = 'Exported ${result.itemCount} items to:\n${result.filePath}';
      } else {
        _statusMessage = 'Export failed: ${result.error}';
      }
    });
  }

  Future<void> _exportDonationReceipt() async {
    setState(() { _loading = true; _statusMessage = null; });
    final items = ref.read(itemsProvider).valueOrNull ?? [];
    final settings = ref.read(settingsProvider);
    final text = await ref.read(exportServiceProvider)
        .generateDonationReceiptText(items, settings);
    setState(() { _loading = false; });
    if (mounted) {
      await Share.share(text, subject: 'Donation Receipt');
    }
  }

  Future<void> _exportInsuranceReport() async {
    setState(() { _loading = true; _statusMessage = null; });
    final items = ref.read(itemsProvider).valueOrNull ?? [];
    final settings = ref.read(settingsProvider);
    final text = await ref.read(exportServiceProvider)
        .generateInsuranceReportText(items, settings);
    setState(() { _loading = false; });
    if (mounted) {
      await Share.share(text, subject: 'Inventory Valuation Report');
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = ref.watch(itemsProvider).valueOrNull?.length ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Export Inventory')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Summary card ────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 32),
                  const SizedBox(width: 12),
                  Text('$itemCount items in inventory',
                      style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Options ─────────────────────────────────────────────────
          SwitchListTile(
            title: const Text('Include photos in Excel export'),
            subtitle: const Text('Larger file size'),
            value: _includePhotos,
            onChanged: (v) => setState(() => _includePhotos = v),
          ),
          const Divider(),

          // ── Export buttons ───────────────────────────────────────────
          _ExportTile(
            icon: Icons.table_chart_outlined,
            title: 'Export CSV',
            subtitle: 'All items as comma-separated values (no photos)',
            onTap: () => _export(ExportFormat.csv),
            loading: _loading,
          ),
          _ExportTile(
            icon: Icons.grid_on,
            title: 'Export Excel (.xlsx)',
            subtitle: 'Full inventory with sell sheet and summary',
            onTap: () => _export(ExportFormat.excel),
            loading: _loading,
          ),
          _ExportTile(
            icon: Icons.storage_outlined,
            title: 'Export SQLite (.db)',
            subtitle: 'Raw database — import into Access via ODBC',
            onTap: () => _export(ExportFormat.sqlite),
            loading: _loading,
          ),
          const Divider(),
          _ExportTile(
            icon: Icons.volunteer_activism_outlined,
            title: 'Donation Receipt',
            subtitle: 'Itemised receipt with fair-market values for tax records',
            onTap: _exportDonationReceipt,
            loading: _loading,
          ),
          _ExportTile(
            icon: Icons.policy_outlined,
            title: 'Insurance Valuation Report',
            subtitle: 'Total household value by category for your insurer',
            onTap: _exportInsuranceReport,
            loading: _loading,
          ),

          // ── Status ───────────────────────────────────────────────────
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_statusMessage != null) ...[
            const SizedBox(height: 16),
            Card(
              color: _lastExportPath != null
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_statusMessage!),
                    if (_lastExportPath != null) ...[
                      const SizedBox(height: 8),
                      Row(children: [
                        TextButton.icon(
                          icon: const Icon(Icons.open_in_new, size: 16),
                          label: const Text('Open'),
                          onPressed: () => OpenFilex.open(_lastExportPath!),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.share, size: 16),
                          label: const Text('Share'),
                          onPressed: () => Share.shareXFiles(
                              [XFile(_lastExportPath!)]),
                        ),
                      ]),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ExportTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool loading;

  const _ExportTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: loading ? null : onTap,
    );
  }
}
