import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/routes.dart';
import '../../models/category.dart';
import '../../models/item.dart';
import '../../providers/app_providers.dart';
import '../../widgets/category_chip.dart';
import '../../widgets/item_card.dart';
import '../../widgets/voice_indicator.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(itemsProvider);
    final filter = ref.watch(filterProvider);
    final counts = ref.watch(categoryCountsProvider);
    final sellRevenue = ref.watch(sellRevenueProvider);
    final donationValue = ref.watch(donationValueProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Move Item Sorter'),
        actions: [
          // Batch mode toggle
          IconButton(
            tooltip: filter.batchMode ? 'Exit batch mode' : 'Batch select',
            icon: Icon(filter.batchMode ? Icons.close : Icons.checklist),
            onPressed: () => ref.read(filterProvider.notifier).toggleBatchMode(),
          ),
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export',
            onPressed: () => context.push(AppRoutes.export),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push(AppRoutes.settings),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Search bar ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search items…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: filter.searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(filterProvider.notifier).setSearch('');
                          ref.read(itemsProvider.notifier).loadAll();
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              ),
              onChanged: (q) {
                ref.read(filterProvider.notifier).setSearch(q);
                ref.read(itemsProvider.notifier).loadAll(searchQuery: q.isNotEmpty ? q : null);
              },
            ),
          ),

          // ── Category filter chips ────────────────────────────────────────
          SizedBox(
            height: 44,
            child: counts.when(
              data: (c) => ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                children: [
                  _allChip(filter, c),
                  ...Category.values.map((cat) => _categoryFilterChip(cat, filter, c)),
                ],
              ),
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
            ),
          ),

          // ── Budget summary strip ─────────────────────────────────────────
          _BudgetStrip(sellRevenue: sellRevenue, donationValue: donationValue),

          // ── Batch action bar ─────────────────────────────────────────────
          if (filter.batchMode && filter.selectedIds.isNotEmpty)
            _BatchActionBar(selectedIds: filter.selectedIds),

          // ── Items list ───────────────────────────────────────────────────
          Expanded(
            child: itemsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (items) {
                if (items.isEmpty) {
                  return _EmptyState(hasFilter: filter.category != null);
                }
                return RefreshIndicator(
                  onRefresh: () => ref.read(itemsProvider.notifier).loadAll(),
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 100),
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final item = items[i];
                      return ItemCard(
                        item: item,
                        batchMode: filter.batchMode,
                        isSelected: filter.selectedIds.contains(item.id),
                        onTap: filter.batchMode
                            ? () => ref
                                .read(filterProvider.notifier)
                                .toggleSelected(item.id)
                            : () => context.push('/item/${item.id}'),
                        onLongPress: () {
                          if (!filter.batchMode) {
                            ref.read(filterProvider.notifier).toggleBatchMode();
                            ref.read(filterProvider.notifier).toggleSelected(item.id);
                          }
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.camera),
        icon: const Icon(Icons.camera_alt),
        label: const Text('Capture'),
      ),
    );
  }

  Widget _allChip(FilterState filter, Map<Category, int> counts) {
    final total = counts.values.fold(0, (a, b) => a + b);
    final selected = filter.category == null;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text('All ($total)'),
        selected: selected,
        onSelected: (_) {
          ref.read(filterProvider.notifier).setCategory(null);
          ref.read(itemsProvider.notifier).loadAll();
        },
      ),
    );
  }

  Widget _categoryFilterChip(
      Category cat, FilterState filter, Map<Category, int> counts) {
    final count = counts[cat] ?? 0;
    if (count == 0) return const SizedBox.shrink();
    final selected = filter.category == cat;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        avatar: Icon(cat.icon, color: cat.color, size: 16),
        label: Text('${cat.displayName} ($count)'),
        selected: selected,
        selectedColor: cat.color.withOpacity(0.2),
        checkmarkColor: cat.color,
        onSelected: (_) {
          final newCat = selected ? null : cat;
          ref.read(filterProvider.notifier).setCategory(newCat);
          ref.read(itemsProvider.notifier).loadAll(filterCategory: newCat);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _BudgetStrip extends StatelessWidget {
  final AsyncValue<double> sellRevenue;
  final AsyncValue<double> donationValue;

  const _BudgetStrip({required this.sellRevenue, required this.donationValue});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '\$');
    final revenue = sellRevenue.valueOrNull ?? 0.0;
    final donation = donationValue.valueOrNull ?? 0.0;
    if (revenue == 0 && donation == 0) return const SizedBox.shrink();

    return Container(
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.attach_money, size: 16),
          const SizedBox(width: 4),
          Text('Expected revenue: ${fmt.format(revenue)}',
              style: Theme.of(context).textTheme.bodySmall),
          const Spacer(),
          const Icon(Icons.receipt_long, size: 16),
          const SizedBox(width: 4),
          Text('Donation write-off: ${fmt.format(donation)}',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _BatchActionBar extends ConsumerWidget {
  final Set<String> selectedIds;
  const _BatchActionBar({required this.selectedIds});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: Theme.of(context).colorScheme.primaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Text('${selectedIds.length} selected',
              style: Theme.of(context).textTheme.labelLarge),
          const Spacer(),
          TextButton.icon(
            icon: const Icon(Icons.category, size: 18),
            label: const Text('Move to…'),
            onPressed: () => _showBatchCategoryDialog(context, ref),
          ),
          TextButton.icon(
            icon: const Icon(Icons.inventory_2_outlined, size: 18),
            label: const Text('Packed'),
            onPressed: () {
              ref.read(itemsProvider.notifier).batchSetPackingStatus(
                    selectedIds.toList(), PackingStatus.packed);
              ref.read(filterProvider.notifier).clearSelection();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            tooltip: 'Delete selected',
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _showBatchCategoryDialog(BuildContext context, WidgetRef ref) async {
    final cat = await showDialog<Category>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Assign category'),
        children: Category.values
            .map((c) => SimpleDialogOption(
                  child: ListTile(
                    leading: Icon(c.icon, color: c.color),
                    title: Text(c.displayName),
                  ),
                  onPressed: () => Navigator.pop(context, c),
                ))
            .toList(),
      ),
    );
    if (cat == null) return;
    await ref.read(itemsProvider.notifier)
        .batchSetCategory(selectedIds.toList(), cat);
    ref.read(filterProvider.notifier).clearSelection();
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete items?'),
        content: Text('Delete ${selectedIds.length} item(s)? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(itemsProvider.notifier).deleteItems(selectedIds.toList());
    ref.read(filterProvider.notifier).clearSelection();
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool hasFilter;
  const _EmptyState({required this.hasFilter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            hasFilter ? 'No items in this category' : 'No items yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (!hasFilter)
            const Text('Tap Capture to start photographing items.'),
        ],
      ),
    );
  }
}
