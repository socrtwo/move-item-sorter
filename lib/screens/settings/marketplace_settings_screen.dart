import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/item.dart';
import '../../providers/app_providers.dart';

class MarketplaceSettingsScreen extends ConsumerWidget {
  const MarketplaceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Marketplace Settings')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // ── Default marketplace ────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Default marketplace',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: settings.defaultMarketplace,
                    items: Marketplace.all
                        .map((m) => DropdownMenuItem(
                              value: m,
                              child: Text(Marketplace.displayName(m)),
                            ))
                        .toList(),
                    onChanged: (v) => ref.read(settingsProvider.notifier)
                        .update((s) => s.copyWith(defaultMarketplace: v!)),
                  ),
                ],
              ),
            ),
          ),

          // ── Auto-list ──────────────────────────────────────────────────
          SwitchListTile(
            title: const Text('Auto-submit listing'),
            subtitle: const Text(
                'Automatically submit to the marketplace after completing the sell flow'),
            value: settings.autoListOnSell,
            onChanged: (v) => ref.read(settingsProvider.notifier)
                .update((s) => s.copyWith(autoListOnSell: v)),
          ),

          // ── Default shipping ───────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Default shipping',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: settings.defaultShippingOption,
                    items: ShippingOption.values
                        .map((s) => DropdownMenuItem(
                              value: s.name,
                              child: Text(s.displayName),
                            ))
                        .toList(),
                    onChanged: (v) => ref.read(settingsProvider.notifier)
                        .update((s) => s.copyWith(defaultShippingOption: v!)),
                  ),
                  if (settings.defaultShippingOption == 'flatRate') ...[
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue:
                          settings.defaultShippingCost.toStringAsFixed(2),
                      decoration: const InputDecoration(
                          labelText: 'Default flat rate (\$)',
                          prefixText: '\$'),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      onChanged: (v) {
                        final cost = double.tryParse(v);
                        if (cost != null) {
                          ref.read(settingsProvider.notifier)
                              .update((s) => s.copyWith(defaultShippingCost: cost));
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── Marketplace list ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
            child: Text('Supported marketplaces',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          ...Marketplace.all.map((mp) => ListTile(
                leading: const Icon(Icons.storefront_outlined),
                title: Text(Marketplace.displayName(mp)),
                subtitle: mp == 'ebay'
                    ? const Text('Full API listing via Trading API')
                    : const Text('Opens marketplace app / website'),
                trailing: settings.defaultMarketplace == mp
                    ? const Chip(label: Text('Default'))
                    : null,
              )),
        ],
      ),
    );
  }
}
