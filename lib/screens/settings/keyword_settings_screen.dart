import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';

class KeywordSettingsScreen extends ConsumerWidget {
  const KeywordSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Voice Trigger Phrases')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _KeywordGroup(
            title: 'Category trigger phrases',
            subtitle: 'Phrases that precede a category: "add this to move"',
            keywords: s.triggerPhrases,
            onUpdate: (list) => ref.read(settingsProvider.notifier)
                .update((st) => st.copyWith(triggerPhrases: list)),
          ),
          _KeywordGroup(
            title: 'New item triggers',
            subtitle: '"new item", "capture", "take photo", …',
            keywords: s.newItemTriggers,
            onUpdate: (list) => ref.read(settingsProvider.notifier)
                .update((st) => st.copyWith(newItemTriggers: list)),
          ),
          _KeywordGroup(
            title: 'Multi-angle triggers',
            subtitle: '"angles", "multi", "rotate", …',
            keywords: s.multiAngleTriggers,
            onUpdate: (list) => ref.read(settingsProvider.notifier)
                .update((st) => st.copyWith(multiAngleTriggers: list)),
          ),
        ],
      ),
    );
  }
}

class _KeywordGroup extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<String> keywords;
  final void Function(List<String>) onUpdate;

  const _KeywordGroup({
    required this.title,
    required this.subtitle,
    required this.keywords,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                ...keywords.map((kw) => Chip(
                      label: Text(kw),
                      onDeleted: () =>
                          onUpdate(keywords.where((k) => k != kw).toList()),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    )),
                ActionChip(
                  label: const Text('+ Add'),
                  onPressed: () => _addKeyword(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addKeyword(BuildContext context) async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add phrase'),
        content: TextField(controller: ctrl,
            decoration: const InputDecoration(hintText: 'Type a phrase…')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('Add')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      onUpdate([...keywords, result]);
    }
  }
}
