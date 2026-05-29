import 'package:flutter/material.dart';

import '../constants/user_hashtags.dart';

/// # 标签 Chip（Feed / 个性化 / 发布复用）
class HashtagChip extends StatelessWidget {
  const HashtagChip({
    super.key,
    required this.tag,
    this.selected = false,
    this.onTap,
    this.onDeleted,
    this.compact = false,
  });

  final String tag;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onDeleted;
  final bool compact;

  static const Color brand = Color(0xFF002FA7);

  @override
  Widget build(BuildContext context) {
    final label = UserHashtags.format(tag);
    final bg = selected
        ? brand.withValues(alpha: 0.14)
        : brand.withValues(alpha: compact ? 0.06 : 0.08);
    final fg = selected ? brand : (compact ? brand.withValues(alpha: 0.85) : brand);

    final child = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: selected ? Border.all(color: brand.withValues(alpha: 0.35)) : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: compact ? 11 : 12,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
    );

    if (onDeleted != null) {
      return InputChip(
        label: Text(
          label,
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        backgroundColor: bg,
        side: BorderSide.none,
        deleteIcon: const Icon(Icons.close, size: 16),
        onDeleted: onDeleted,
        onPressed: onTap,
      );
    }

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: child,
        ),
      );
    }

    return child;
  }
}
