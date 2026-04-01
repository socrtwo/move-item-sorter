import 'package:flutter/material.dart';
import '../models/category.dart';

class CategoryChip extends StatelessWidget {
  final Category category;
  final String? subCategory;
  final bool compact;

  const CategoryChip({
    super.key,
    required this.category,
    this.subCategory,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final label = subCategory != null && !compact
        ? '${category.displayName} · $subCategory'
        : category.displayName;

    return Chip(
      padding: compact ? EdgeInsets.zero : null,
      visualDensity: compact ? VisualDensity.compact : null,
      avatar: Icon(category.icon, color: category.color,
          size: compact ? 14 : 16),
      label: Text(label,
          style: TextStyle(
              color: category.color,
              fontSize: compact ? 11 : 13,
              fontWeight: FontWeight.w500)),
      backgroundColor: category.color.withOpacity(0.12),
      side: BorderSide(color: category.color.withOpacity(0.4)),
    );
  }
}
