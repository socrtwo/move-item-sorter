import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/category.dart';
import '../../providers/app_providers.dart';

class CategorySettingsScreen extends ConsumerWidget {
  const CategorySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final configs = settings.categoryConfigs;

    return Scaffold(
      appBar: AppBar(title: const Text('Categories & Sub-classifications')),
      body: ReorderableListView.builder(
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: configs.length,
        onReorder: (o, n) {
          final updated = List<CategoryConfig>.from(configs);
          final item = updated.removeAt(o);
          updated.insert(n > o ? n - 1 : n, item);
          ref.read(settingsProvider.notifier)
              .update((s) => s.copyWith(categoryConfigs: updated));
        },
        itemBuilder: (ctx, i) {
          final config = configs[i];
          return _CategoryTile(key: ValueKey(config.id), config: config, index: i);
        },
      ),
    );
  }
}

class _CategoryTile extends ConsumerWidget {
  final CategoryConfig config;
  final int index;

  const _CategoryTile({super.key, required this.config, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ExpansionTile(
      leading: Icon(config.category.icon, color: config.category.color),
      title: Text(config.category.displayName,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        '${config.subClassifications.length} sub-classifications · '
        '${config.aliases.length} extra keywords',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      children: [
        // ── Aliases ────────────────────────────────────────────────────
        ListTile(
          dense: true,
          title: const Text('Extra trigger words'),
          subtitle: Wrap(
            spacing: 6,
            children: [
              ...config.aliases.map((a) => Chip(
                    label: Text(a),
                    onDeleted: () => _removeAlias(ref, config, a),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  )),
              ActionChip(
                label: const Text('+ Add'),
                onPressed: () => _addAlias(context, ref, config),
              ),
            ],
          ),
        ),

        // ── Sub-classifications ────────────────────────────────────────
        ListTile(
          dense: true,
          title: const Text('Sub-classifications'),
          subtitle: Column(
            children: [
              ...config.subClassifications.asMap().entries.map((e) {
                final sub = e.value;
                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.only(left: 16),
                  title: Text(sub.label),
                  subtitle: Text(sub.keywords.join(', ')),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: () => _removeSub(ref, config, sub.id),
                  ),
                );
              }),
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.only(left: 16),
                leading: const Icon(Icons.add_circle_outline, size: 20),
                title: const Text('Add sub-classification'),
                onTap: () => _addSub(context, ref, config),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _removeAlias(WidgetRef ref, CategoryConfig config, String alias) {
    _updateConfig(ref, config.copyWith(
        aliases: config.aliases.where((a) => a != alias).toList()));
  }

  Future<void> _addAlias(BuildContext ctx, WidgetRef ref, CategoryConfig config) async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Add trigger word'),
        content: TextField(controller: ctrl, decoration:
            const InputDecoration(hintText: 'e.g. "bring" or "keep"')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Add')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      _updateConfig(ref, config.copyWith(aliases: [...config.aliases, result]));
    }
  }

  void _removeSub(WidgetRef ref, CategoryConfig config, String subId) {
    _updateConfig(ref, config.copyWith(
        subClassifications:
            config.subClassifications.where((s) => s.id != subId).toList()));
  }

  Future<void> _addSub(
      BuildContext ctx, WidgetRef ref, CategoryConfig config) async {
    final labelCtrl = TextEditingController();
    final kwCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Add sub-classification'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: labelCtrl,
              decoration: const InputDecoration(labelText: 'Label (e.g. "Living Room")')),
          const SizedBox(height: 8),
          TextField(controller: kwCtrl,
              decoration: const InputDecoration(
                  labelText: 'Keywords (comma-separated)',
                  hintText: 'living room, lounge')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add')),
        ],
      ),
    );
    if (result == true && labelCtrl.text.trim().isNotEmpty) {
      final sub = SubClassification(
        id: labelCtrl.text.trim().toLowerCase().replaceAll(' ', '_'),
        label: labelCtrl.text.trim(),
        keywords: kwCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
      );
      _updateConfig(ref, config.copyWith(
          subClassifications: [...config.subClassifications, sub]));
    }
  }

  void _updateConfig(WidgetRef ref, CategoryConfig updated) {
    final configs = ref.read(settingsProvider).categoryConfigs;
    final newList = configs.map((c) => c.id == updated.id ? updated : c).toList();
    ref.read(settingsProvider.notifier)
        .update((s) => s.copyWith(categoryConfigs: newList));
  }
}
