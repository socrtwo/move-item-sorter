import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/app_settings.dart';
import '../../providers/app_providers.dart';

class RoomSettingsScreen extends ConsumerWidget {
  const RoomSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rooms = ref.watch(settingsProvider).rooms;

    return Scaffold(
      appBar: AppBar(title: const Text('Rooms & Locations')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addRoom(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add room'),
      ),
      body: ReorderableListView.builder(
        padding: const EdgeInsets.only(bottom: 100),
        itemCount: rooms.length,
        onReorder: (o, n) {
          final updated = List<RoomConfig>.from(rooms);
          final item = updated.removeAt(o);
          updated.insert(n > o ? n - 1 : n, item);
          ref.read(settingsProvider.notifier)
              .update((s) => s.copyWith(rooms: updated));
        },
        itemBuilder: (_, i) {
          final room = rooms[i];
          return ListTile(
            key: ValueKey(room.id),
            leading: const Icon(Icons.meeting_room_outlined),
            title: Text(room.label),
            subtitle: Text(room.keywords.join(', ')),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  onPressed: () => _editRoom(context, ref, room),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  onPressed: () {
                    final updated = rooms.where((r) => r.id != room.id).toList();
                    ref.read(settingsProvider.notifier)
                        .update((s) => s.copyWith(rooms: updated));
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _addRoom(BuildContext ctx, WidgetRef ref) async {
    final labelCtrl = TextEditingController();
    final kwCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Add room'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: labelCtrl,
              decoration: const InputDecoration(labelText: 'Room name')),
          const SizedBox(height: 8),
          TextField(controller: kwCtrl,
              decoration: const InputDecoration(
                  labelText: 'Voice keywords',
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
    if (ok != true || labelCtrl.text.trim().isEmpty) return;
    final room = RoomConfig(
      id: labelCtrl.text.trim().toLowerCase().replaceAll(' ', '_'),
      label: labelCtrl.text.trim(),
      keywords: kwCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
    );
    final rooms = [...ref.read(settingsProvider).rooms, room];
    ref.read(settingsProvider.notifier).update((s) => s.copyWith(rooms: rooms));
  }

  Future<void> _editRoom(BuildContext ctx, WidgetRef ref, RoomConfig room) async {
    final labelCtrl = TextEditingController(text: room.label);
    final kwCtrl = TextEditingController(text: room.keywords.join(', '));
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Edit room'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: labelCtrl,
              decoration: const InputDecoration(labelText: 'Room name')),
          const SizedBox(height: 8),
          TextField(controller: kwCtrl,
              decoration: const InputDecoration(labelText: 'Voice keywords')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    final updated = room.copyWith(
      label: labelCtrl.text.trim(),
      keywords: kwCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
    );
    final rooms = ref.read(settingsProvider).rooms
        .map((r) => r.id == updated.id ? updated : r)
        .toList();
    ref.read(settingsProvider.notifier).update((s) => s.copyWith(rooms: rooms));
  }
}
