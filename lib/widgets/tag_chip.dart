import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/utils.dart';

/// 板块/标签胶囊。
class TagChip extends StatelessWidget {
  const TagChip({
    Key? key,
    required this.tag,
    this.selected = false,
    this.onTap,
  }) : super(key: key);

  final Tag tag;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = tag.color != null
        ? colorFromHex(tag.color!, fallback: Theme.of(context).colorScheme.primary)
        : Theme.of(context).colorScheme.primary;

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: selected ? color : color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected ? color : color.withOpacity(0.5),
        ),
      ),
      child: Text(
        tag.name,
        style: TextStyle(
          color: selected
              ? (ThemeData.estimateBrightnessForColor(color) == Brightness.dark
                  ? Colors.white
                  : Colors.black)
              : Theme.of(context).colorScheme.onSurface,
          fontSize: 13,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );

    if (onTap == null) return chip;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: chip,
    );
  }
}
