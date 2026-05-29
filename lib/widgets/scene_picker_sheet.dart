import 'package:flutter/material.dart';

import '../constants/scene_categories.dart';

/// 组局场景选择 BottomSheet（浏览筛选 / 发布分类复用）
class ScenePickerSheet extends StatelessWidget {
  const ScenePickerSheet({
    super.key,
    required this.selectedId,
    required this.includeAll,
    required this.title,
    required this.subtitle,
  });

  final String? selectedId;
  final bool includeAll;
  final String title;
  final String subtitle;

  static Future<String?> show(
    BuildContext context, {
    String? selectedId,
    bool includeAll = false,
    required String title,
    required String subtitle,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => ScenePickerSheet(
        selectedId: selectedId,
        includeAll: includeAll,
        title: title,
        subtitle: subtitle,
      ),
    );
  }

  static const Color _brand = Color(0xFF002FA7);

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: Colors.black.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.5,
            ),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  if (includeAll)
                    _SceneTile(
                      icon: Icons.grid_view_rounded,
                      label: '全部',
                      selected: selectedId == null ||
                          selectedId!.isEmpty ||
                          selectedId == SceneCategories.allId,
                      onTap: () =>
                          Navigator.pop(context, SceneCategories.allId),
                    ),
                  ...SceneCategories.publishable.map(
                    (scene) => _SceneTile(
                      icon: scene.icon,
                      label: scene.label,
                      selected: selectedId == scene.id,
                      onTap: () => Navigator.pop(context, scene.id),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SceneTile extends StatelessWidget {
  const _SceneTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        icon,
        color: selected ? ScenePickerSheet._brand : Colors.black54,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          color: selected ? ScenePickerSheet._brand : Colors.black87,
        ),
      ),
      trailing: selected
          ? const Icon(Icons.check_circle, color: ScenePickerSheet._brand)
          : null,
      onTap: onTap,
    );
  }
}
