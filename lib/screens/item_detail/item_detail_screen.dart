import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/routes.dart';
import '../../models/item.dart';
import '../../models/category.dart';
import '../../providers/app_providers.dart';
import '../../widgets/category_chip.dart';

class ItemDetailScreen extends ConsumerStatefulWidget {
  final String itemId;
  const ItemDetailScreen({super.key, required this.itemId});

  @override
  ConsumerState<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends ConsumerState<ItemDetailScreen> {
  Item? _item;
  bool _editing = false;
  late TextEditingController _nameCtrl;
  late TextEditingController _notesCtrl;
  late TextEditingController _valueCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _notesCtrl = TextEditingController();
    _valueCtrl = TextEditingController();
    _loadItem();
  }

  Future<void> _loadItem() async {
    final item = await ref.read(databaseServiceProvider).getItem(widget.itemId);
    if (item != null && mounted) {
      setState(() {
        _item = item;
        _nameCtrl.text = item.name;
        _notesCtrl.text = item.notes ?? '';
        _valueCtrl.text = item.estimatedValue?.toStringAsFixed(2) ?? '';
      });
    }
  }

  Future<void> _save() async {
    if (_item == null) return;
    final updated = _item!.copyWith(
      name: _nameCtrl.text.trim(),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      estimatedValue: double.tryParse(_valueCtrl.text),
      updatedAt: DateTime.now(),
    );
    await ref.read(itemsProvider.notifier).updateItem(updated);
    setState(() {
      _item = updated;
      _editing = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Item updated')));
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete item?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(itemsProvider.notifier).deleteItem(widget.itemId);
    if (mounted) context.pop();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _notesCtrl.dispose();
    _valueCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_item == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final item = _item!;
    final theme = Theme.of(context);
    final fmt = NumberFormat.currency(symbol: '\$');

    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Edit Item' : item.displayName,
            overflow: TextOverflow.ellipsis),
        actions: [
          if (!_editing) ...[
            IconButton(icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit', onPressed: () => setState(() => _editing = true)),
            IconButton(icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete', onPressed: _delete),
          ] else ...[
            TextButton(onPressed: () => setState(() => _editing = false),
                child: const Text('Cancel')),
            FilledButton(onPressed: _save, child: const Text('Save')),
          ],
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Photos ────────────────────────────────────────────────
            if (item.photoPaths.isNotEmpty) ...[
              SizedBox(
                height: 200,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: item.photoPaths.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final path = i == 0 && item.enhancedPhotoPath != null
                        ? item.enhancedPhotoPath!
                        : item.photoPaths[i];
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(File(path),
                          width: 200, height: 200, fit: BoxFit.cover),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Name ──────────────────────────────────────────────────
            _editing
                ? TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'Item name'),
                  )
                : Text(item.displayName,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),

            const SizedBox(height: 12),

            // ── Category + packing status ─────────────────────────────
            Row(
              children: [
                CategoryChip(category: item.category, subCategory: item.subCategory),
                const SizedBox(width: 8),
                Chip(
                  avatar: Icon(_packingIcon(item.packingStatus), size: 16),
                  label: Text(item.packingStatus.displayName),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),

            // ── Room ──────────────────────────────────────────────────
            if (item.roomLocation != null) ...[
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.room_outlined, size: 16),
                const SizedBox(width: 4),
                Text('Room: ${item.roomLocation}'),
              ]),
            ],

            // ── Identified as / Barcode ───────────────────────────────
            if (item.identifiedAs != null || item.barcodeProductName != null) ...[
              const SizedBox(height: 12),
              _infoRow(Icons.image_search, 'Identified as',
                  item.barcodeProductName ?? item.identifiedAs!),
            ],
            if (item.barcodeValue != null)
              _infoRow(Icons.qr_code, 'Barcode', item.barcodeValue!),

            // ── Estimated value ───────────────────────────────────────
            const SizedBox(height: 12),
            _editing
                ? TextField(
                    controller: _valueCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Estimated value (\$)',
                            prefixText: '\$'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  )
                : item.estimatedValue != null
                    ? _infoRow(Icons.attach_money, 'Estimated value',
                        fmt.format(item.estimatedValue!))
                    : const SizedBox.shrink(),

            // ── Dimensions ────────────────────────────────────────────
            if (item.dimensions?.hasAny == true) ...[
              const SizedBox(height: 8),
              _infoRow(Icons.straighten, 'Dimensions',
                  item.dimensions!.summary),
            ],

            // ── Voice description ─────────────────────────────────────
            if (item.voiceDescription != null) ...[
              const SizedBox(height: 12),
              Text('Voice description',
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: theme.colorScheme.primary)),
              const SizedBox(height: 4),
              Text(item.voiceDescription!,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontStyle: FontStyle.italic)),
            ],

            // ── Notes ─────────────────────────────────────────────────
            const SizedBox(height: 12),
            _editing
                ? TextField(
                    controller: _notesCtrl,
                    decoration: const InputDecoration(labelText: 'Notes'),
                    maxLines: 3,
                  )
                : item.notes != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Notes',
                              style: theme.textTheme.labelMedium
                                  ?.copyWith(color: theme.colorScheme.primary)),
                          const SizedBox(height: 4),
                          Text(item.notes!),
                        ],
                      )
                    : const SizedBox.shrink(),

            // ── Sell details ──────────────────────────────────────────
            if (item.sellDetails != null) ...[
              const Divider(height: 32),
              _SellDetailsSection(item: item),
            ],

            // ── Duplicate flag ────────────────────────────────────────
            if (item.isDuplicateFlagged) ...[
              const SizedBox(height: 16),
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: const ListTile(
                  leading: Icon(Icons.warning_amber_outlined),
                  title: Text('Possible duplicate flagged'),
                  subtitle: Text('This item may already exist in your inventory.'),
                ),
              ),
            ],

            const SizedBox(height: 8),
            Text('Created: ${DateFormat.yMMMd().add_jm().format(item.createdAt)}',
                style: theme.textTheme.bodySmall),

            // ── Sell button ───────────────────────────────────────────
            if (item.category == Category.sell && item.sellDetails == null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.push('/sell/${item.id}'),
                icon: const Icon(Icons.sell_outlined),
                label: const Text('Start sell listing'),
              ),
            ],

            // ── Change packing status ─────────────────────────────────
            const SizedBox(height: 16),
            _PackingStatusSelector(item: item),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w500)),
          Expanded(child: Text(value, overflow: TextOverflow.ellipsis)),
        ]),
      );

  IconData _packingIcon(PackingStatus s) => switch (s) {
        PackingStatus.notStarted => Icons.inventory_2_outlined,
        PackingStatus.packed => Icons.inventory_2,
        PackingStatus.loaded => Icons.local_shipping,
        PackingStatus.delivered => Icons.check_circle,
      };
}

// ──────────────────────────────────────────────────────────────────────────────

class _SellDetailsSection extends StatelessWidget {
  final Item item;
  const _SellDetailsSection({required this.item});

  @override
  Widget build(BuildContext context) {
    final sd = item.sellDetails!;
    final fmt = NumberFormat.currency(symbol: '\$');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sell Listing',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _row('Marketplace', sd.marketplace),
        _row('Type', sd.listingType.displayName),
        _row('Title', sd.title),
        if (sd.subtitle != null) _row('Subtitle', sd.subtitle!),
        if (sd.price != null) _row('Price', fmt.format(sd.price!)),
        _row('Shipping', sd.shippingOption.displayName),
        if (sd.condition != null) _row('Condition', sd.condition!),
        if (sd.isListed)
          _row('Listed', sd.listingUrl ?? 'Yes'),
        if (sd.description != null) ...[
          const SizedBox(height: 8),
          Text('Description${sd.aiGeneratedDescription ? " (AI)" : ""}:',
              style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(sd.description!),
        ],
        if (sd.isAiGuessed)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('[Fields in brackets were AI-estimated]',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.secondary,
                    fontSize: 12)),
          ),
      ],
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w500)),
          Expanded(child: Text(value, overflow: TextOverflow.ellipsis)),
        ]),
      );
}

// ──────────────────────────────────────────────────────────────────────────────

class _PackingStatusSelector extends ConsumerWidget {
  final Item item;
  const _PackingStatusSelector({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Packing status',
            style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 8),
        SegmentedButton<PackingStatus>(
          segments: PackingStatus.values
              .map((s) => ButtonSegment(value: s, label: Text(s.displayName)))
              .toList(),
          selected: {item.packingStatus},
          onSelectionChanged: (sel) {
            ref.read(itemsProvider.notifier).updateItem(
                item.copyWith(packingStatus: sel.first, updatedAt: DateTime.now()));
          },
        ),
      ],
    );
  }
}
