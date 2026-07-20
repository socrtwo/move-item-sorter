import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routes.dart';
import '../../models/app_settings.dart';
import '../../providers/app_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _section('Camera'),
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: const Text('Default camera mode'),
            subtitle: Text(settings.defaultCameraMode.displayName),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickCameraMode(context, ref),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.auto_awesome),
            title: const Text('Auto-enhance photos'),
            subtitle: const Text('Brightness, contrast, sharpness'),
            value: settings.autoEnhancePhotos,
            onChanged: (v) => ref.read(settingsProvider.notifier)
                .update((s) => s.copyWith(autoEnhancePhotos: v)),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.image_not_supported_outlined),
            title: const Text('Remove photo backgrounds'),
            subtitle: const Text('Isolate items on white'),
            value: settings.autoRemoveBackground,
            onChanged: (v) => ref.read(settingsProvider.notifier)
                .update((s) => s.copyWith(autoRemoveBackground: v)),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.qr_code_scanner),
            title: const Text('Barcode scanning'),
            value: settings.barcodeScanEnabled,
            onChanged: (v) => ref.read(settingsProvider.notifier)
                .update((s) => s.copyWith(barcodeScanEnabled: v)),
          ),

          _section('Voice & Speech'),
          SwitchListTile(
            secondary: const Icon(Icons.volume_up_outlined),
            title: const Text('Text-to-speech feedback'),
            value: settings.ttsEnabled,
            onChanged: (v) => ref.read(settingsProvider.notifier)
                .update((s) => s.copyWith(ttsEnabled: v)),
          ),
          ListTile(
            leading: const Icon(Icons.speed),
            title: const Text('Speech rate'),
            subtitle: Slider(
              value: settings.ttsRate,
              min: 0.1, max: 1.0, divisions: 9,
              label: settings.ttsRate.toStringAsFixed(1),
              onChanged: (v) => ref.read(settingsProvider.notifier)
                  .update((s) => s.copyWith(ttsRate: v)),
            ),
          ),

          _section('Categories & Keywords'),
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: const Text('Edit categories & sub-classifications'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.catSettings),
          ),
          ListTile(
            leading: const Icon(Icons.record_voice_over_outlined),
            title: const Text('Edit voice trigger phrases'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.kwSettings),
          ),
          ListTile(
            leading: const Icon(Icons.meeting_room_outlined),
            title: const Text('Manage rooms & locations'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.roomSettings),
          ),

          _section('Marketplaces'),
          ListTile(
            leading: const Icon(Icons.storefront_outlined),
            title: const Text('Marketplace settings'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.mktSettings),
          ),

          _section('Insurance & Valuation'),
          SwitchListTile(
            secondary: const Icon(Icons.policy_outlined),
            title: const Text('Insurance valuation mode'),
            subtitle: const Text('Track estimated values for each item'),
            value: settings.insuranceModeEnabled,
            onChanged: (v) => ref.read(settingsProvider.notifier)
                .update((s) => s.copyWith(insuranceModeEnabled: v)),
          ),
          if (settings.insuranceModeEnabled) ...[
            _textField(context, ref, 'Insurance company',
                settings.insuranceCompany,
                (v) => ref.read(settingsProvider.notifier)
                    .update((s) => s.copyWith(insuranceCompany: v))),
            _textField(context, ref, 'Policy number',
                settings.insurancePolicyNumber,
                (v) => ref.read(settingsProvider.notifier)
                    .update((s) => s.copyWith(insurancePolicyNumber: v))),
          ],

          _section('Cloud Sync'),
          SwitchListTile(
            secondary: const Icon(Icons.cloud_outlined),
            title: const Text('Enable cloud backup'),
            subtitle: const Text('Requires Firebase configuration'),
            value: settings.cloudSyncEnabled,
            onChanged: (v) => ref.read(settingsProvider.notifier)
                .update((s) => s.copyWith(cloudSyncEnabled: v)),
          ),

          _section('Duplicate Detection'),
          SwitchListTile(
            secondary: const Icon(Icons.content_copy_outlined),
            title: const Text('Detect duplicate items'),
            value: settings.duplicateDetectionEnabled,
            onChanged: (v) => ref.read(settingsProvider.notifier)
                .update((s) => s.copyWith(duplicateDetectionEnabled: v)),
          ),

          _section('API Keys'),
          ListTile(
            leading: const Icon(Icons.key_outlined),
            title: const Text('Manage API keys'),
            subtitle: const Text('Google Vision, OpenAI, eBay, Amazon'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.apiSettings),
          ),

          _section('Appearance'),
          ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: const Text('Theme'),
            subtitle: Text(_themeLabel(ref.watch(themeModeProvider))),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickTheme(context, ref),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      );

  Widget _textField(BuildContext ctx, WidgetRef ref, String label,
      String current, void Function(String) onSave) {
    return ListTile(
      title: Text(label),
      subtitle: Text(current.isEmpty ? '(not set)' : current),
      trailing: const Icon(Icons.edit_outlined, size: 18),
      onTap: () async {
        final ctrl = TextEditingController(text: current);
        final result = await showDialog<String>(
          context: ctx,
          builder: (_) => AlertDialog(
            title: Text(label),
            content: TextField(controller: ctrl),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, ctrl.text),
                  child: const Text('Save')),
            ],
          ),
        );
        if (result != null) onSave(result);
      },
    );
  }

  Future<void> _pickCameraMode(BuildContext ctx, WidgetRef ref) async {
    final settings = ref.read(settingsProvider);
    final mode = await showDialog<CameraMode>(
      context: ctx,
      builder: (_) => SimpleDialog(
        title: const Text('Default camera mode'),
        children: CameraMode.values
            .map((m) => SimpleDialogOption(
                  child: Text(m.displayName),
                  onPressed: () => Navigator.pop(ctx, m),
                ))
            .toList(),
      ),
    );
    if (mode != null) {
      ref.read(settingsProvider.notifier)
          .update((s) => s.copyWith(defaultCameraMode: mode));
    }
  }

  String _themeLabel(ThemeMode m) => switch (m) {
        ThemeMode.system => 'System',
        ThemeMode.light  => 'Light',
        ThemeMode.dark   => 'Dark',
      };

  Future<void> _pickTheme(BuildContext ctx, WidgetRef ref) async {
    final mode = await showDialog<ThemeMode>(
      context: ctx,
      builder: (_) => SimpleDialog(
        title: const Text('Theme'),
        children: ThemeMode.values
            .map((m) => SimpleDialogOption(
                  child: Text(_themeLabel(m)),
                  onPressed: () => Navigator.pop(ctx, m),
                ))
            .toList(),
      ),
    );
    if (mode != null) ref.read(themeModeProvider.notifier).state = mode;
  }
}
