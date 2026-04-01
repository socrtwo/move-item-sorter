import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/item.dart';
import 'category_chip.dart';

class ItemCard extends StatelessWidget {
  final Item item;
  final bool batchMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const ItemCard({
    super.key,
    required this.item,
    this.batchMode = false,
    this.isSelected = false,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: isSelected
          ? theme.colorScheme.primaryContainer.withOpacity(0.5)
          : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // ── Batch checkbox ────────────────────────────────────
              if (batchMode)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (_) => onTap(),
                  ),
                ),

              // ── Thumbnail ─────────────────────────────────────────
              _Thumbnail(item: item),
              const SizedBox(width: 12),

              // ── Text content ──────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.displayName,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        CategoryChip(
                          category: item.category,
                          subCategory: item.subCategory,
                          compact: true,
                        ),
                        if (item.roomLocation != null) ...[
                          const SizedBox(width: 4),
                          Flexible(
                            child: Chip(
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              label: Text(item.roomLocation!,
                                  style: const TextStyle(fontSize: 11)),
                              avatar: const Icon(Icons.meeting_room_outlined,
                                  size: 12),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (item.voiceDescription != null ||
                        item.identifiedAs != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.voiceDescription ?? item.identifiedAs!,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontStyle: FontStyle.italic),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // ── Status icons ──────────────────────────────────────
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (item.packingStatus != PackingStatus.notStarted)
                    Icon(_packingIcon(item.packingStatus),
                        size: 18,
                        color: item.packingStatus == PackingStatus.delivered
                            ? Colors.green
                            : theme.colorScheme.primary),
                  if (item.isDuplicateFlagged)
                    const Icon(Icons.content_copy_outlined,
                        size: 16, color: Colors.orange),
                  if (item.sellDetails?.isListed == true)
                    const Icon(Icons.check_circle,
                        size: 16, color: Colors.green),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _packingIcon(PackingStatus s) => switch (s) {
        PackingStatus.notStarted => Icons.inventory_2_outlined,
        PackingStatus.packed     => Icons.inventory_2,
        PackingStatus.loaded     => Icons.local_shipping,
        PackingStatus.delivered  => Icons.check_circle,
      };
}

class _Thumbnail extends StatelessWidget {
  final Item item;
  const _Thumbnail({required this.item});

  @override
  Widget build(BuildContext context) {
    final path = item.primaryPhotoPath;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 64,
        height: 64,
        child: path != null
            ? Image.file(File(path), fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder(context))
            : _placeholder(context),
      ),
    );
  }

  Widget _placeholder(BuildContext ctx) => Container(
        color: Theme.of(ctx).colorScheme.surfaceVariant,
        child: Icon(item.category.icon,
            color: item.category.color, size: 28),
      );
}
